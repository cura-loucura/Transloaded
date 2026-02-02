import Foundation

struct TranslationPanel: Identifiable {
    let id: UUID
    let fileID: UUID
    let targetLanguage: SupportedLanguage
    var translatedContent: String
    var isTranslating: Bool
    var error: String?

    init(fileID: UUID, targetLanguage: SupportedLanguage) {
        self.id = UUID()
        self.fileID = fileID
        self.targetLanguage = targetLanguage
        self.translatedContent = ""
        self.isTranslating = true
        self.error = nil
    }
}
