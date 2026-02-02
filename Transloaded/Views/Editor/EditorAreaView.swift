import SwiftUI

struct EditorAreaView: View {
    @Bindable var appState: AppState
    @Bindable var translationViewModel: TranslationViewModel
    @Bindable var settingsState: SettingsState

    var body: some View {
        VStack(spacing: 0) {
            if !appState.openFiles.isEmpty {
                header
                Divider()
            }

            if translationViewModel.isPreparingTranslation {
                languagePackStatus
            }

            contentArea
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            sourceLanguageSelector

            Divider()
                .frame(height: 20)

            FileTabBar(
                files: appState.openFiles,
                activeFileID: appState.activeFileID,
                onSelect: { appState.setActiveFile(id: $0) },
                onClose: { appState.closeFile(id: $0) }
            )

            Spacer()

            addTranslationButton
        }
    }

    // MARK: - Source Language Selector

    @ViewBuilder
    private var sourceLanguageSelector: some View {
        if let file = appState.activeFile {
            let currentLang = file.selectedSourceLanguage ?? file.detectedLanguage
            Menu {
                ForEach(settingsState.activeLanguages) { lang in
                    Button {
                        appState.setSourceLanguage(lang, for: file.id)
                        settingsState.lastSourceLanguage = lang
                    } label: {
                        HStack {
                            Text(lang.displayName)
                            if lang == currentLang {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currentLang?.displayName ?? "Detect")
                        .font(.system(size: 11))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    // MARK: - Add Translation Button

    @ViewBuilder
    private var addTranslationButton: some View {
        if let file = appState.activeFile {
            let openLanguages = appState.visibleTranslationPanels.map(\.targetLanguage)
            Menu {
                ForEach(settingsState.activeLanguages) { lang in
                    let isSource = lang == (file.selectedSourceLanguage ?? file.detectedLanguage)
                    let isOpen = openLanguages.contains(lang)
                    Button {
                        appState.addTranslation(for: file.id, language: lang)
                        settingsState.lastTargetLanguage = lang
                    } label: {
                        HStack {
                            Text(lang.displayName)
                            if isOpen {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(isSource || isOpen)
                }
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .help("Add translation panel")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.trailing, 8)
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        let panels = appState.visibleTranslationPanels
        if panels.isEmpty {
            FileContentView(
                file: appState.activeFile,
                onReload: { id in appState.reloadFile(id: id) },
                onDismissReload: { id in appState.dismissReloadBanner(id: id) }
            )
        } else {
            HSplitView {
                FileContentView(
                    file: appState.activeFile,
                    onReload: { id in appState.reloadFile(id: id) },
                    onDismissReload: { id in appState.dismissReloadBanner(id: id) }
                )
                .frame(minWidth: 300)

                ForEach(panels) { panel in
                    TranslationPanelView(
                        panel: panel,
                        onClose: { appState.closeTranslation(id: panel.id) },
                        onRetry: { appState.retryTranslation(panelID: panel.id) }
                    )
                }
            }
        }
    }

    // MARK: - Language Pack Status

    private var languagePackStatus: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text(translationViewModel.translationStatus)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.08))
    }
}
