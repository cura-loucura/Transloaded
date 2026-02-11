import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel
    @Binding var selectedFileURL: URL?
    var onOpenScrapbook: (() -> Void)?

    @Environment(\.openSettings) private var openSettings
    @State private var showNewFolderSheet = false
    @State private var newFolderName = ""

    private var targetFolderForNew: URL? {
        viewModel.selectedFolderURL ?? viewModel.defaultFolderItem?.url
    }

    var body: some View {
        VStack(spacing: 0) {
            scrapbookButton
            Divider()
            newFolderToolbar
            fileTree
            Divider()
            settingsButton
        }
        .frame(minWidth: 200)
        .sheet(isPresented: $showNewFolderSheet) {
            newFolderSheet
        }
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

    private var settingsButton: some View {
        HStack {
            Spacer()
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var newFolderToolbar: some View {
        HStack {
            Spacer()
            Button {
                showNewFolderSheet = true
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .disabled(targetFolderForNew == nil)
            .help("New Folder in selected folder")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var fileTree: some View {
        List(selection: $selectedFileURL) {
            // Default folder — pinned at top
            if let defaultItem = viewModel.defaultFolderItem {
                SidebarFileItemView(item: defaultItem, isRoot: true, viewModel: viewModel)
            } else {
                Label("Loading default folder…", systemImage: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // User-added roots
            ForEach(viewModel.roots) { root in
                SidebarFileItemView(item: root, isRoot: true, viewModel: viewModel)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var newFolderSheet: some View {
        if let targetURL = targetFolderForNew {
            VStack(spacing: 16) {
                Text("New Folder in '\(targetURL.lastPathComponent)'")
                    .font(.headline)

                TextField("Folder name", text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        newFolderName = viewModel.nextNewFolderName(in: targetURL)
                    }

                if !newFolderName.isEmpty && viewModel.folderNameExists(newFolderName, in: targetURL) {
                    Text("A folder with this name already exists.")
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                HStack {
                    Button("Cancel") { showNewFolderSheet = false }
                        .buttonStyle(.bordered)

                    Button("Create") {
                        try? viewModel.createSubfolder(named: newFolderName, in: targetURL)
                        showNewFolderSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newFolderName.isEmpty || viewModel.folderNameExists(newFolderName, in: targetURL))
                }
            }
            .padding(24)
            .frame(width: 320)
        }
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
                            .fill(
                                viewModel.selectedFolderURL == item.url
                                    ? Color.accentColor.opacity(0.15)
                                    : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
                            )
                    )
                    .onHover { hovering in
                        isHovered = hovering
                    }
                    .onTapGesture {
                        viewModel.selectedFolderURL = item.url
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
                .foregroundStyle(item.isTextFile || item.isImageFile || item.isPDFFile ? .primary : .tertiary)
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
        if item.isPDFFile { return "doc.richtext" }
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
