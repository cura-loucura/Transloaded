import Foundation
import Translation

@Observable
@MainActor
class TranslationViewModel {
    // Public state
    var translationStatus: String = ""
    var isPreparingTranslation: Bool = false

    // The configuration used by the `.translationTask` view modifier
    // Use optional so we can set to nil when idle
    var translationConfig: TranslationDownloadConfiguration? = nil

    // Internal queue of pending download legs (source -> target)
    private var pendingDownloadLegs: [(SupportedLanguage, SupportedLanguage)] = []

    // Service dependency
    private let service = TranslationService()

    // MARK: - Public API

    /// Prepare translation by ensuring language packs are available.
    /// If packs are missing, enqueue required legs and trigger downloads via `.translationTask`.
    func prepareTranslation(from source: SupportedLanguage, to target: SupportedLanguage) async {
        isPreparingTranslation = true
        translationStatus = "Checking language packs…"

        // Ask the service for availability and required download legs
        let status = await service.prepareLanguagePair(from: source, to: target)

        switch status {
        case .installed:
            // Nothing to download
            translationStatus = "Language packs installed"
            isPreparingTranslation = false
        case .supported, .unsupported:
            // Build a list of required downloads using requiredDownloads helper for user-friendly status
            let needed = await service.requiredDownloads(from: source, to: target)
            if needed.isEmpty {
                // Unsupported without a download path
                translationStatus = "Language pair unsupported"
                isPreparingTranslation = false
                return
            }

            // Populate pending legs by checking actual availability per leg
            await enqueueMissingLegs(from: source, to: target)
            triggerNextDownload()
        @unknown default:
            translationStatus = "Unknown availability status"
            isPreparingTranslation = false
        }
    }

    /// Called by the `.translationTask` handler when a download finishes
    func onTranslationDownloadComplete() async {
        if let finished = translationConfig {
            translationStatus = "Installed: \(finished.displayName)"
        }
        translationConfig = nil
        triggerNextDownload()
    }

    /// Called by the `.translationTask` handler when a download fails
    func onTranslationDownloadFailed(_ error: Error) async {
        translationStatus = "Download failed: \(error.localizedDescription)"
        translationConfig = nil
        // Continue with next to avoid getting stuck; user can retry if needed
        triggerNextDownload()
    }

    // MARK: - Private helpers

    private func enqueueMissingLegs(from source: SupportedLanguage, to target: SupportedLanguage) async {
        pendingDownloadLegs.removeAll()
        let availability = await service.checkAvailability(from: source, to: target)
        switch availability {
        case .installed:
            break
        case .supported:
            pendingDownloadLegs.append((source, target))
        case .unsupported:
            // Check legs through English
            let leg1 = await service.checkAvailability(from: source, to: .english)
            if case .supported = leg1 { pendingDownloadLegs.append((source, .english)) }

            let leg2 = await service.checkAvailability(from: .english, to: target)
            if case .supported = leg2 { pendingDownloadLegs.append((.english, target)) }
        @unknown default:
            break
        }
    }

    /// Triggers the next download by setting `translationConfig`.
    /// If queue is empty, clears preparing state.
    func triggerNextDownload() {
        guard translationConfig == nil else { return }
        guard !pendingDownloadLegs.isEmpty else {
            isPreparingTranslation = false
            if translationStatus.isEmpty { translationStatus = "Ready" }
            return
        }

        let (source, target) = pendingDownloadLegs.removeFirst()
        translationStatus = "Downloading: \(source.displayName) → \(target.displayName)…"
        translationConfig = TranslationDownloadConfiguration(source: source, target: target)
    }
}
// MARK: - TranslationDownloadConfiguration

/// A lightweight wrapper to drive the `.translationTask` view modifier
/// around a pair of languages. The actual download is handled by the system.
struct TranslationDownloadConfiguration: Equatable {
    let source: SupportedLanguage
    let target: SupportedLanguage

    var displayName: String { "\(source.displayName) → \(target.displayName)" }
}

