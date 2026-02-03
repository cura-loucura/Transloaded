import Foundation

enum SupportedLanguage: String, CaseIterable, Identifiable, Codable, Hashable {
    case arabic = "ar"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case dutch = "nl"
    case english = "en-US"
    case french = "fr-FR"
    case german = "de"
    case hindi = "hi"
    case indonesian = "id"
    case italian = "it"
    case japanese = "ja-JP"
    case korean = "ko"
    case polish = "pl"
    case portuguese = "pt-BR"
    case russian = "ru"
    case spanish = "es"
    case thai = "th"
    case turkish = "tr"
    case ukrainian = "uk"
    case vietnamese = "vi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arabic: "Arabic"
        case .chineseSimplified: "Chinese (Simplified)"
        case .chineseTraditional: "Chinese (Traditional)"
        case .dutch: "Dutch"
        case .english: "English"
        case .french: "French"
        case .german: "German"
        case .hindi: "Hindi"
        case .indonesian: "Indonesian"
        case .italian: "Italian"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .polish: "Polish"
        case .portuguese: "Portuguese"
        case .russian: "Russian"
        case .spanish: "Spanish"
        case .thai: "Thai"
        case .turkish: "Turkish"
        case .ukrainian: "Ukrainian"
        case .vietnamese: "Vietnamese"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    /// Short code used by the Translation framework
    var languageCode: String {
        switch self {
        case .arabic: "ar"
        case .chineseSimplified: "zh-Hans"
        case .chineseTraditional: "zh-Hant"
        case .dutch: "nl"
        case .english: "en"
        case .french: "fr"
        case .german: "de"
        case .hindi: "hi"
        case .indonesian: "id"
        case .italian: "it"
        case .japanese: "ja"
        case .korean: "ko"
        case .polish: "pl"
        case .portuguese: "pt"
        case .russian: "ru"
        case .spanish: "es"
        case .thai: "th"
        case .turkish: "tr"
        case .ukrainian: "uk"
        case .vietnamese: "vi"
        }
    }

    /// The original 4 languages that ship as defaults
    static let defaultActive: [SupportedLanguage] = [.english, .french, .japanese, .portuguese]
}
