import SwiftUI

struct SettingsView: View {
    @Bindable var settingsState: SettingsState
    @Bindable var translationViewModel: TranslationViewModel

    var body: some View {
        TabView {
            languagesTab
                .tabItem {
                    Label("Languages", systemImage: "globe")
                }

            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 450, height: 450)
    }

    // MARK: - Reference Language

    private var referenceLanguage: SupportedLanguage {
        settingsState.defaultSourceLanguage ?? settingsState.osLanguage
    }

    // MARK: - Languages Tab

    private var languagesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            downloadSection

            Divider()

            Text("Active Languages")
                .font(.headline)

            Text("Toggle which languages appear in the source and target language menus. At least one must remain active.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach(settingsState.allLanguages) { lang in
                    let isOSLanguage = lang == settingsState.osLanguage
                    HStack {
                        Toggle(isOn: Binding(
                            get: { settingsState.isLanguageActive(lang) },
                            set: { _ in settingsState.toggleLanguage(lang) }
                        )) {
                            Text(lang.displayName)
                        }
                        .toggleStyle(.switch)
                        .disabled(isOSLanguage)

                        Spacer()

                        if isOSLanguage {
                            Text("System")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(lang.languageCode)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .monospaced()
                    }
                }
            }
            .listStyle(.bordered)
        }
        .padding()
    }

    @ViewBuilder
    private var downloadSection: some View {
        let langs = settingsState.activeLanguages
        let ref = referenceLanguage
        let othersCount = langs.count - 1

        VStack(alignment: .leading, spacing: 8) {
            Text("Download Language Packs")
                .font(.headline)

            Text("Pre-download translation packs for offline use. A system dialog will appear for each language pair.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("\(ref.displayName) → \(othersCount) language\(othersCount == 1 ? "" : "s")") {
                    let others = langs.filter { $0 != ref }
                    let pairs = others.map { (source: ref, target: $0) }
                    Task {
                        await translationViewModel.startBulkDownload(pairs: pairs)
                    }
                }
                .disabled(langs.count < 2)

                Button("All \(langs.count) language combinations") {
                    var pairs: [(source: SupportedLanguage, target: SupportedLanguage)] = []
                    for source in langs {
                        for target in langs where source != target {
                            pairs.append((source: source, target: target))
                        }
                    }
                    Task {
                        await translationViewModel.startBulkDownload(pairs: pairs)
                    }
                }
                .disabled(langs.count < 2)
            }
            .font(.callout)
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("Session") {
                Toggle("Remember open files and directories", isOn: $settingsState.rememberOpenItems)
                Text("Restore previously open sidebar items and editor tabs when the app launches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Default Source Language") {
                Picker("When auto-detection fails, use:", selection: $settingsState.defaultSourceLanguage) {
                    Text("None (require manual selection)")
                        .tag(SupportedLanguage?.none)
                    Divider()
                    ForEach(settingsState.activeLanguages) { lang in
                        Text(lang.displayName)
                            .tag(Optional(lang))
                    }
                }
            }

            Section("Default Translation Language") {
                Picker("Auto-open translation panel for:", selection: $settingsState.defaultTargetLanguage) {
                    Text("None (don't auto-translate)")
                        .tag(SupportedLanguage?.none)
                    Divider()
                    ForEach(settingsState.activeLanguages) { lang in
                        Text(lang.displayName)
                            .tag(Optional(lang))
                    }
                }
                Text("When a file is opened, automatically add a translation panel for this language (unless it matches the source).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Save Naming Pattern") {
                TextField("Pattern", text: $settingsState.translationSavePattern)
                    .textFieldStyle(.roundedBorder)
                Text("Available tokens: {name}, {lang}, {ext}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Example: readme_{lang}.{ext} → readme_fr.md")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
