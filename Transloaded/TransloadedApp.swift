import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?
    var sidebarViewModel: SidebarViewModel?
    var settingsState: SettingsState?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveSession()
    }

    @MainActor
    private func saveSession() {
        guard let settingsState, settingsState.rememberOpenItems else {
            settingsState?.clearSessionData()
            return
        }

        // Save sidebar roots as security-scoped bookmarks
        let sidebarBookmarks: [Data] = (sidebarViewModel?.roots ?? []).compactMap { item in
            try? item.url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
        UserDefaults.standard.set(sidebarBookmarks, forKey: "sessionSidebarBookmarks")

        // Save open file URLs (excluding scrapbook) as security-scoped bookmarks
        let openFileBookmarks: [Data] = (appState?.openFiles ?? [])
            .filter { !$0.isScrapbook }
            .compactMap { file in
                try? file.url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            }
        UserDefaults.standard.set(openFileBookmarks, forKey: "sessionOpenFileBookmarks")

        // Save active file bookmark
        if let activeFile = appState?.activeFile, !activeFile.isScrapbook {
            if let data = try? activeFile.url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(data, forKey: "sessionActiveFileBookmark")
            }
        } else {
            UserDefaults.standard.removeObject(forKey: "sessionActiveFileBookmark")
        }
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
    @State private var showTutorial = false

    var body: some Scene {
        WindowGroup {
            ContentView(
                sidebarViewModel: sidebarViewModel,
                appState: appState,
                translationViewModel: translationViewModel,
                settingsState: settingsState
            )
            .sheet(isPresented: $showTutorial) {
                TutorialView(isPresented: $showTutorial) {
                    settingsState.hasSeenTutorial = true
                }
            }
            .onAppear {
                if !settingsState.hasSeenTutorial {
                    showTutorial = true
                }
                appState.translationService = translationViewModel.translationService
                appState.translationViewModel = translationViewModel
                appState.settingsState = settingsState
                appState.recentItemsManager = recentItemsManager
                sidebarViewModel.recentItemsManager = recentItemsManager
                sidebarViewModel.settingsState = settingsState
                sidebarViewModel.loadDefaultFolder()
                translationViewModel.onAllDownloadsComplete = { [weak appState] in
                    appState?.retryPendingDownloads()
                }

                appDelegate.appState = appState
                appDelegate.sidebarViewModel = sidebarViewModel
                appDelegate.settingsState = settingsState
                restoreSession()
            }
        }
        .defaultSize(width: 1200, height: 800)
        .windowToolbarStyle(.unified(showsTitle: false))
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

            CommandGroup(after: .toolbar) {
                Divider()

                Button("Increase Font Size") {
                    if settingsState.editorFontSize < 36 {
                        settingsState.editorFontSize += 1
                    }
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Decrease Font Size") {
                    if settingsState.editorFontSize > 9 {
                        settingsState.editorFontSize -= 1
                    }
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Font Size") {
                    settingsState.editorFontSize = 13
                }
                .keyboardShortcut("0", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button("Transloaded Help") {
                    showTutorial = true
                }
            }
        }

        Settings {
            SettingsView(
                settingsState: settingsState,
                translationViewModel: translationViewModel
            )
        }
    }

    private func restoreSession() {
        guard settingsState.rememberOpenItems else { return }

        // Restore sidebar roots
        var validSidebarBookmarks: [Data] = []
        if let dataArray = UserDefaults.standard.array(forKey: "sessionSidebarBookmarks") as? [Data] {
            for data in dataArray {
                var isStale = false
                guard let url = try? URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ) else { continue }
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                _ = url.startAccessingSecurityScopedResource()
                sidebarViewModel.addURLs([url])
                if isStale, let freshData = try? url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    validSidebarBookmarks.append(freshData)
                } else {
                    validSidebarBookmarks.append(data)
                }
            }
            UserDefaults.standard.set(validSidebarBookmarks, forKey: "sessionSidebarBookmarks")
        }

        // Restore open files
        var validFileBookmarks: [Data] = []
        if let dataArray = UserDefaults.standard.array(forKey: "sessionOpenFileBookmarks") as? [Data] {
            for data in dataArray {
                var isStale = false
                guard let url = try? URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ) else { continue }
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                _ = url.startAccessingSecurityScopedResource()
                appState.restoreFile(url: url)
                if isStale, let freshData = try? url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    validFileBookmarks.append(freshData)
                } else {
                    validFileBookmarks.append(data)
                }
            }
            UserDefaults.standard.set(validFileBookmarks, forKey: "sessionOpenFileBookmarks")
        }

        // Restore active file
        if let data = UserDefaults.standard.data(forKey: "sessionActiveFileBookmark") {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                _ = url.startAccessingSecurityScopedResource()
                if let match = appState.openFiles.first(where: { $0.url == url }) {
                    appState.activeFileID = match.id
                }
            }
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
