import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel
    @Binding var selectedFileURL: URL?
    var onOpenScrapbook: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            scrapbookButton
            Divider()

            Group {
                if viewModel.roots.isEmpty {
                    emptyState
                } else {
                    fileTree
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(minWidth: 200)
    }

    private var scrapbookButton: some View {
        Button {
            onOpenScrapbook?()
        } label: {
            Label("Scrapbook", systemImage: "square.and.pencil")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(Color.primary.opacity(0.04))
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
        List(selection: $selectedFileURL) {
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

    @State private var isHovered = false

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
                    .padding(.vertical, 1)
                    .padding(.horizontal, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                    )
                    .onHover { hovering in
                        isHovered = hovering
                    }
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
                .foregroundStyle(item.isTextFile || item.isImageFile ? .primary : .tertiary)
                .tag(item.url)
                .onTapGesture(count: 2) {
                    viewModel.handleDoubleClick(on: item)
                }
                .padding(.vertical, 1)
                .padding(.horizontal, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                )
                .onHover { hovering in
                    isHovered = hovering
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
        if item.isImageFile { return "photo" }
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
