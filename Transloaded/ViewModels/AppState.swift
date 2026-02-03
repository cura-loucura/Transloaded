import Foundation
import NaturalLanguage
import AppKit

@Observable
@MainActor
class AppState {
    var openFiles: [OpenFile] = []
    var activeFileID: UUID?
    var translationPanels: [TranslationPanel] = []
    var activeTranslationPanelID: UUID?

    private let fileSystemService = FileSystemService()
    private let fileWatcherService = FileWatcherService()
    var translationService: TranslationService?
    var translationViewModel: TranslationViewModel?
    var settingsState: SettingsState?
    var recentItemsManager: RecentItemsManager?

    private var panelsPendingDownload: Set<UUID> = []

    // Error alert state
    var showError: Bool = false
    var errorMessage: String = ""

    // Large file confirmation
    var showLargeFileAlert: Bool = false
    var pendingLargeFileURL: URL?
    static let largeFileThreshold = 1_000_000 // 1MB

    var activeFile: OpenFile? {
        guard let id = activeFileID else { return nil }
        return openFiles.first { $0.id == id }
    }

    var visibleTranslationPanels: [TranslationPanel] {
        guard let id = activeFileID else { return [] }
        return translationPanels.filter { $0.fileID == id }
    }

    // MARK: - File Management

    func openFile(url: URL) {
        if let existing = openFiles.first(where: { $0.url == url }) {
            activeFileID = existing.id
            return
        }

        // Check file size before opening
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int,
           size > Self.largeFileThreshold {
            pendingLargeFileURL = url
            showLargeFileAlert = true
            return
        }

        performOpenFile(url: url)
    }

    func confirmOpenLargeFile() {
        guard let url = pendingLargeFileURL else { return }
        pendingLargeFileURL = nil
        showLargeFileAlert = false
        performOpenFile(url: url)
    }

    func cancelOpenLargeFile() {
        pendingLargeFileURL = nil
        showLargeFileAlert = false
    }

    /// Opens a file without triggering auto-translate, used during session restore.
    func restoreFile(url: URL) {
        if openFiles.contains(where: { $0.url == url }) { return }

        do {
            let content = try fileSystemService.readFileContent(at: url)
            let detected = detectLanguage(for: content) ?? settingsState?.defaultSourceLanguage
            let file = OpenFile(
                url: url,
                name: url.lastPathComponent,
                content: content,
                detectedLanguage: detected
            )
            openFiles.append(file)
            activeFileID = file.id

            fileWatcherService.watch(url: url) { [weak self] changedURL in
                Task { @MainActor in
                    self?.markFileAsExternallyModified(url: changedURL)
                }
            }
        } catch {
            // Silently skip files that can't be read during restore
        }
    }

    private func performOpenFile(url: URL) {
        do {
            let content = try fileSystemService.readFileContent(at: url)
            let detected = detectLanguage(for: content) ?? settingsState?.defaultSourceLanguage
            let file = OpenFile(
                url: url,
                name: url.lastPathComponent,
                content: content,
                detectedLanguage: detected
            )
            openFiles.append(file)
            activeFileID = file.id
            recentItemsManager?.addRecentFile(url)

            // Auto-open translation panel if default target language is set and differs from source
            if let targetLang = settingsState?.defaultTargetLanguage,
               targetLang != detected {
                addTranslation(for: file.id, language: targetLang)
            }

            fileWatcherService.watch(url: url) { [weak self] changedURL in
                Task { @MainActor in
                    self?.markFileAsExternallyModified(url: changedURL)
                }
            }
        } catch {
            errorMessage = "Failed to open \(url.lastPathComponent): \(error.localizedDescription)"
            showError = true
        }
    }

    func closeActiveFile() {
        guard let id = activeFileID else { return }
        closeFile(id: id)
    }

    func reloadActiveFile() {
        guard let id = activeFileID else { return }
        reloadFile(id: id)
    }

    func closeFile(id: UUID) {
        if let file = openFiles.first(where: { $0.id == id }) {
            fileWatcherService.stopWatching(url: file.url)
        }
        translationPanels.removeAll { $0.fileID == id }
        openFiles.removeAll { $0.id == id }

        if activeFileID == id {
            activeFileID = openFiles.last?.id
        }
    }

