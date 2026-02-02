import Foundation

struct OpenFile: Identifiable {
    let id: UUID
    let url: URL
    let name: String
    var content: String
    var detectedLanguage: SupportedLanguage?
    var selectedSourceLanguage: SupportedLanguage?
    var isExternallyModified: Bool = false

    init(url: URL, name: String, content: String, detectedLanguage: SupportedLanguage? = nil) {
        self.id = UUID()
        self.url = url
        self.name = name
        self.content = content
        self.detectedLanguage = detectedLanguage
        self.selectedSourceLanguage = detectedLanguage
    }
}
