import Foundation
import CoreServices

// MARK: - FSEvents C-bridge helpers

private final class FSEventBox {
    let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
}

private func retainFSEventBox(_ ptr: UnsafeRawPointer?) -> UnsafeRawPointer? {
    guard let ptr else { return nil }
    _ = Unmanaged<FSEventBox>.fromOpaque(ptr).retain()
    return ptr
}

private func releaseFSEventBox(_ ptr: UnsafeRawPointer?) {
    guard let ptr else { return }
    Unmanaged<FSEventBox>.fromOpaque(ptr).release()
}

private func fsEventStreamCallback(
    _ streamRef: ConstFSEventStreamRef,
    _ info: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info else { return }
    Unmanaged<FSEventBox>.fromOpaque(info).takeUnretainedValue().handler()
}

// MARK: - FileWatcherService

final class FileWatcherService: @unchecked Sendable {
    /// Single-file / flat-directory watchers (used for open files).
    private var watchers: [URL: DispatchSourceFileSystemObject] = [:]
    /// Recursive directory watchers using FSEvents.
    private var directoryStreams: [URL: FSEventStreamRef] = [:]

    private let queue = DispatchQueue(label: "com.transloaded.filewatcher", qos: .utility)

    // MARK: - Flat file watching (DispatchSource)

    func watch(url: URL, onChange: @escaping (URL) -> Void) {
        stopWatching(url: url)

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard self != nil else { return }
            onChange(url)
        }

        source.setCancelHandler {
            close(fd)
        }

        watchers[url] = source
        source.resume()
    }

    func stopWatching(url: URL) {
        if let existing = watchers.removeValue(forKey: url) {
            existing.cancel()
        }
    }

    // MARK: - Recursive directory watching (FSEvents)

    /// Watches `url` and all its descendants for any filesystem change.
    func watchDirectory(_ url: URL, onChange: @escaping () -> Void) {
        stopWatchingDirectory(url)

        let box = FSEventBox(onChange)
        let unmanaged = Unmanaged.passRetained(box)

        var context = FSEventStreamContext(
            version: 0,
            info: unmanaged.toOpaque(),
            retain: retainFSEventBox,
            release: releaseFSEventBox,
            copyDescription: nil
        )

        let paths = [url.path] as CFArray
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            fsEventStreamCallback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)
        ) else {
            unmanaged.release()
            return
        }

        // FSEventStreamCreate called retain(info) via our callback; release our own hold.
        unmanaged.release()

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        directoryStreams[url] = stream
    }

    private func stopWatchingDirectory(_ url: URL) {
        if let stream = directoryStreams.removeValue(forKey: url) {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream) // triggers releaseFSEventBox → box freed
        }
    }

    // MARK: - Stop all

    func stopAll() {
        for (_, source) in watchers {
            source.cancel()
        }
        watchers.removeAll()
        for url in Array(directoryStreams.keys) {
            stopWatchingDirectory(url)
        }
    }

    deinit {
        stopAll()
    }
}
