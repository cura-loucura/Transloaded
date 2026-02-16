import AppKit
import UniformTypeIdentifiers

func presentPhotoLibraryPicker(
    onImagesPicked: @escaping @MainActor ([NSImage]) -> Void,
    onDismiss: @escaping @MainActor () -> Void
) {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowedContentTypes = [.image]
    panel.title = "Select Images"
    panel.prompt = "Add"
    panel.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first

    guard let window = NSApp.keyWindow else { return }
    panel.beginSheetModal(for: window) { response in
        Task { @MainActor in
            onDismiss()
            guard response == .OK else { return }
            let images = panel.urls.compactMap { NSImage(contentsOf: $0) }
            onImagesPicked(images)
        }
    }
}
