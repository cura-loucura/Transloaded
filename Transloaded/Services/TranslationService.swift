import Foundation
import Translation

extension TranslationSession: @retroactive @unchecked Sendable {}

actor TranslationService {
    private var sessions: [String: TranslationSession] = [:]

    private func sessionKey(from source: SupportedLanguage, to target: SupportedLanguage) -> String {
        "\(source.languageCode)-\(target.languageCode)"
    }

    /// Translate text, falling back to two-hop through English if direct pair unavailable.
    /// Throws `.downloadRequired` if language packs need to be downloaded first.
    func translate(
        text: String,
        from source: SupportedLanguage,
        to target: SupportedLanguage
    ) async throws -> String {
        guard source != target else { return text }

        let key = sessionKey(from: source, to: target)

        if let existing = sessions[key] {
            let response = try await existing.translate(text)
            return response.targetText
        }

        let availability = LanguageAvailability()
        let sourceLocale = Locale.Language(identifier: source.languageCode)
        let targetLocale = Locale.Language(identifier: target.languageCode)
        let status = await availability.status(from: sourceLocale, to: targetLocale)

        switch status {
        case .installed:
            if #available(macOS 26.0, *) {
                let newSession = TranslationSession(installedSource: sourceLocale, target: targetLocale)
                sessions[key] = newSession
                let response = try await newSession.translate(text)
                return response.targetText
            } else {
                throw TranslationError.downloadRequired(source: source, target: target)
            }

        case .supported:
            // Pack not downloaded — caller must trigger download via .translationTask first
            throw TranslationError.downloadRequired(source: source, target: target)

        case .unsupported:
            // Two-hop fallback through English
            return try await twoHopTranslate(text: text, from: source, to: target)

        @unknown default:
            throw TranslationError.unsupportedPair(source: source, target: target)
        }
    }

    /// Translates via English as intermediate language
    private func twoHopTranslate(
        text: String,
        from source: SupportedLanguage,
        to target: SupportedLanguage
    ) async throws -> String {
        let englishText = try await translate(text: text, from: source, to: .english)
        return try await translate(text: englishText, from: .english, to: target)
    }

    /// Create and cache a session for an installed language pair
    @available(macOS 26.0, *)
    func createSession(
        from source: SupportedLanguage,
        to target: SupportedLanguage
    ) {
        let key = sessionKey(from: source, to: target)
        guard sessions[key] == nil else { return }

        let sourceLocale = Locale.Language(identifier: source.languageCode)
        let targetLocale = Locale.Language(identifier: target.languageCode)
        sessions[key] = TranslationSession(installedSource: sourceLocale, target: targetLocale)
    }

    /// Check if a language pair is ready, downloadable, or unsupported
    func checkAvailability(
        from source: SupportedLanguage,
        to target: SupportedLanguage
    ) async -> LanguageAvailability.Status {
        let availability = LanguageAvailability()
        let sourceLocale = Locale.Language(identifier: source.languageCode)
        let targetLocale = Locale.Language(identifier: target.languageCode)
        return await availability.status(from: sourceLocale, to: targetLocale)
    }

    /// Returns human-readable list of downloads needed for a language pair
    func requiredDownloads(
        from source: SupportedLanguage,
        to target: SupportedLanguage
    ) async -> [String] {
        var downloads: [String] = []
        let availability = LanguageAvailability()

        let sourceLocale = Locale.Language(identifier: source.languageCode)
        let targetLocale = Locale.Language(identifier: target.languageCode)
        let englishLocale = Locale.Language(identifier: "en")

        let directStatus = await availability.status(from: sourceLocale, to: targetLocale)

        switch directStatus {
        case .installed:
            return []
        case .supported:
            downloads.append("\(source.displayName) → \(target.displayName)")
        case .unsupported:
            let leg1 = await availability.status(from: sourceLocale, to: englishLocale)
            let leg2 = await availability.status(from: englishLocale, to: targetLocale)
            if leg1 == .supported {
                downloads.append("\(source.displayName) → English")
            }
            if leg2 == .supported {
                downloads.append("English → \(target.displayName)")
            }
        @unknown default:
            break
        }

        return downloads
    }

    /// Prepare a language pair by ensuring a session exists when packs are installed
    /// Returns the availability status so callers can decide to trigger downloads
    func prepareLanguagePair(
        from source: SupportedLanguage,
        to target: SupportedLanguage
    ) async -> LanguageAvailability.Status {
        let availability = LanguageAvailability()
        let sourceLocale = Locale.Language(identifier: source.languageCode)
        let targetLocale = Locale.Language(identifier: target.languageCode)
        let status = await availability.status(from: sourceLocale, to: targetLocale)

        if case .installed = status {
            if #available(macOS 26.0, *) {
                let key = sessionKey(from: source, to: target)
                if sessions[key] == nil {
                    let session = TranslationSession(installedSource: sourceLocale, target: targetLocale)
                    sessions[key] = session
                }
            }
        }
        return status
    }

    func clearSessions() {
        sessions.removeAll()
    }
}

