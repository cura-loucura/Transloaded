import SwiftUI
import Translation
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var sidebarViewModel: SidebarViewModel
    @Bindable var appState: AppState
    @Bindable var translationViewModel: TranslationViewModel
    @Bindable var settingsState: SettingsState

    private var selectedFileURL: Binding<URL?> {
        Binding<URL?>(
            get: { appState.activeFile?.url },
            set: { newURL in
                guard let url = newURL else { return }
                // Only switch to already-open files; don't open new ones
                if let existing = appState.openFiles.first(where: { $0.url == url }) {
                    appState.setActiveFile(id: existing.id)
                }
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: sidebarViewModel,
                selectedFileURL: selectedFileURL,
                onOpenScrapbook: { appState.openScrapbook() }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
        } detail: {
            EditorAreaView(
                appState: appState,
                translationViewModel: translationViewModel,
                settingsState: settingsState
            )
        }
        .onAppear {
            sidebarViewModel.onFileDoubleClick = { url in
                appState.openFile(url: url)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { sidebarViewModel.addFile() }) {
                    Label("Open File", systemImage: "doc.badge.plus")
                }
                .help("Open File")

                Button(action: { sidebarViewModel.addDirectory() }) {
                    Label("Open Directory", systemImage: "folder.badge.plus")
                }
                .help("Open Directory")
            }

            ToolbarItemGroup(placement: .secondaryAction) {
                Button(action: { appState.reloadActiveFile() }) {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .help("Reload File")
                .disabled(appState.activeFileID == nil)

                Button(action: { appState.saveActiveTranslation() }) {
                    Label("Save Translation", systemImage: "square.and.arrow.down")
                }
                .help("Save Translation")
                .disabled(appState.activeTranslationPanelID == nil)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers: providers)
        }
        .alert("Error", isPresented: $appState.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.errorMessage)
        }
        .alert("Large File", isPresented: $appState.showLargeFileAlert) {
            Button("Open Anyway") {
                appState.confirmOpenLargeFile()
            }
            Button("Cancel", role: .cancel) {
                appState.cancelOpenLargeFile()
            }
        } message: {
            if let url = appState.pendingLargeFileURL {
                Text("\(url.lastPathComponent) is larger than 1 MB. Opening large files may affect performance.")
            }
        }
        .alert("Close Scrapbook", isPresented: $appState.showCloseScrapbookAlert) {
            Button("Don't Save", role: .destructive) {
                appState.confirmCloseScrapbook()
            }
            Button("Cancel", role: .cancel) {
                appState.cancelCloseScrapbook()
            }
        } message: {
            Text("The scrapbook has content. Close without saving?")
        }
        .translationTask(translationViewModel.translationConfig) { session in
            do {
                try await session.prepareTranslation()
                translationViewModel.onTranslationDownloadComplete()
            } catch {
                translationViewModel.onTranslationDownloadFailed(error)
            }
        }
    }

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in
                        sidebarViewModel.addURLs([url])
                        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                        if !isDir, FileSystemService().isTextFile(at: url) {
                            appState.openFile(url: url)
                        }
                    }
                }
            }
        }
        return handled
    }
}
