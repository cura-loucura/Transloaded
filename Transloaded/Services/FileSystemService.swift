import Foundation
import UniformTypeIdentifiers

struct FileSystemService {
    private let fileManager = FileManager.default

    func loadDirectory(at url: URL) -> FileItem {
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .nameKey]
        let name = url.lastPathComponent
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

        guard isDir else {
            return FileItem(
                url: url,
                name: name,
                isDirectory: false,
                children: nil,
                isTextFile: isTextFile(at: url),
                isImageFile: isImageFile(at: url)
            )
        }

        let contents = (try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )) ?? []

        let children = contents
            .sorted { lhs, rhs in
                let lhsDir = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let rhsDir = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if lhsDir != rhsDir { return lhsDir }
                return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
            }
            .map { loadDirectory(at: $0) }

        return FileItem(
            url: url,
            name: name,
            isDirectory: true,
            children: children,
            isTextFile: false,
            isImageFile: false
        )
    }

    func readFileContent(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func isTextFile(at url: URL) -> Bool {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.conforms(to: .text)
                || type.conforms(to: .sourceCode)
                || type.conforms(to: .script)
                || type.conforms(to: .json)
                || type.conforms(to: .xml)
                || type.conforms(to: .yaml)
                || type.conforms(to: .propertyList)
        }

        let textExtensions: Set<String> = [
            "txt", "md", "markdown", "rst", "csv", "tsv", "log",
            "json", "xml", "yaml", "yml", "toml", "ini", "cfg", "conf",
            "swift", "py", "js", "ts", "jsx", "tsx", "html", "css", "scss",
            "java", "kt", "c", "h", "cpp", "hpp", "m", "mm", "rs", "go",
            "rb", "php", "sh", "bash", "zsh", "fish", "ps1",
            "sql", "graphql", "proto", "env", "gitignore", "dockerfile",
            "makefile", "cmake", "gradle", "plist", "strings", "storyboard"
        ]

        return textExtensions.contains(url.pathExtension.lowercased())
    }

    func isImageFile(at url: URL) -> Bool {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.conforms(to: .image)
        }

        let imageExtensions: Set<String> = [
            "png", "jpg", "jpeg", "tiff", "tif", "heic", "heif", "bmp"
        ]

        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}
