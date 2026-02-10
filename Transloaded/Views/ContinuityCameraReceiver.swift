import SwiftUI
import AppKit

struct ContinuityCameraReceiver: NSViewRepresentable {
    var onImageReceived: @MainActor (NSImage) -> Void
    @Binding var showMenu: Bool

    func makeNSView(context: Context) -> CameraReceiverView {
        let view = CameraReceiverView()
        view.onImageReceived = onImageReceived

        // Register that this app can receive images from services (Continuity Camera)
        NSApp.registerServicesMenuSendTypes([], returnTypes: [.tiff, .png])

        // Become first responder so the system adds "Import from iPhone" to the Edit menu
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: CameraReceiverView, context: Context) {
        nsView.onImageReceived = onImageReceived
        if showMenu {
            DispatchQueue.main.async {
                nsView.showImportMenu()
                showMenu = false
            }
        }
    }
}

class CameraReceiverView: NSView, @preconcurrency NSServicesMenuRequestor {
    nonisolated(unsafe) var onImageReceived: (@MainActor (NSImage) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?) -> Any? {
        if let returnType,
           NSImage.imageTypes.contains(returnType.rawValue) {
            return self
        }
        return super.validRequestor(forSendType: sendType, returnType: returnType)
    }

    func readSelection(from pboard: NSPasteboard) -> Bool {
        guard let image = NSImage(pasteboard: pboard) else { return false }
        let callback = onImageReceived
        Task { @MainActor in
            callback?(image)
        }
        return true
    }

    func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        return false
    }

    /// Finds the system-populated "Import from iPhone" submenu in the Edit menu and shows it
    /// as a popup at the current mouse location.
    func showImportMenu() {
        guard let window = self.window else { return }
        window.makeFirstResponder(self)

        // Give the system a moment to update the Edit menu with Import from iPhone items
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Search all top-level menus for the Import from iPhone submenu
            guard let mainMenu = NSApp.mainMenu else { return }
            for topItem in mainMenu.items {
                guard let submenu = topItem.submenu else { continue }
                submenu.update()

                for item in submenu.items where item.hasSubmenu {
                    let title = item.title.lowercased()
                    if title.contains("import") && (title.contains("iphone") || title.contains("ipad") || title.contains("device")) {
                        // Show the submenu at the mouse position
                        let mouseLocation = NSEvent.mouseLocation
                        item.submenu?.popUp(positioning: nil, at: mouseLocation, in: nil)
                        return
                    }
                }
            }

            // Fallback: try showing a context menu on this view (system may populate it)
            self.showContextMenuFallback()
        }
    }

    private func showContextMenuFallback() {
        guard let window = self.window else { return }
        let mouseScreenPoint = NSEvent.mouseLocation
        let windowPoint = window.convertPoint(fromScreen: mouseScreenPoint)

        guard let event = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: windowPoint,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        ) else { return }

        let menu = self.menu(for: event) ?? NSMenu()
        if menu.items.isEmpty {
            // No items available — iPhone may not be nearby
            let placeholder = NSMenuItem(title: "No iPhone detected nearby", action: nil, keyEquivalent: "")
            placeholder.isEnabled = false
            menu.addItem(placeholder)
            let hint = NSMenuItem(title: "Ensure Bluetooth & Wi-Fi are on and same Apple ID", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}
