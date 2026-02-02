import Foundation

final class FileWatcherService: @unchecked Sendable {
    private var watchers: [URL: DispatchSourceFileSystemObject] = [:]
    private let queue = DispatchQueue(label: "com.transloaded.filewatcher", qos: .utility)

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

    func stopAll() {
        for (_, source) in watchers {
            source.cancel()
        }
        watchers.removeAll()
    }

    deinit {
        stopAll()
    }
}
