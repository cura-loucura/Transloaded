import Foundation
import Translation

@Observable
@MainActor
class TranslationViewModel {

    // MARK: - Per-panel download state
    var translationStatus: String = ""
    var isPreparingTranslation: Bool = false
    var translationConfig: TranslationSession.Configuration?
    /// Incremented each time translationConfig is set to force .translationTask to re-trigger
    var translationTaskID: Int = 0

    let translationService = TranslationService()
    var onAllDownloadsComplete: (() -> Void)?

    // MARK: - Shared download queue
    private var downloadQueue: [(source: Locale.Language, target: Locale.Language)] = []
    private var currentDownloadSource: Locale.Language?
    private var currentDownloadTarget: Locale.Language?

    // MARK: - Translation-triggered download (from panel)

    func prepareTranslation(from source: SupportedLanguage, to target: SupportedLanguage) async {
        guard source != target else {
            isPreparingTranslation = false
            return
        }

        isPreparingTranslation = true

        let availability = LanguageAvailability()
        let sourceLocale = Locale.Language(identifier: source.languageCode)
        let targetLocale = Locale.Language(identifier: target.languageCode)
        let englishLocale = Locale.Language(identifier: "en")

        let directStatus = await availability.status(from: sourceLocale, to: targetLocale)

        var newLegs: [(source: Locale.Language, target: Locale.Language)] = []

        switch directStatus {
        case .installed:
            if #available(macOS 26.0, *) {
                await translationService.createSession(from: source, to: target)
            }
            isPreparingTranslation = false
            return

        case .supported:
            newLegs.append((source: sourceLocale, target: targetLocale))

        case .unsupported:
            let leg1Status = await availability.status(from: sourceLocale, to: englishLocale)
            let leg2Status = await availability.status(from: englishLocale, to: targetLocale)

            if leg1Status == .supported {
                newLegs.append((source: sourceLocale, target: englishLocale))
            }
            if leg2Status == .supported {
                newLegs.append((source: englishLocale, target: targetLocale))
            }

        @unknown default:
            break
        }

        // Insert at front (priority over bulk downloads)
        downloadQueue.insert(contentsOf: newLegs, at: 0)
        await advanceQueue()
    }

    // MARK: - Bulk download (from Settings)

    func startBulkDownload(pairs: [(source: SupportedLanguage, target: SupportedLanguage)]) async {
        let availability = LanguageAvailability()
        let englishLocale = Locale.Language(identifier: "en")

        // Collect needed downloads, handling English pivot for unsupported pairs
        var seen = Set<String>()
        var needed: [(source: Locale.Language, target: Locale.Language)] = []

        for pair in pairs {
            let sourceLocale = Locale.Language(identifier: pair.source.languageCode)
            let targetLocale = Locale.Language(identifier: pair.target.languageCode)
            let status = await availability.status(from: sourceLocale, to: targetLocale)

            switch status {
            case .supported:
                let key = "\(pair.source.languageCode)>\(pair.target.languageCode)"
                if seen.insert(key).inserted {
                    needed.append((source: sourceLocale, target: targetLocale))
                }

            case .unsupported:
                // Needs English pivot — add the individual legs if not already downloaded
                let leg1Status = await availability.status(from: sourceLocale, to: englishLocale)
                if leg1Status == .supported {
                    let key = "\(pair.source.languageCode)>en"
                    if seen.insert(key).inserted {
                        needed.append((source: sourceLocale, target: englishLocale))
                    }
                }
                let leg2Status = await availability.status(from: englishLocale, to: targetLocale)
                if leg2Status == .supported {
                    let key = "en>\(pair.target.languageCode)"
                    if seen.insert(key).inserted {
                        needed.append((source: englishLocale, target: targetLocale))
                    }
                }

            default:
                break
            }
        }

        guard !needed.isEmpty else { return }

        downloadQueue.append(contentsOf: needed)

        if translationConfig == nil {
            await advanceQueue()
        }
    }

    // MARK: - Download engine

    /// Advances to the next pair that still needs downloading, skipping already-installed ones.
    private func advanceQueue() async {
        let availability = LanguageAvailability()

        while let next = downloadQueue.first {
            downloadQueue.removeFirst()
            let status = await availability.status(from: next.source, to: next.target)
            if status != .installed {
                currentDownloadSource = next.source
                currentDownloadTarget = next.target
                translationConfig = .init(source: next.source, target: next.target)
                translationTaskID += 1
                return
            }
        }

        // Queue empty — all done
        currentDownloadSource = nil
        currentDownloadTarget = nil
        translationStatus = ""
        isPreparingTranslation = false
        translationConfig = nil
        onAllDownloadsComplete?()
    }

    /// Called by ContentView after session.prepareTranslation() succeeds.
    /// Re-checks actual installation status — pressing "Done" without
    /// downloading still completes prepareTranslation() without throwing.
    func verifyAndCompleteDownload() async {
        guard let src = currentDownloadSource, let tgt = currentDownloadTarget else {
            await advanceQueue()
            return
        }
        let status = await LanguageAvailability().status(from: src, to: tgt)
        if status == .installed {
            await advanceQueue()
        } else {
            // User dismissed without downloading — skip to next pair
            await advanceQueue()
        }
    }

    func onTranslationDownloadFailed(_ error: Error) {
        downloadQueue.removeAll()
        currentDownloadSource = nil
        currentDownloadTarget = nil
        translationConfig = nil
        translationStatus = "Download failed: \(error.localizedDescription)"
        isPreparingTranslation = false
    }
}
