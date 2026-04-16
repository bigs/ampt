//
//  ShaderFileWatcher.swift
//  ampt
//

import Foundation

@Observable
final class ShaderFileWatcher {
    private(set) var isWatching: Bool = false
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?

    func watch(fileAt path: String, onChange: @escaping (String) -> Void) {
        stopWatching()

        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: .main
        )

        source.setEventHandler {
            guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return }
            onChange(contents)
        }

        source.setCancelHandler { [fd = fileDescriptor] in
            close(fd)
        }

        source.resume()
        dispatchSource = source
        isWatching = true
    }

    func stopWatching() {
        dispatchSource?.cancel()
        dispatchSource = nil
        fileDescriptor = -1
        isWatching = false
    }

    deinit {
        stopWatching()
    }
}
