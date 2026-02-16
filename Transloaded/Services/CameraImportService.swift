import AppKit
import ImageIO
import UniformTypeIdentifiers

enum CameraImportError: LocalizedError {
    case noImageData
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .noImageData:
            return "Could not extract image data from the captured photo"
        case .saveFailed(let name):
            return "Failed to save image: \(name)"
        }
    }
}

struct CameraImportService {

    func saveImage(_ image: NSImage, to folder: URL, quality: ImageQualityOption) throws -> URL {
        let nextNumber = nextScanNumber(in: folder)
        let filename = String(format: "scan_%03d", nextNumber)
        let resized = resize(image, quality: quality)

        // Try HEIC first, fall back to JPEG
        if let url = try? saveAsHEIC(resized, folder: folder, filename: filename, quality: quality) {
            return url
        }

        return try saveAsJPEG(resized, folder: folder, filename: filename, quality: quality)
    }

    func savePDF(_ data: Data, to folder: URL) throws -> URL {
        let nextNumber = nextScanNumber(in: folder)
        let filename = String(format: "scan_%03d.pdf", nextNumber)
        let url = folder.appendingPathComponent(filename)

        do {
            try data.write(to: url)
        } catch {
            throw CameraImportError.saveFailed(filename)
        }

        return url
    }

    // MARK: - Private

    private func resize(_ image: NSImage, quality: ImageQualityOption) -> NSImage {
        let size = image.size
        let maxDim = quality.maxDimension
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDim else { return image }
        let scale = maxDim / longestSide
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()
        return resized
    }

    private func nextScanNumber(in folder: URL) -> Int {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return 1
        }

        var maxNumber = 0
        for url in contents {
            let name = url.deletingPathExtension().lastPathComponent
            if name.hasPrefix("scan_"),
               let numberStr = name.split(separator: "_").last,
               let number = Int(numberStr) {
                maxNumber = max(maxNumber, number)
            }
        }

        return maxNumber + 1
    }

    private func saveAsHEIC(_ image: NSImage, folder: URL, filename: String, quality: ImageQualityOption) throws -> URL {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw CameraImportError.noImageData
        }

        let url = folder.appendingPathComponent(filename).appendingPathExtension("heic")

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            throw CameraImportError.saveFailed(filename + ".heic")
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality.compressionQuality
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CameraImportError.saveFailed(filename + ".heic")
        }

        return url
    }

    private func saveAsJPEG(_ image: NSImage, folder: URL, filename: String, quality: ImageQualityOption) throws -> URL {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality.compressionQuality]) else {
            throw CameraImportError.noImageData
        }

        let url = folder.appendingPathComponent(filename).appendingPathExtension("jpg")

        do {
            try jpegData.write(to: url)
        } catch {
            throw CameraImportError.saveFailed(filename + ".jpg")
        }

        return url
    }
}
