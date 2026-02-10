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

    func saveImage(_ image: NSImage, to folder: URL) throws -> URL {
        let nextNumber = nextScanNumber(in: folder)
        let filename = String(format: "scan_%03d", nextNumber)

        // Try HEIC first, fall back to JPEG
        if let url = try? saveAsHEIC(image, folder: folder, filename: filename) {
            return url
        }

        return try saveAsJPEG(image, folder: folder, filename: filename)
    }

    // MARK: - Private

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

    private func saveAsHEIC(_ image: NSImage, folder: URL, filename: String) throws -> URL {
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

        CGImageDestinationAddImage(destination, cgImage, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw CameraImportError.saveFailed(filename + ".heic")
        }

        return url
    }

    private func saveAsJPEG(_ image: NSImage, folder: URL, filename: String) throws -> URL {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
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
