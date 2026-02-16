import SwiftUI
import Translation
import UniformTypeIdentifiers
import PhotosUI

struct ContentView: View {
    @Bindable var sidebarViewModel: SidebarViewModel
    @Bindable var appState: AppState
    @Bindable var translationViewModel: TranslationViewModel
    @Bindable var settingsState: SettingsState

    private let cameraImportService = CameraImportService()
    @State private var showCameraMenu = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var pendingCameraImage: NSImage?
    @State private var pendingCameraFolder: URL?
    @State private var pendingLibraryImages: [NSImage] = []
    @State private var showingQualityPicker = false

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
                onPDFReceived: { data in handleCameraPDF(data) },
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
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 5) {
                    Image("AppLogo")
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 28)
                    Text("Transloaded  ")
                        .fontWeight(.semibold)
                }
            }

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
                .disabled(sidebarViewModel.defaultFolderItem == nil)

                Button(action: { showPhotoPicker = true }) {
                    Label("Import Images", systemImage: "photo.on.rectangle")
                }
                .help("Import images from disk")
                .disabled(sidebarViewModel.defaultFolderItem == nil)
                .photosPicker(
                    isPresented: $showPhotoPicker,
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 20,
                    matching: .images
                )
                .onChange(of: selectedPhotoItems) { _, items in
                    Task {
                        await loadSelectedPhotos(items)
                    }
                }
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
        .sheet(isPresented: $showingQualityPicker) {
            ImageQualityPickerView { quality in
                savePendingImages(quality: quality)
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
        .alert(
            "Import to '\(sidebarViewModel.pendingImportFolderURL?.lastPathComponent ?? "folder")'?",
            isPresented: $sidebarViewModel.showImportToFolderAlert
        ) {
            Button("Yes") { sidebarViewModel.confirmImport(toFolder: true) }
            Button("No") { sidebarViewModel.confirmImport(toFolder: false) }
            Button("Cancel", role: .cancel) {
                sidebarViewModel.pendingImportURLs = []
                sidebarViewModel.showImportToFolderAlert = false
            }
        } message: {
            Text("Copy the selected file(s) into this folder?")
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
        .background {
            // Isolated view so .id() only recreates this, not the whole ContentView.
            // Changing translationTaskID forces SwiftUI to re-mount the modifier,
            // which is needed because .translationTask won't re-trigger after dismissal.
            Color.clear
                .translationTask(translationViewModel.translationConfig) { session in
                    do {
                        try await session.prepareTranslation()
                        await translationViewModel.verifyAndCompleteDownload()
                    } catch {
                        translationViewModel.onTranslationDownloadFailed(error)
                    }
                }
                .id(translationViewModel.translationTaskID)
        }
    }

    private var cameraTargetFolder: URL? {
        sidebarViewModel.selectedFolderURL ?? sidebarViewModel.defaultFolderItem?.url
    }

    private func refreshAfterCameraImport(targetFolder: URL) {
        if let rootURL = sidebarViewModel.roots.first(where: { targetFolder.path.hasPrefix($0.url.path) })?.url {
            sidebarViewModel.refreshRoot(at: rootURL)
        } else {
            sidebarViewModel.refreshDefaultFolder()
        }
    }

    private func handleCameraImage(_ image: NSImage) {
        guard let targetFolder = cameraTargetFolder else {
            appState.errorMessage = "No import folder available"
            appState.showError = true
            return
        }

        pendingCameraImage = image
        pendingCameraFolder = targetFolder
        showingQualityPicker = true
    }

    private func savePendingImages(quality: ImageQualityOption) {
        if let image = pendingCameraImage, let targetFolder = pendingCameraFolder {
            pendingCameraImage = nil
            pendingCameraFolder = nil
            do {
                let savedURL = try cameraImportService.saveImage(image, to: targetFolder, quality: quality)
                refreshAfterCameraImport(targetFolder: targetFolder)
                appState.openFile(url: savedURL)
            } catch {
                appState.errorMessage = "Camera import failed: \(error.localizedDescription)"
                appState.showError = true
            }
        } else if !pendingLibraryImages.isEmpty, let targetFolder = pendingCameraFolder {
            let images = pendingLibraryImages
            pendingLibraryImages = []
            pendingCameraFolder = nil
            var lastURL: URL?
            for image in images {
                lastURL = try? cameraImportService.saveImage(image, to: targetFolder, quality: quality)
            }
            refreshAfterCameraImport(targetFolder: targetFolder)
            if let url = lastURL { appState.openFile(url: url) }
        }
    }

    private func handleLibraryImages(_ images: [NSImage]) {
        guard !images.isEmpty else { return }
        guard let targetFolder = cameraTargetFolder else {
            appState.errorMessage = "No import folder available"
            appState.showError = true
            return
        }
        pendingLibraryImages = images
        pendingCameraFolder = targetFolder
        showingQualityPicker = true
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        var loadedImages: [NSImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = NSImage(data: data) {
                loadedImages.append(image)
            }
        }
        selectedPhotoItems = []
        if !loadedImages.isEmpty {
            handleLibraryImages(loadedImages)
        }
    }

    private func handleCameraPDF(_ data: Data) {
        guard let targetFolder = cameraTargetFolder else {
            appState.errorMessage = "No import folder available"
            appState.showError = true
            return
        }

        do {
            let savedURL = try cameraImportService.savePDF(data, to: targetFolder)
            refreshAfterCameraImport(targetFolder: targetFolder)
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