    func setActiveFile(id: UUID) {
        guard openFiles.contains(where: { $0.id == id }) else { return }
        activeFileID = id
    }

    // MARK: - External Modification / Reload

    private func markFileAsExternallyModified(url: URL) {
        guard let index = openFiles.firstIndex(where: { $0.url == url }) else { return }
        openFiles[index].isExternallyModified = true
    }

    func reloadFile(id: UUID) {
        guard let index = openFiles.firstIndex(where: { $0.id == id }) else { return }
        let url = openFiles[index].url
        do {
            let content = try fileSystemService.readFileContent(at: url)
            openFiles[index].content = content
            openFiles[index].isExternallyModified = false
            let detected = detectLanguage(for: content)
            openFiles[index].detectedLanguage = detected

            retranslateAllPanels(for: id)
        } catch {
            errorMessage = "Failed to reload \(url.lastPathComponent): \(error.localizedDescription)"
            showError = true
        }
    }

    func dismissReloadBanner(id: UUID) {
        guard let index = openFiles.firstIndex(where: { $0.id == id }) else { return }
        openFiles[index].isExternallyModified = false
    }

    // MARK: - Source Language

    func setSourceLanguage(_ language: SupportedLanguage, for fileID: UUID) {
        guard let index = openFiles.firstIndex(where: { $0.id == fileID }) else { return }
        openFiles[index].selectedSourceLanguage = language
        retranslateAllPanels(for: fileID)
    }

    // MARK: - Translation Panels

    func addTranslation(for fileID: UUID, language: SupportedLanguage) {
        if translationPanels.contains(where: { $0.fileID == fileID && $0.targetLanguage == language }) {
            return
        }

        let panel = TranslationPanel(fileID: fileID, targetLanguage: language)
        translationPanels.append(panel)
        activeTranslationPanelID = panel.id
        translateContent(panelID: panel.id)
    }

    func closeTranslation(id: UUID) {
        translationPanels.removeAll { $0.id == id }
        if activeTranslationPanelID == id {
            activeTranslationPanelID = visibleTranslationPanels.last?.id
        }
    }

    func retryTranslation(panelID: UUID) {
        translateContent(panelID: panelID)
    }

    func retryPendingDownloads() {
        let pending = panelsPendingDownload
        panelsPendingDownload.removeAll()
        for panelID in pending {
            translateContent(panelID: panelID)
        }
    }

    private func retranslateAllPanels(for fileID: UUID) {
        for panel in translationPanels where panel.fileID == fileID {
            translateContent(panelID: panel.id)
        }
    }

    private func translateContent(panelID: UUID) {
        guard let panelIndex = translationPanels.firstIndex(where: { $0.id == panelID }) else { return }
        let panel = translationPanels[panelIndex]
        guard let file = openFiles.first(where: { $0.id == panel.fileID }) else { return }
        guard let source = file.selectedSourceLanguage ?? file.detectedLanguage else {
            translationPanels[panelIndex].error = "Source language unknown"
            translationPanels[panelIndex].isTranslating = false
            return
        }
        guard let service = translationService else { return }

        translationPanels[panelIndex].isTranslating = true
        translationPanels[panelIndex].error = nil

        let content = file.content
        let target = panel.targetLanguage

        Task {
            do {
                let translated = try await service.translate(text: content, from: source, to: target)
                if let idx = translationPanels.firstIndex(where: { $0.id == panelID }) {
                    translationPanels[idx].translatedContent = translated
                    translationPanels[idx].isTranslating = false
                }
            } catch let translationError as TranslationError {
                if case .downloadRequired(let src, let tgt) = translationError {
                    // Keep panel in translating state while downloading
                    panelsPendingDownload.insert(panelID)
                    await translationViewModel?.prepareTranslation(from: src, to: tgt)
                } else {
                    if let idx = translationPanels.firstIndex(where: { $0.id == panelID }) {
                        translationPanels[idx].error = translationError.localizedDescription
                        translationPanels[idx].isTranslating = false
                    }
                }
            } catch {
                if let idx = translationPanels.firstIndex(where: { $0.id == panelID }) {
                    translationPanels[idx].error = error.localizedDescription
                    translationPanels[idx].isTranslating = false
                }
            }
        }
    }

    // MARK: - Scrapbook

