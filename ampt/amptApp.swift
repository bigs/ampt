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
            ContentView(playerState: playerState)
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
