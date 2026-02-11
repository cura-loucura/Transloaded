import Foundation
import Vision
import CoreGraphics
import ImageIO
import VisionKit
import AppKit

struct OCRResult: Sendable {
    let text: String
    let confidence: Float
}

actor OCRService {
    /// Minimum character count from Vision OCR to consider it successful.
    /// Below this, we fall back to ImageAnalyzer (Live Text) which handles
    /// vertical text, complex CJK layouts, etc.
    private let visionTextThreshold = 20

    func recognizeText(in url: URL) async throws -> OCRResult {
        let cgImage = try loadCGImage(from: url)
        return try await recognizeText(from: cgImage)
    }

    func recognizeText(from cgImage: CGImage) async throws -> OCRResult {
        let visionResult = try visionRecognizeText(from: cgImage)

        if visionResult.text.count >= visionTextThreshold {
            return visionResult
        }

        // Vision returned too little text — try ImageAnalyzer (Live Text)
        // which handles vertical text, complex CJK layouts, etc.
        if let liveTextResult = try? await liveTextRecognizeText(from: cgImage),
           liveTextResult.text.count > visionResult.text.count {
            return liveTextResult
        }

        return visionResult
    }

    // MARK: - Vision Framework OCR

    private func visionRecognizeText(from cgImage: CGImage) throws -> OCRResult {
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

    // MARK: - Live Text (ImageAnalyzer) Fallback

    private func liveTextRecognizeText(from cgImage: CGImage) async throws -> OCRResult? {
        let analyzer = ImageAnalyzer()
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        let config = ImageAnalyzer.Configuration([.text])
        let analysis = try await analyzer.analyze(nsImage, orientation: .up, configuration: config)
        let text = analysis.transcript
        guard !text.isEmpty else { return nil }
        return OCRResult(text: text, confidence: 0.9)
    }

    // MARK: - Private

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