    // Close scrapbook alert state
    var showCloseScrapbookAlert: Bool = false
    private var pendingCloseScrapbookID: UUID?
    private var scrapbookDetectionTask: Task<Void, Never>?

    func openScrapbook() {
        // If scrapbook is already open, just switch to it
        if let existing = openFiles.first(where: { $0.isScrapbook }) {
            activeFileID = existing.id
            return
        }

        let scrapbook = OpenFile.newScrapbook()
        openFiles.insert(scrapbook, at: 0)
        activeFileID = scrapbook.id
    }

    func closeScrapbook(id: UUID) {
        guard let file = openFiles.first(where: { $0.id == id }),
              file.isScrapbook else { return }

        if !file.content.isEmpty {
            pendingCloseScrapbookID = id
            showCloseScrapbookAlert = true
        } else {
            closeFile(id: id)
        }
    }

    func confirmCloseScrapbook() {
        guard let id = pendingCloseScrapbookID else { return }
        pendingCloseScrapbookID = nil
        showCloseScrapbookAlert = false
        closeFile(id: id)
    }

    func cancelCloseScrapbook() {
        pendingCloseScrapbookID = nil
        showCloseScrapbookAlert = false
    }

    func updateScrapbookContent(_ content: String) {
        guard let index = openFiles.firstIndex(where: { $0.isScrapbook }) else { return }
        openFiles[index].content = content

        // Debounce: after 800ms of no further edits, detect language & retranslate
        scrapbookDetectionTask?.cancel()
        scrapbookDetectionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.detectAndRetranslateScrapbook()
        }
    }

    func onScrapbookFocusLost() {
        scrapbookDetectionTask?.cancel()
        detectAndRetranslateScrapbook()
    }

    private func detectAndRetranslateScrapbook() {
        guard let index = openFiles.firstIndex(where: { $0.isScrapbook }),
              !openFiles[index].content.isEmpty else { return }
        let detected = detectLanguage(for: openFiles[index].content)
        openFiles[index].detectedLanguage = detected
        if openFiles[index].selectedSourceLanguage == nil {
            openFiles[index].selectedSourceLanguage = detected
        }
        retranslateAllPanels(for: openFiles[index].id)
    }

    // MARK: - Save Translation

    func saveActiveTranslation() {
        guard let panelID = activeTranslationPanelID,
              let panel = translationPanels.first(where: { $0.id == panelID }),
              let file = openFiles.first(where: { $0.id == panel.fileID }) else { return }

        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = defaultSaveURL(for: file.url, language: panel.targetLanguage).lastPathComponent
        savePanel.directoryURL = file.url.deletingLastPathComponent()

        guard savePanel.runModal() == .OK, let url = savePanel.url else { return }

        do {
            try panel.translatedContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = "Failed to save translation: \(error.localizedDescription)"
            showError = true
        }
    }

    private func defaultSaveURL(for originalURL: URL, language: SupportedLanguage) -> URL {
        let dir = originalURL.deletingLastPathComponent()
        let name = originalURL.deletingPathExtension().lastPathComponent
        let ext = originalURL.pathExtension
        let langCode = language.languageCode

        let pattern = settingsState?.translationSavePattern ?? "{name}_{lang}.{ext}"
        var filename = pattern
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{lang}", with: langCode)
            .replacingOccurrences(of: "{ext}", with: ext)

        // If ext is empty, trim trailing dot
        if ext.isEmpty {
            filename = filename.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }

        return dir.appendingPathComponent(filename)
    }

    // MARK: - Language Detection

    private func detectLanguage(for text: String) -> SupportedLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let dominant = recognizer.dominantLanguage else { return nil }

        switch dominant {
        case .arabic: return .arabic
        case .simplifiedChinese: return .chineseSimplified
        case .traditionalChinese: return .chineseTraditional
        case .dutch: return .dutch
        case .english: return .english
        case .french: return .french
        case .german: return .german
        case .hindi: return .hindi
        case .indonesian: return .indonesian
        case .italian: return .italian
        case .japanese: return .japanese
        case .korean: return .korean
        case .polish: return .polish
        case .portuguese: return .portuguese
        case .russian: return .russian
        case .spanish: return .spanish
        case .thai: return .thai
        case .turkish: return .turkish
        case .ukrainian: return .ukrainian
        case .vietnamese: return .vietnamese
        default: return nil
        }
    }
}
