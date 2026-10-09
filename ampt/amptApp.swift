//
//  amptApp.swift
//  ampt
//
//  Created by Cole Brown on 1/16/26.
//

import SwiftUI
import SwiftData

@main
struct amptApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Track.self,
            Shader.self,
        ])

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]
            )
            Shader.seedDefaultIfNeeded(in: container.mainContext)
            return container
        } catch {
            // A corrupt store shouldn't make the app unlaunchable. Run on an
            // in-memory store so playback still works; the on-disk file is
            // left untouched for manual recovery.
            print("Could not open persistent store, falling back to in-memory: \(error)")
            do {
                let container = try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
                )
                Shader.seedDefaultIfNeeded(in: container.mainContext)
                return container
            } catch {
                fatalError("Could not create in-memory ModelContainer: \(error)")
            }
        }
    }()

    @State private var playerState: PlayerState
    @State private var audioAnalyzer: AudioAnalyzer
    @State private var compilationState = ShaderCompilationState()

    init() {
        let ps = PlayerState()
        _playerState = State(initialValue: ps)
        _audioAnalyzer = State(initialValue: AudioAnalyzer(audioPlayer: ps.audioPlayer))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(playerState: playerState, fileDropCoordinator: .shared)
                .onAppear { appDelegate.playerState = playerState }
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 300, height: 400)
        .windowResizability(.contentMinSize)

        WindowGroup(id: "visualizer") {
            VisualizerWindow(audioAnalyzer: audioAnalyzer, compilationState: compilationState)
                .navigationTitle("ampt Visualizer")
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 400)

        WindowGroup(id: "shader-library") {
            ShaderLibraryView(compilationState: compilationState)
                .navigationTitle("Shader Library")
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 800, height: 500)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Stored property ensures AmptDocumentController is instantiated before
    // anything else can access NSDocumentController.shared. The first
    // NSDocumentController subclass created becomes the shared instance.
    private let documentController = AmptDocumentController()

    /// Set once the main window appears; drives the dock menu.
    var playerState: PlayerState?

    func applicationWillFinishLaunching(_ notification: Notification) {
        documentController.onOpen = { url in
            FileDropCoordinator.shared.receive([url])
        }
    }

    // Handles folders dropped onto the dock icon — folders bypass NSDocumentController
    // and come through this classic delegate method instead.
    func application(_ application: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: filename, isDirectory: &isDir),
              isDir.boolValue else {
            return false // let NSDocumentController handle audio files
        }
        FileDropCoordinator.shared.receive([url])
        return true
    }

    // MARK: Dock menu

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        let info: String
        if let track = playerState?.currentTrack {
            info = "\(track.title) — \(track.artist ?? "Unknown Artist")"
        } else {
            info = "No track playing"
        }
        let infoItem = NSMenuItem(title: info, action: nil, keyEquivalent: "")
        infoItem.isEnabled = false
        menu.addItem(infoItem)
        menu.addItem(.separator())

        let isPlaying = playerState?.isPlaying ?? false
        for (title, action) in [
            ("Previous", #selector(previousAction)),
            (isPlaying ? "Pause" : "Play", #selector(playPauseAction)),
            ("Next", #selector(nextAction)),
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        return menu
    }

    @objc private func previousAction() { playerState?.previous() }
    @objc private func playPauseAction() { playerState?.togglePlayPause() }
    @objc private func nextAction() { playerState?.next() }
}

// MARK: - Document Controller

// Intercepts every NSDocumentController file-open call. Without a registered
// NSDocument subclass, the default implementation would show "cannot open"
// errors. We suppress those and route the URL to the playlist instead.
final class AmptDocumentController: NSDocumentController {
    var onOpen: ((URL) -> Void)?

    override func openDocument(
        withContentsOf url: URL,
        display displayDocument: Bool,
        completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void
    ) {
        onOpen?(url)
        completionHandler(nil, false, nil)
    }
}

// MARK: - File Drop Coordinator

@Observable
final class FileDropCoordinator {
    static let shared = FileDropCoordinator()
    var pendingURLs: [URL] = []

    func receive(_ urls: [URL]) {
        pendingURLs.append(contentsOf: urls)
    }
}
