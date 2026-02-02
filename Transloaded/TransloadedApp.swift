import SwiftUI

@main
struct TransloadedApp: App {
    @State private var sidebarViewModel = SidebarViewModel()
    @State private var appState = AppState()
    @State private var translationViewModel = TranslationViewModel()
    @State private var settingsState = SettingsState()

    var body: some Scene {
        WindowGroup {
            ContentView(
                sidebarViewModel: sidebarViewModel,
                appState: appState,
                translationViewModel: translationViewModel,
                settingsState: settingsState
            )
            .onAppear {
                appState.translationService = translationViewModel.translationService
                appState.settingsState = settingsState
            }
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
                Divider()
                Button("Open File...") {
                    sidebarViewModel.addFile()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open Directory...") {
                    sidebarViewModel.addDirectory()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandGroup(after: .saveItem) {
                Button("Save Translation") {
                    appState.saveActiveTranslation()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.activeTranslationPanelID == nil)

                Button("Save Translation To...") {
                    appState.saveActiveTranslationAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appState.activeTranslationPanelID == nil)

                Divider()

                Button("Close Tab") {
                    appState.closeActiveFile()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(appState.activeFileID == nil)

                Button("Reload File") {
                    appState.reloadActiveFile()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(appState.activeFileID == nil)
            }
        }

        Settings {
            SettingsView(settingsState: settingsState)
        }
    }
}
