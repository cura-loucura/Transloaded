import SwiftUI

struct FileContentView: View {
    let file: OpenFile?
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
            } else {
                fileContent(for: file)
            }
        } else {
            emptyState
        }
    }

    private func scrapbookEditor(for file: OpenFile) -> some View {
        TextEditor(text: $scrapbookText)
            .font(.system(.body, design: .monospaced))
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

    private func fileContent(for file: OpenFile) -> some View {
        VStack(spacing: 0) {
            if file.isExternallyModified {
                reloadBanner(for: file)
            }

            ScrollView([.horizontal, .vertical]) {
                Text(file.content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No file open")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(spacing: 4) {
                Text("Double-click a file in the sidebar to open it")
                Text("or drag files and folders into the window")
            }
            .font(.subheadline)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
