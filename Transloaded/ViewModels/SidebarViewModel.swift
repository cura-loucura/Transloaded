import Foundation
import AppKit

@Observable
@MainActor
class SidebarViewModel {
    var roots: [FileItem] = []

    private let fileSystemService = FileSystemService()

    var onFileDoubleClick: ((URL) -> Void)?
    var recentItemsManager: RecentItemsManager?
    var settingsState: SettingsState?

    var selectedFolderURL: URL?
    var defaultFolderItem: FileItem?

    // Import-to-folder dialog state
    var pendingImportURLs: [URL] = []
    var pendingImportFolderURL: URL?
    var showImportToFolderAlert = false

    private var defaultFolderWatcher = FileWatcherService()
    private var defaultFolderRefreshTask: Task<Void, Never>?

    func addDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a directory to open"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard !roots.contains(where: { $0.url == url }) else { return }

        let item = fileSystemService.loadDirectory(at: url)
        roots.append(item)
        recentItemsManager?.addRecentFolder(url)
    }

    func addFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.message = "Choose files to open"

        guard panel.runModal() == .OK else { return }

        let urls = panel.urls.filter { url in !roots.contains(where: { $0.url == url }) }

        if let targetFolder = selectedFolderURL {
            pendingImportURLs = urls
            pendingImportFolderURL = targetFolder
            showImportToFolderAlert = true
        } else {
            for url in urls { addURLToRoots(url) }
        }
    }

    func confirmImport(toFolder: Bool) {
        defer {
            pendingImportURLs = []
            pendingImportFolderURL = nil
            showImportToFolderAlert = false
        }
        guard toFolder, let targetFolder = pendingImportFolderURL else {
            for url in pendingImportURLs { addURLToRoots(url) }
            return
        }
        for url in pendingImportURLs {
            let dest = targetFolder.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: dest)
        }
        if let rootURL = roots.first(where: { targetFolder.path.hasPrefix($0.url.path) })?.url {
            refreshRoot(at: rootURL)
        } else {
            refreshDefaultFolder()
        }
    }

    func removeRoot(_ item: FileItem) {
        roots.removeAll { $0.id == item.id }
    }

    func handleDoubleClick(on item: FileItem) {
        guard !item.isDirectory, item.isTextFile || item.isImageFile || item.isPDFFile else { return }
        onFileDoubleClick?(item.url)
    }

    func refreshRoot(at url: URL) {
        guard roots.contains(where: { $0.url == url }) else { return }
        Task {
            let refreshed = await Task.detached(priority: .utility) {
                FileSystemService().loadDirectory(at: url)
            }.value
            guard let currentIndex = self.roots.firstIndex(where: { $0.url == url }) else { return }
            self.roots[currentIndex] = refreshed
        }
    }

    func addURLs(_ urls: [URL]) {
        for url in urls { addURLToRoots(url) }
    }

    // MARK: - Default Folder

    func loadDefaultFolder() {
        guard let path = settingsState?.defaultFolderPath else { return }
        let url = URL(fileURLWithPath: path).standardized
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        Task {
            let item = await Task.detached(priority: .utility) {
                FileSystemService().loadDirectory(at: url)
            }.value
            self.defaultFolderItem = item
        }
        defaultFolderWatcher.watch(url: url) { [weak self] _ in
            DispatchQueue.main.async { self?.scheduleDefaultFolderRefresh() }
        }
    }

    func refreshDefaultFolder() {
        guard let path = settingsState?.defaultFolderPath else { return }
        let url = URL(fileURLWithPath: path).standardized
        Task {
            let item = await Task.detached(priority: .utility) {
                FileSystemService().loadDirectory(at: url)
            }.value
            self.defaultFolderItem = item
        }
    }

    private func scheduleDefaultFolderRefresh() {
        defaultFolderRefreshTask?.cancel()
        defaultFolderRefreshTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            self?.refreshDefaultFolder()
        }
    }

    // MARK: - New Folder

    func nextNewFolderName(in parentURL: URL) -> String {
        let existing = (try? FileManager.default.contentsOfDirectory(atPath: parentURL.path)) ?? []
        if !existing.contains("New Folder") { return "New Folder" }
        var i = 2
        while existing.contains("New Folder \(i)") { i += 1 }
        return "New Folder \(i)"
    }

    func folderNameExists(_ name: String, in parentURL: URL) -> Bool {
        let candidate = parentURL.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: candidate.path)
    }

    func createSubfolder(named name: String, in parentURL: URL) throws {
        let newURL = parentURL.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: false)
        if let rootURL = roots.first(where: { parentURL.path.hasPrefix($0.url.path) })?.url {
            refreshRoot(at: rootURL)
        } else {
            refreshDefaultFolder()
        }
    }

    // MARK: - Private Helpers

    private func addURLToRoots(_ url: URL) {
        guard !roots.contains(where: { $0.url == url }) else { return }
        let item = fileSystemService.loadDirectory(at: url)
        roots.append(item)
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDir {
            recentItemsManager?.addRecentFolder(url)
        } else {
            recentItemsManager?.addRecentFile(url)
        }
    }
}
