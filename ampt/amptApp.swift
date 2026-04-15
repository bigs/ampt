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
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var playerState = PlayerState()
    @State private var dockIconUpdater = DockIconUpdater()
    @State private var dockMenuManager: DockMenuManager?

    var body: some Scene {
        WindowGroup {
            ContentView(playerState: playerState, fileDropCoordinator: .shared)
                .environment(\.dockIconUpdater, dockIconUpdater)
                .onAppear {
                    if dockMenuManager == nil {
                        dockMenuManager = DockMenuManager(playerState: playerState)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 300, height: 400)
        .windowResizability(.contentMinSize)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Stored property ensures AmptDocumentController is instantiated before
    // anything else can access NSDocumentController.shared. The first
    // NSDocumentController subclass created becomes the shared instance.
    private let documentController = AmptDocumentController()

    func applicationWillFinishLaunching(_ notification: Notification) {
        documentController.onOpen = { url in
            FileDropCoordinator.shared.receive([url])
        }
    }
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

// MARK: - Environment Key

private struct DockIconUpdaterKey: EnvironmentKey {
    static let defaultValue: DockIconUpdater? = nil
}

extension EnvironmentValues {
    var dockIconUpdater: DockIconUpdater? {
        get { self[DockIconUpdaterKey.self] }
        set { self[DockIconUpdaterKey.self] = newValue }
    }
}
