//
//  TransformExecutor.swift
//  xNotes
//

import Foundation

/// Runs a transform off the main thread with a timeout, so a slow or hanging plugin never blocks the UI.
nonisolated enum TransformExecutor {
    static func run(
        _ transform: ClipboardTransform,
        text: String,
        argument: String?,
        timeout: TimeInterval = JavaScriptTransformLoader.executionTimeLimit + 1
    ) async -> Result<String?, Error> {
        await withCheckedContinuation { continuation in
            let once = ResumeOnce(continuation)
            DispatchQueue.global(qos: .userInitiated).async {
                once.resume(with: Result { try transform.run(text, argument) })
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                once.resume(with: .failure(TransformError(message: "“\(transform.title)” took longer than \(Int(timeout)) s and was cancelled.")))
            }
        }
    }

    private final class ResumeOnce: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Result<String?, Error>, Never>?

        init(_ continuation: CheckedContinuation<Result<String?, Error>, Never>) {
            self.continuation = continuation
        }

        func resume(with result: Result<String?, Error>) {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume(returning: result)
        }
    }
}
