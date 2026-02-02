import Foundation

enum TranslationError: LocalizedError {
    case unsupportedPair(source: SupportedLanguage, target: SupportedLanguage)
    case downloadRequired(source: SupportedLanguage, target: SupportedLanguage)

    var errorDescription: String? {
        switch self {
        case .unsupportedPair(let source, let target):
            "Translation from \(source.displayName) to \(target.displayName) is not supported."
        case .downloadRequired(let source, let target):
            "Language pack for \(source.displayName) → \(target.displayName) needs to be downloaded first."
        }
    }
}
