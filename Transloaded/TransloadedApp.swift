import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct TransloadedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var sidebarViewModel = SidebarViewModel()
    @State private var appState = AppState()
    @State private var translationViewModel = TranslationViewModel()
    @State private var settingsState = SettingsState()
    @State private var recentItemsManager = RecentItemsManager()

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
                appState.translationViewModel = translationViewModel
                appState.settingsState = settingsState
                appState.recentItemsManager = recentItemsManager
                sidebarViewModel.recentItemsManager = recentItemsManager
                translationViewModel.onAllDownloadsComplete = { [weak appState] in
                    appState?.retryPendingDownloads()
                }
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

                Menu("Open Recent") {
                    if recentItemsManager.recentFiles.isEmpty && recentItemsManager.recentFolders.isEmpty {
                        Text("No Recent Items")
                            .foregroundStyle(.secondary)
                    } else {
                        Section("Files") {
                            ForEach(recentItemsManager.recentFiles) { item in
                                Button(item.name) {
                                    openRecentFile(item)
                                }
                            }
                        }

                        if !recentItemsManager.recentFolders.isEmpty {
                            Divider()
                            Section("Folders") {
                                ForEach(recentItemsManager.recentFolders) { item in
                                    Button(item.name) {
                                        openRecentFolder(item)
                                    }
                                }
                            }
                        }

                        Divider()

                        Button("Clear List") {
                            recentItemsManager.clearAll()
                        }
                    }
                }
            }

            CommandGroup(after: .saveItem) {
                Button("Save Translation...") {
                    appState.saveActiveTranslation()
                }
                .keyboardShortcut("s", modifiers: .command)
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

    private func openRecentFile(_ item: RecentItemsManager.RecentItem) {
        guard let url = recentItemsManager.resolveAndAccess(item) else { return }
        sidebarViewModel.addURLs([url])
        appState.openFile(url: url)
    }

    private func openRecentFolder(_ item: RecentItemsManager.RecentItem) {
        guard let url = recentItemsManager.resolveAndAccess(item) else { return }
        sidebarViewModel.addURLs([url])
    }
}
