import Foundation

@Observable
@MainActor
class SettingsState {
    private static let activeLanguagesKey = "activeLanguages"
    private static let defaultSourceLanguageKey = "defaultSourceLanguage"
    private static let savePatternKey = "translationSavePattern"
    private static let lastSourceLanguageKey = "lastSourceLanguage"
    private static let lastTargetLanguageKey = "lastTargetLanguage"

    let allLanguages: [SupportedLanguage] = SupportedLanguage.allCases

    var activeLanguages: [SupportedLanguage] {
        didSet { saveActiveLanguages() }
    }

    var defaultSourceLanguage: SupportedLanguage? {
        didSet {
            UserDefaults.standard.set(defaultSourceLanguage?.rawValue, forKey: Self.defaultSourceLanguageKey)
        }
    }

    var translationSavePattern: String {
        didSet {
            UserDefaults.standard.set(translationSavePattern, forKey: Self.savePatternKey)
        }
    }

    var lastSourceLanguage: SupportedLanguage? {
        didSet {
            UserDefaults.standard.set(lastSourceLanguage?.rawValue, forKey: Self.lastSourceLanguageKey)
        }
    }

    var lastTargetLanguage: SupportedLanguage? {
        didSet {
            UserDefaults.standard.set(lastTargetLanguage?.rawValue, forKey: Self.lastTargetLanguageKey)
        }
    }

    init() {
        // Load active languages
        if let rawValues = UserDefaults.standard.stringArray(forKey: Self.activeLanguagesKey) {
            let loaded = rawValues.compactMap { SupportedLanguage(rawValue: $0) }
            self.activeLanguages = loaded.isEmpty ? SupportedLanguage.allCases : loaded
        } else {
            self.activeLanguages = SupportedLanguage.allCases
        }

        // Load default source language
        if let raw = UserDefaults.standard.string(forKey: Self.defaultSourceLanguageKey) {
            self.defaultSourceLanguage = SupportedLanguage(rawValue: raw)
        } else {
            self.defaultSourceLanguage = nil
        }

        // Load save pattern
        self.translationSavePattern = UserDefaults.standard.string(forKey: Self.savePatternKey) ?? "{name}_{lang}.{ext}"

        // Load last-used languages
        if let raw = UserDefaults.standard.string(forKey: Self.lastSourceLanguageKey) {
            self.lastSourceLanguage = SupportedLanguage(rawValue: raw)
        } else {
            self.lastSourceLanguage = nil
        }
        if let raw = UserDefaults.standard.string(forKey: Self.lastTargetLanguageKey) {
            self.lastTargetLanguage = SupportedLanguage(rawValue: raw)
        } else {
            self.lastTargetLanguage = nil
        }
    }

    func toggleLanguage(_ language: SupportedLanguage) {
        if activeLanguages.contains(language) {
            // Don't allow deactivating the last language
            guard activeLanguages.count > 1 else { return }
            activeLanguages.removeAll { $0 == language }
        } else {
            activeLanguages.append(language)
        }
    }

    func isLanguageActive(_ language: SupportedLanguage) -> Bool {
        activeLanguages.contains(language)
    }

    private func saveActiveLanguages() {
        let rawValues = activeLanguages.map(\.rawValue)
        UserDefaults.standard.set(rawValues, forKey: Self.activeLanguagesKey)
    }
}
