import Foundation
import Translation

@Observable
@MainActor
class TranslationViewModel {
    var translationStatus: String = ""
    var isPreparingTranslation: Bool = false
    var translationConfig: TranslationSession.Configuration?

    let translationService = TranslationService()
    private var pendingDownloadLegs: [(source: Locale.Language, target: Locale.Language, label: String)] = []

    func prepareTranslation(from source: SupportedLanguage, to target: SupportedLanguage) async {
        guard source != target else {
            isPreparingTranslation = false
            return
        }

        isPreparingTranslation = true
        pendingDownloadLegs = []

        let availability = LanguageAvailability()
        let sourceLocale = Locale.Language(identifier: source.languageCode)
        let targetLocale = Locale.Language(identifier: target.languageCode)
        let englishLocale = Locale.Language(identifier: "en")

        let directStatus = await availability.status(from: sourceLocale, to: targetLocale)

        switch directStatus {
        case .installed:
            // Already downloaded, cache session directly
            if #available(macOS 26.0, *) {
                await translationService.createSession(from: source, to: target)
            }
            isPreparingTranslation = false
            return

        case .supported:
            // Queue single download
            pendingDownloadLegs.append((
                source: sourceLocale,
                target: targetLocale,
                label: "\(source.displayName) → \(target.displayName)"
            ))

        case .unsupported:
            // Queue two-hop downloads through English
            let leg1Status = await availability.status(from: sourceLocale, to: englishLocale)
            let leg2Status = await availability.status(from: englishLocale, to: targetLocale)

            if leg1Status == .supported {
                pendingDownloadLegs.append((
                    source: sourceLocale,
                    target: englishLocale,
                    label: "\(source.displayName) → English"
                ))
            }
            if leg2Status == .supported {
                pendingDownloadLegs.append((
                    source: englishLocale,
                    target: targetLocale,
                    label: "English → \(target.displayName)"
                ))
            }

        @unknown default:
            break
        }

        triggerNextDownload()
    }

    private func triggerNextDownload() {
        guard let next = pendingDownloadLegs.first else {
            // All downloads complete
            translationStatus = ""
            isPreparingTranslation = false
            translationConfig = nil
            return
        }

        translationStatus = "Downloading: \(next.label)..."
        translationConfig = .init(source: next.source, target: next.target)
    }

    func onTranslationDownloadComplete() {
        translationConfig = nil
        if !pendingDownloadLegs.isEmpty {
            pendingDownloadLegs.removeFirst()
        }
        Task { @MainActor in
            triggerNextDownload()
        }
    }

    func onTranslationDownloadFailed(_ error: Error) {
        translationConfig = nil
        translationStatus = "Download failed: \(error.localizedDescription)"
        isPreparingTranslation = false
        pendingDownloadLegs = []
    }
}
