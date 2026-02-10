import Foundation
import Vision
import CoreGraphics
import ImageIO

struct OCRResult: Sendable {
    let text: String
    let confidence: Float
}

actor OCRService {
    func recognizeText(in url: URL) async throws -> OCRResult {
        let cgImage = try loadCGImage(from: url)
        return try recognizeText(from: cgImage)
    }

    func recognizeText(from cgImage: CGImage) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // Enable all supported languages so CJK scripts (Japanese, Chinese, Korean) are recognized
        let supportedLanguages = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = supportedLanguages
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            return OCRResult(text: "", confidence: 0)
        }

        var lines: [String] = []
        var totalConfidence: Float = 0

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            lines.append(candidate.string)
            totalConfidence += candidate.confidence
        }

        let averageConfidence = totalConfidence / Float(observations.count)
        let fullText = lines.joined(separator: "\n")

        return OCRResult(text: fullText, confidence: averageConfidence)
    }

    private func loadCGImage(from url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw OCRError.imageLoadFailed(url.lastPathComponent)
        }
        return cgImage
    }
}

enum OCRError: LocalizedError {
    case imageLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageLoadFailed(let name):
            return "Failed to load image: \(name)"
        }
    }
}
