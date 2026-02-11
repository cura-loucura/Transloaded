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

        // Extract per-page: use native text when available, OCR otherwise
        var pages: [String] = []
        var usedOCR = false

        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }

            let nativeText = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if nativeText.count >= nativeTextThreshold {
                pages.append(nativeText)
            } else if let cgImage = renderPageToImage(page) {
                // Native text too short — OCR this page
                let result = try await ocrService.recognizeText(from: cgImage)
                if !result.text.isEmpty {
                    pages.append(result.text)
                    usedOCR = true
                } else if !nativeText.isEmpty {
                    pages.append(nativeText)
                }
            } else if !nativeText.isEmpty {
                pages.append(nativeText)
            }
        }

        let text = pages.joined(separator: "\n\n")

        if text.isEmpty {
            return PDFExtractionResult(text: "", pageCount: pageCount, extractionMethod: .empty)
        }

        return PDFExtractionResult(
            text: text,
            pageCount: pageCount,
            extractionMethod: usedOCR ? .ocr : .native
        )
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
