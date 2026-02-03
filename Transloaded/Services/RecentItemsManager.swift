import Foundation

@Observable
@MainActor
class RecentItemsManager {
    private static let recentFilesKey = "recentFileBookmarks"
    private static let recentFoldersKey = "recentFolderBookmarks"
    private static let maxItems = 10

    struct RecentItem: Identifiable {
        let id = UUID()
        let url: URL
        let name: String
    }

    private(set) var recentFiles: [RecentItem] = []
    private(set) var recentFolders: [RecentItem] = []

    init() {
        recentFiles = loadBookmarks(forKey: Self.recentFilesKey)
        recentFolders = loadBookmarks(forKey: Self.recentFoldersKey)
    }

    func addRecentFile(_ url: URL) {
        addRecent(url: url, to: &recentFiles, key: Self.recentFilesKey)
    }

    func addRecentFolder(_ url: URL) {
        addRecent(url: url, to: &recentFolders, key: Self.recentFoldersKey)
    }

    func clearAll() {
        recentFiles = []
        recentFolders = []
        UserDefaults.standard.removeObject(forKey: Self.recentFilesKey)
        UserDefaults.standard.removeObject(forKey: Self.recentFoldersKey)
    }

    func resolveAndAccess(_ item: RecentItem) -> URL? {
        // The URL was already resolved from bookmark data during load;
        // start accessing the security-scoped resource
        guard item.url.startAccessingSecurityScopedResource() else { return nil }
        return item.url
    }

    // MARK: - Private

    private func addRecent(url: URL, to list: inout [RecentItem], key: String) {
        // Remove existing entry for same URL
        list.removeAll { $0.url == url }
        // Insert at front
        list.insert(RecentItem(url: url, name: url.lastPathComponent), at: 0)
        // Trim to max
        if list.count > Self.maxItems {
            list = Array(list.prefix(Self.maxItems))
        }
        saveBookmarks(list, forKey: key)
    }

    private func saveBookmarks(_ items: [RecentItem], forKey key: String) {
        let bookmarks: [Data] = items.compactMap { item in
            try? item.url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
        UserDefaults.standard.set(bookmarks, forKey: key)
    }

    private func loadBookmarks(forKey key: String) -> [RecentItem] {
        guard let dataArray = UserDefaults.standard.array(forKey: key) as? [Data] else {
            return []
        }

        return dataArray.compactMap { data in
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                return nil
            }
            return RecentItem(url: url, name: url.lastPathComponent)
        }
    }
}
