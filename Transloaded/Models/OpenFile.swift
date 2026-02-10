import Foundation

enum FileType: Sendable {
    case text
    case image
}

struct OpenFile: Identifiable {
    let id: UUID
    let url: URL
    let name: String
    var content: String
    var detectedLanguage: SupportedLanguage?
    var selectedSourceLanguage: SupportedLanguage?
    var isExternallyModified: Bool = false
    var fileType: FileType = .text
    var sourceImageURL: URL?
    var ocrConfidence: Float?

    static let scrapbookURL = URL(fileURLWithPath: "/dev/null/Scrapbook")

    var isScrapbook: Bool {
        url == Self.scrapbookURL
    }

    var isImage: Bool {
        fileType == .image
    }

    init(url: URL, name: String, content: String, detectedLanguage: SupportedLanguage? = nil, fileType: FileType = .text, sourceImageURL: URL? = nil, ocrConfidence: Float? = nil) {
        self.id = UUID()
        self.url = url
        self.name = name
        self.content = content
        self.detectedLanguage = detectedLanguage
        self.selectedSourceLanguage = detectedLanguage
        self.fileType = fileType
        self.sourceImageURL = sourceImageURL
        self.ocrConfidence = ocrConfidence
    }

    static func newScrapbook() -> OpenFile {
        OpenFile(url: scrapbookURL, name: "Scrapbook", content: "")
    }
}
