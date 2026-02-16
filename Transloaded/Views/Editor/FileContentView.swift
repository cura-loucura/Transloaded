import SwiftUI

struct FileContentView: View {
    let file: OpenFile?
    var font: Font = .system(.body, design: .monospaced)
    var onReload: ((UUID) -> Void)?
    var onDismissReload: ((UUID) -> Void)?
    var onScrapbookContentChange: ((String) -> Void)?
    var onScrapbookFocusLost: (() -> Void)?

    @FocusState private var isScrapbookFocused: Bool
    @State private var scrapbookText: String = ""

    var body: some View {
        if let file {
            if file.isScrapbook {
                scrapbookEditor(for: file)
            } else if file.isPDF {
                pdfContent(for: file)
            } else if file.isImage {
                imageContent(for: file)
            } else {
                fileContent(for: file)
            }
        } else {
            emptyState
        }
    }

    // MARK: - Scrapbook

    private func scrapbookEditor(for file: OpenFile) -> some View {
        TextEditor(text: $scrapbookText)
            .font(font)
            .focused($isScrapbookFocused)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                scrapbookText = file.content
            }
            .onChange(of: scrapbookText) { _, newValue in
                onScrapbookContentChange?(newValue)
            }
            .onChange(of: isScrapbookFocused) { _, focused in
                if !focused {
                    onScrapbookFocusLost?()
                }
            }
    }

    // MARK: - Text File

    private func fileContent(for file: OpenFile) -> some View {
        VStack(spacing: 0) {
            if file.isExternallyModified {
                reloadBanner(for: file)
            }

            ScrollView(.vertical) {
                Text(file.content)
                    .font(font)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Image File

    private func imageContent(for file: OpenFile) -> some View {
        VStack(spacing: 0) {
            if file.isExternallyModified {
                reloadBanner(for: file)
            }

            if let confidence = file.ocrConfidence, confidence < 0.5, !file.content.isEmpty {
                ocrWarningBanner
            }

            if file.content.isEmpty {
                ocrProcessingView
            } else {
                VSplitView {
                    imagePreview(for: file)
                        .frame(minHeight: 120)

                    ocrTextView(for: file)
                        .frame(minHeight: 80)
                }
            }
        }
    }

    private func imagePreview(for file: OpenFile) -> some View {
        Group {
            if let imageURL = file.sourceImageURL,
               let nsImage = NSImage(contentsOf: imageURL) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.03))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("Unable to load image preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func ocrTextView(for file: OpenFile) -> some View {
        VStack(spacing: 0) {
            HStack {
                Label("Extracted Text", systemImage: "text.viewfinder")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))

            Divider()

            ScrollView(.vertical) {
                Text(file.content)
                    .font(font)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var ocrProcessingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Extracting text from image...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var ocrWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 12))

            Text("OCR quality is low \u{2014} extracted text may be inaccurate.")
                .font(.system(size: 12))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.1))
    }

    // MARK: - PDF File

    private func pdfContent(for file: OpenFile) -> some View {
        VStack(spacing: 0) {
            if file.isExternallyModified {
                reloadBanner(for: file)
            }

            if let method = file.pdfExtractionMethod {
                pdfExtractionBanner(method: method, pageCount: file.pdfPageCount)
            }

            if file.content.isEmpty && file.pdfExtractionMethod == nil {
                pdfProcessingView
            } else if file.pdfExtractionMethod == "empty" {
                pdfEmptyWarning
            } else {
                VSplitView {
                    pdfPreview(for: file)
                        .frame(minHeight: 150)

                    pdfTextView(for: file)
                        .frame(minHeight: 80)
                }
            }
        }
    }

    private func pdfPreview(for file: OpenFile) -> some View {
        Group {
            if let pdfURL = file.sourcePDFURL {
                PDFKitView(url: pdfURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("Unable to load PDF preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func pdfTextView(for file: OpenFile) -> some View {
        VStack(spacing: 0) {
            HStack {
                Label("Extracted Text", systemImage: "text.viewfinder")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))

            Divider()

            ScrollView(.vertical) {
                Text(file.content)
                    .font(font)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func pdfExtractionBanner(method: String, pageCount: Int?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: method == "ocr" ? "eye.circle.fill" : "doc.text.fill")
                .foregroundStyle(.blue)
                .font(.system(size: 12))

            Group {
                switch method {
                case "native":
                    Text("Text extracted from \(pageCount ?? 0) page\(pageCount == 1 ? "" : "s")")
                case "ocr":
                    Text("Scanned PDF \u{2014} text extracted via OCR from \(pageCount ?? 0) page\(pageCount == 1 ? "" : "s")")
                case "empty":
                    Text("No text could be extracted from this PDF")
                default:
                    Text("Text extracted")
                }
            }
            .font(.system(size: 12))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(method == "empty" ? Color.yellow.opacity(0.1) : Color.blue.opacity(0.06))
    }

    private var pdfProcessingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Extracting text from PDF...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pdfEmptyWarning: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No text extracted")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("This PDF may contain only images or unsupported content.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Banners

    private func reloadBanner(for file: OpenFile) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12))

            Text("This file has been modified externally.")
                .font(.system(size: 12))

            Spacer()

            Button("Reload") {
                onReload?(file.id)
            }
            .controlSize(.small)

            Button("Dismiss") {
                onDismissReload?(file.id)
            }
            .controlSize(.small)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image("AppLogo")
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .opacity(0.35)
            Text("No file open")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(spacing: 4) {
                Text("Double-click a file in the sidebar to open it,")
                Text("drag files into the window,")
                Text("or use Edit \u{2192} Import from iPhone to capture with your camera")
            }
            .font(.subheadline)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
