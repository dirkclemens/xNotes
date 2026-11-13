//
//  JavaScriptTransformLoader.swift
//  xNotes
//
//  Loads clipboard transform plugins written in JavaScript.
//
//  Plugin format (one `.js` file per transform):
//
//      /**
//       * @title  Title Case
//       * @group  Case
//       * @id     example.title-case       (optional, default: plugin.<file name>)
//       * @input  Language:                (optional, asks the user for a value)
//       * @description Short explanation   (optional)
//       */
//      function transform(input, ctx) {
//          // ctx.argument contains the @input value (or null)
//          return input.toUpperCase();      // return null/undefined for "no change"
//      }
//
//  Scripts run in an isolated JavaScriptCore context without file or network access.
//

import Foundation
import JavaScriptCore

nonisolated struct PluginLoadError: Identifiable, Equatable, Sendable {
    let id = UUID()
    let fileName: String
    let message: String
}

nonisolated enum JavaScriptTransformLoader {
    static let defaultGroup = "Plugins"
    /// Plugins are placed after built-in transforms of the same group (separated by a divider).
    static let pluginSection = 100
    /// Upper bound for a single plugin run.
    static let executionTimeLimit: TimeInterval = 3

    struct LoadResult {
        var transforms: [ClipboardTransform] = []
        var errors: [PluginLoadError] = []
    }

    static func loadPlugins(in folder: URL, reservedIds: Set<String>) -> LoadResult {
        var result = LoadResult()
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            return result
        }

        var usedIds = reservedIds
        for url in files.filter({ $0.pathExtension.lowercased() == "js" })
            .sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
            let fileName = url.lastPathComponent
            do {
                let source = try String(contentsOf: url, encoding: .utf8)
                let metadata = parseMetadata(source, fileURL: url)
                try validate(source: source, url: url)
                guard !usedIds.contains(metadata.id) else {
                    throw TransformError(message: "Duplicate id “\(metadata.id)”.")
                }
                usedIds.insert(metadata.id)
                result.transforms.append(makeTransform(metadata: metadata, source: source, url: url))
            } catch {
                result.errors.append(PluginLoadError(fileName: fileName, message: error.localizedDescription))
            }
        }
        return result
    }

    // MARK: - Metadata

    struct Metadata {
        var id: String
        var title: String
        var group: String
        var input: ClipboardTransform.Input
        var description: String?
    }

    static func parseMetadata(_ source: String, fileURL: URL) -> Metadata {
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        var metadata = Metadata(
            id: "plugin.\(baseName)",
            title: baseName
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized,
            group: defaultGroup,
            input: .none,
            description: nil
        )

        guard let start = source.range(of: "/**"),
              let end = source.range(of: "*/", range: start.upperBound..<source.endIndex) else {
            return metadata
        }

        let header = source[start.upperBound..<end.lowerBound]
        for rawLine in header.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("*") {
                line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            guard line.hasPrefix("@") else { continue }
            let parts = line.dropFirst().split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
            guard let key = parts.first?.lowercased() else { continue }
            let value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            guard !value.isEmpty else { continue }

            switch key {
            case "id": metadata.id = value
            case "title": metadata.title = value
            case "group": metadata.group = value
            case "input": metadata.input = .prompt(label: value)
            case "description": metadata.description = value
            default: continue
            }
        }
        return metadata
    }

    // MARK: - Execution

    private static func makeTransform(metadata: Metadata, source: String, url: URL) -> ClipboardTransform {
        ClipboardTransform(
            id: metadata.id,
            title: metadata.title,
            group: metadata.group,
            section: pluginSection,
            input: metadata.input,
            source: .javascript(url),
            help: metadata.description
        ) { text, argument in
            try execute(source: source, url: url, text: text, argument: argument)
        }
    }

    /// Compiles the script and checks that it defines `transform`.
    private static func validate(source: String, url: URL) throws {
        let (context, exception) = try makeContext(source: source, url: url)
        if let message = exception.message { throw TransformError(message: message) }
        let function = context.objectForKeyedSubscript("transform")
        guard let function, isFunction(function, in: context) else {
            throw TransformError(message: "No function named transform(input, ctx) found.")
        }
    }

    static func execute(source: String, url: URL, text: String, argument: String?) throws -> String? {
        let (context, exception) = try makeContext(source: source, url: url)
        if let message = exception.message { throw TransformError(message: message) }

        guard let function = context.objectForKeyedSubscript("transform"), isFunction(function, in: context) else {
            throw TransformError(message: "No function named transform(input, ctx) found.")
        }

        let ctx: [String: Any] = [
            "argument": argument ?? NSNull(),
            "fileName": url.lastPathComponent,
        ]
        let value = function.call(withArguments: [text, ctx])

        if let message = exception.message {
            throw TransformError(message: "\(url.lastPathComponent): \(message)")
        }
        guard let value, !value.isUndefined, !value.isNull else { return nil }
        return value.toString()
    }

    /// Collects the first JavaScript exception thrown in a context.
    private final class ExceptionBox {
        var message: String?
    }

    private static func makeContext(source: String, url: URL) throws -> (JSContext, ExceptionBox) {
        guard let context = JSContext() else {
            throw TransformError(message: "Could not create a JavaScript context.")
        }
        context.name = url.lastPathComponent
        JSExecutionTimeLimit.apply(to: context, seconds: executionTimeLimit)

        let box = ExceptionBox()
        context.exceptionHandler = { _, exception in
            guard box.message == nil else { return }
            let text = exception?.toString() ?? "Unknown JavaScript error"
            if text.contains("execution terminated") {
                box.message = "Stopped after \(Int(executionTimeLimit)) s (endless loop?)."
                return
            }
            let line = exception?.objectForKeyedSubscript("line")
            if let line, line.isNumber {
                box.message = "\(text) (line \(line.toInt32()))"
            } else {
                box.message = text
            }
        }

        let pluginName = url.lastPathComponent
        let log: @convention(block) () -> Void = {
            let args = JSContext.currentArguments()?.compactMap { ($0 as? JSValue)?.toString() } ?? []
            NSLog("[xNotes plugin \(pluginName)] \(args.joined(separator: " "))")
        }
        let console = JSValue(newObjectIn: context)
        console?.setObject(log, forKeyedSubscript: "log" as NSString)
        console?.setObject(log, forKeyedSubscript: "error" as NSString)
        context.setObject(console, forKeyedSubscript: "console" as NSString)

        context.evaluateScript(source, withSourceURL: url)
        return (context, box)
    }

    private static func isFunction(_ value: JSValue, in context: JSContext) -> Bool {
        guard value.isObject else { return false }
        let typeOf = context.evaluateScript("(function (v) { return typeof v; })")
        return typeOf?.call(withArguments: [value])?.toString() == "function"
    }
}

/// Stops runaway scripts (e.g. infinite loops).
///
/// JavaScriptCore only exposes the execution time limit through its SPI header,
/// so the symbol is looked up at runtime. If it is unavailable, the caller's
/// timeout still returns control to the user, but the script keeps running in the background.
nonisolated private enum JSExecutionTimeLimit {
    typealias ShouldTerminate = @convention(c) (JSContextRef?, UnsafeMutableRawPointer?) -> Bool
    typealias SetLimit = @convention(c) (JSContextGroupRef?, Double, ShouldTerminate?, UnsafeMutableRawPointer?) -> Void

    private static let setLimit: SetLimit? = {
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
        guard let symbol = dlsym(rtldDefault, "JSContextGroupSetExecutionTimeLimit") else { return nil }
        return unsafeBitCast(symbol, to: SetLimit.self)
    }()

    static func apply(to context: JSContext, seconds: Double) {
        guard let setLimit else { return }
        let group = JSContextGetGroup(context.jsGlobalContextRef)
        setLimit(group, seconds, { _, _ in true }, nil)
    }
}
