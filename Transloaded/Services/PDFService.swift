import Foundation
import PDFKit
import CoreGraphics

enum ExtractionMethod: String, Sendable {
    case native
    case ocr
    case empty
}

struct PDFExtractionResult: Sendable {
    let text: String
    let pageCount: Int
    let extractionMethod: ExtractionMethod
}

enum PDFError: LocalizedError {
    case documentLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .documentLoadFailed(let name):
            return "Failed to load PDF: \(name)"
        }
    }
}

actor PDFService {
    private let ocrService = OCRService()

    /// Minimum character count from native extraction to consider it successful.
    /// Below this threshold, we assume the PDF is scanned and fall back to OCR.
    private let nativeTextThreshold = 20

    func extractText(from url: URL) async throws -> PDFExtractionResult {
        guard let document = PDFDocument(url: url) else {
            throw PDFError.documentLoadFailed(url.lastPathComponent)
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else {
            return PDFExtractionResult(text: "", pageCount: 0, extractionMethod: .empty)
        }

        // Try native text extraction first
        let nativeText = extractNativeText(from: document)

        if nativeText.count >= nativeTextThreshold {
            return PDFExtractionResult(
                text: nativeText,
                pageCount: pageCount,
                extractionMethod: .native
            )
        }

        // Native extraction yielded little/no text — fall back to OCR
        let ocrText = try await extractTextViaOCR(from: document)

        if ocrText.isEmpty {
            return PDFExtractionResult(text: "", pageCount: pageCount, extractionMethod: .empty)
        }

        return PDFExtractionResult(
            text: ocrText,
            pageCount: pageCount,
            extractionMethod: .ocr
        )
    }

    // MARK: - Native Extraction

    private func extractNativeText(from document: PDFDocument) -> String {
        var pages: [String] = []

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            if let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pages.append(text)
            }
        }

        return pages.joined(separator: "\n\n")
    }

    // MARK: - OCR Fallback

    private func extractTextViaOCR(from document: PDFDocument) async throws -> String {
        var pages: [String] = []

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            guard let cgImage = renderPageToImage(page) else { continue }

            let result = try await ocrService.recognizeText(from: cgImage)
            if !result.text.isEmpty {
                pages.append(result.text)
            }
        }

        return pages.joined(separator: "\n\n")
    }

    private func renderPageToImage(_ page: PDFPage, dpi: CGFloat = 300) -> CGImage? {
        let pageRect = page.bounds(for: .mediaBox)
        // Scale from 72 DPI (PDF points) to target DPI
        let scale = dpi / 72.0
        let width = Int(pageRect.width * scale)
        let height = Int(pageRect.height * scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        // White background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        context.scaleBy(x: scale, y: scale)

        // PDFPage.draw applies the page's own transforms
        page.draw(with: .mediaBox, to: context)

        return context.makeImage()
    }
}
