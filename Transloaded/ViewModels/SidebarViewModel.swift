import Foundation
import AppKit

@Observable
@MainActor
class SidebarViewModel {
    var roots: [FileItem] = []

    private let fileSystemService = FileSystemService()

    var onFileDoubleClick: ((URL) -> Void)?
    var recentItemsManager: RecentItemsManager?

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

        for url in panel.urls {
            guard !roots.contains(where: { $0.url == url }) else { continue }
            let item = fileSystemService.loadDirectory(at: url)
            roots.append(item)
        }
    }

    func removeRoot(_ item: FileItem) {
        roots.removeAll { $0.id == item.id }
    }

    func handleDoubleClick(on item: FileItem) {
        guard !item.isDirectory, item.isTextFile || item.isImageFile || item.isPDFFile else { return }
        onFileDoubleClick?(item.url)
    }

    var importTargetFolder: URL? {
        roots.first(where: { $0.isDirectory })?.url
    }

    func refreshRoot(at url: URL) {
        guard let index = roots.firstIndex(where: { $0.url == url }) else { return }
        let refreshed = fileSystemService.loadDirectory(at: url)
        roots[index] = refreshed
    }

    func addURLs(_ urls: [URL]) {
        for url in urls {
            guard !roots.contains(where: { $0.url == url }) else { continue }
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
}
