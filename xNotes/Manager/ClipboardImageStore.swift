//
//  ClipboardImageStore.swift
//  xNotes
//

import AppKit
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

/// Images from the clipboard (screenshots, "Copy Image"), one PNG per entry plus a small
/// thumbnail for the list, in `Application Support/<bundle id>/ClipboardImages/`.
/// Like formatted text they stay out of `tabs.json`, and they are not part of backups.
final class ClipboardImageStore {
    /// Larger images are not recorded (a full-screen 6K screenshot is about 20 MB as PNG).
    nonisolated static let maxBytes = 30 * 1024 * 1024
    /// Longest side of the list thumbnail in pixels (Retina: 2× the displayed size).
    nonisolated static let thumbnailPixels = 96

    /// An image read from the pasteboard, converted and measured off the main thread.
    nonisolated struct ProcessedImage: Sendable {
        let png: Data
        let thumbnailPNG: Data?
        let info: ClipboardImageInfo
    }

    private let folderURL: URL
    private let thumbnailCache = NSCache<NSUUID, NSImage>()

    init(folderName: String) {
        folderURL = AppPaths.applicationSupport.appendingPathComponent(folderName, isDirectory: true)
    }

    /// Image data on the pasteboard, in the best available format. Read on the main thread.
    static func imageData(on pasteboard: NSPasteboard) -> Data? {
        let preferred: [NSPasteboard.PasteboardType] = [
            .png, .tiff, NSPasteboard.PasteboardType(UTType.jpeg.identifier),
            NSPasteboard.PasteboardType(UTType.heic.identifier), NSPasteboard.PasteboardType(UTType.gif.identifier),
        ]
        for type in preferred {
            if let data = pasteboard.data(forType: type), !data.isEmpty {
                return data
            }
        }
        return nil
    }

    /// Converts to PNG, builds the thumbnail and hashes the pixels' PNG for de-duplication.
    nonisolated static func process(_ data: Data) -> ProcessedImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let sourceType = CGImageSourceGetType(source) as String?
        let png: Data
        if sourceType == UTType.png.identifier {
            png = data
        } else {
            guard let converted = encodePNG(image) else { return nil }
            png = converted
        }
        guard png.count <= maxBytes else { return nil }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailPixels,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
            .flatMap(encodePNG)

        let hash = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
        let originalFormat = sourceType.flatMap { UTType($0)?.localizedDescription } ?? "Image"
        let info = ClipboardImageInfo(
            hash: hash,
            width: image.width,
            height: image.height,
            byteCount: png.count,
            originalFormat: originalFormat
        )
        return ProcessedImage(png: png, thumbnailPNG: thumbnail, info: info)
    }

    nonisolated private static func encodePNG(_ image: CGImage) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    func save(_ image: ProcessedImage, for id: UUID) -> Bool {
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try image.png.write(to: imageURL(for: id), options: .atomic)
            try image.thumbnailPNG?.write(to: thumbnailURL(for: id), options: .atomic)
            return true
        } catch {
            NSLog("[ClipboardImageStore] Failed to save image \(id): \(error)")
            return false
        }
    }

    func imageURL(for id: UUID) -> URL {
        folderURL.appendingPathComponent("\(id.uuidString).png")
    }

    func imageData(for id: UUID) -> Data? {
        try? Data(contentsOf: imageURL(for: id))
    }

    /// Small image for the list; cached in memory.
    func thumbnail(for id: UUID) -> NSImage? {
        if let cached = thumbnailCache.object(forKey: id as NSUUID) {
            return cached
        }
        guard let image = NSImage(contentsOf: thumbnailURL(for: id)) ?? NSImage(contentsOf: imageURL(for: id)) else {
            return nil
        }
        thumbnailCache.setObject(image, forKey: id as NSUUID)
        return image
    }

    /// Downscaled image for the hover preview. Decoding a large screenshot takes a moment,
    /// so this runs off the main thread.
    nonisolated static func previewImage(at url: URL, maxPixels: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Deletes the images of entries that are gone.
    func removeAll(except keptIds: Set<UUID>) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "-thumb", with: "")
            guard let id = UUID(uuidString: name), !keptIds.contains(id) else { continue }
            try? FileManager.default.removeItem(at: file)
            thumbnailCache.removeObject(forKey: id as NSUUID)
        }
    }

    private func thumbnailURL(for id: UUID) -> URL {
        folderURL.appendingPathComponent("\(id.uuidString)-thumb.png")
    }
}

/// Size and identity of a clipboard image (stored in `tabs.json`; the pixels are files).
nonisolated struct ClipboardImageInfo: Codable, Equatable, Sendable {
    /// SHA-256 of the PNG, to recognize the same image copied again.
    let hash: String
    let width: Int
    let height: Int
    /// Size of the stored PNG.
    let byteCount: Int
    /// Format the source app provided, e.g. "PNG image" or "TIFF image".
    let originalFormat: String
}
