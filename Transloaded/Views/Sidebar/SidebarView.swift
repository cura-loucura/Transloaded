import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel

    var body: some View {
        Group {
            if viewModel.roots.isEmpty {
                emptyState
            } else {
                fileTree
            }
        }
        .frame(minWidth: 200)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No files or folders open")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Use File > Open to get started")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var fileTree: some View {
        List {
            ForEach(viewModel.roots) { root in
                SidebarFileItemView(item: root, isRoot: true, viewModel: viewModel)
            }
        }
        .listStyle(.sidebar)
    }
}

struct SidebarFileItemView: View {
    let item: FileItem
    let isRoot: Bool
    let viewModel: SidebarViewModel

    var body: some View {
        if item.isDirectory {
            DisclosureGroup {
                if let children = item.children {
                    ForEach(children) { child in
                        SidebarFileItemView(item: child, isRoot: false, viewModel: viewModel)
                    }
                }
            } label: {
                Label(item.name, systemImage: "folder.fill")
                    .foregroundStyle(isRoot ? .primary : .secondary)
            }
            .contextMenu {
                if isRoot {
                    Button("Remove from Sidebar") {
                        viewModel.removeRoot(item)
                    }
                }
            }
        } else {
            Label(item.name, systemImage: fileIcon)
                .foregroundStyle(item.isTextFile ? .primary : .tertiary)
                .onTapGesture(count: 2) {
                    viewModel.handleDoubleClick(on: item)
                }
                .contextMenu {
                    if isRoot {
                        Button("Remove from Sidebar") {
                            viewModel.removeRoot(item)
                        }
                    }
                }
        }
    }

    private var fileIcon: String {
        guard item.isTextFile else { return "doc.fill" }

        let ext = item.url.pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "json": return "curlybraces"
        case "xml", "html": return "chevron.left.forwardslash.chevron.right"
        case "md", "markdown": return "text.document"
        case "py", "js", "ts", "rb", "go", "rs", "java", "c", "cpp", "h":
            return "terminal"
        default: return "doc.text"
        }
    }
}
