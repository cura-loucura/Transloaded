import SwiftUI

struct SettingsView: View {
    @Bindable var settingsState: SettingsState

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
        .frame(width: 450, height: 350)
    }

    // MARK: - Languages Tab

    private var languagesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Languages")
                .font(.headline)

            Text("Toggle which languages appear in the source and target language menus. At least one must remain active.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach(settingsState.allLanguages) { lang in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { settingsState.isLanguageActive(lang) },
                            set: { _ in settingsState.toggleLanguage(lang) }
                        )) {
                            Text(lang.displayName)
                        }
                        .toggleStyle(.switch)

                        Spacer()

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

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
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
