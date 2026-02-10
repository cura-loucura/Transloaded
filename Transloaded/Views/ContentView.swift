import SwiftUI
import Translation
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var sidebarViewModel: SidebarViewModel
    @Bindable var appState: AppState
    @Bindable var translationViewModel: TranslationViewModel
    @Bindable var settingsState: SettingsState

    private let cameraImportService = CameraImportService()
    @State private var showCameraMenu = false

    private var selectedFileURL: Binding<URL?> {
        Binding<URL?>(
            get: { appState.activeFile?.url },
            set: { newURL in
                guard let url = newURL else { return }
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
        .background {
            ContinuityCameraReceiver(
                onImageReceived: { image in handleCameraImage(image) },
                showMenu: $showCameraMenu
            )
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
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

                Button(action: { showCameraMenu = true }) {
                    Label("Import from Camera", systemImage: "camera.fill")
                }
                .help("Import from iPhone Camera")
                .disabled(sidebarViewModel.importTargetFolder == nil)
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

                Menu {
                    let fontFamilies: [(name: String, label: String)] = [
                        ("", "System Monospaced"),
                        ("Menlo", "Menlo"),
                        ("SF Mono", "SF Mono"),
                        ("Monaco", "Monaco"),
                        ("Courier New", "Courier New"),
                        ("Andale Mono", "Andale Mono")
                    ]
                    ForEach(fontFamilies, id: \.name) { font in
                        Button {
                            settingsState.editorFontName = font.name
                        } label: {
                            HStack {
                                Text(font.label)
                                if settingsState.editorFontName == font.name {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Button {
                            if settingsState.editorFontSize > 9 {
                                settingsState.editorFontSize -= 1
                            }
                        } label: {
                            Label("Decrease Size", systemImage: "minus")
                        }

                        Button {
                            if settingsState.editorFontSize < 36 {
                                settingsState.editorFontSize += 1
                            }
                        } label: {
                            Label("Increase Size", systemImage: "plus")
                        }
                    }
                } label: {
                    Label("Font", systemImage: "textformat.size")
                }
                .help("Font Settings")
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

    private func handleCameraImage(_ image: NSImage) {
        guard let folder = sidebarViewModel.importTargetFolder else {
            appState.errorMessage = "Open a folder first to import camera images"
            appState.showError = true
            return
        }

        do {
            let savedURL = try cameraImportService.saveImage(image, to: folder)
            sidebarViewModel.refreshRoot(at: folder)
            appState.openFile(url: savedURL)
        } catch {
            appState.errorMessage = "Camera import failed: \(error.localizedDescription)"
            appState.showError = true
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
