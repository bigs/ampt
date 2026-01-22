//
//  DockMenuManager.swift
//  ampt
//

import AppKit

@MainActor
final class DockMenuManager: NSObject, NSApplicationDelegate {
    private let playerState: PlayerState

    init(playerState: PlayerState) {
        self.playerState = playerState
        super.init()
        NSApplication.shared.delegate = self
    }

    @objc private func previousAction() {
        playerState.previous()
    }

    @objc private func playPauseAction() {
        playerState.togglePlayPause()
    }

    @objc private func nextAction() {
        playerState.next()
    }

    // MARK: - NSApplicationDelegate

    nonisolated func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        MainActor.assumeIsolated {
            buildMenu()
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Track info (disabled, just for display)
        let trackInfoItem: NSMenuItem
        if let track = playerState.currentTrack {
            let artist = track.artist ?? "Unknown Artist"
            trackInfoItem = NSMenuItem(title: "\(track.title) — \(artist)", action: nil, keyEquivalent: "")
        } else {
            trackInfoItem = NSMenuItem(title: "No track playing", action: nil, keyEquivalent: "")
        }
        trackInfoItem.isEnabled = false
        menu.addItem(trackInfoItem)

        menu.addItem(NSMenuItem.separator())

        // Previous
        let previousItem = NSMenuItem(title: "Previous", action: #selector(previousAction), keyEquivalent: "")
        previousItem.target = self
        menu.addItem(previousItem)

        // Play/Pause
        let isPlaying = playerState.isPlaying
        let playPauseItem = NSMenuItem(
            title: isPlaying ? "Pause" : "Play",
            action: #selector(playPauseAction),
            keyEquivalent: ""
        )
        playPauseItem.target = self
        menu.addItem(playPauseItem)

        // Next
        let nextItem = NSMenuItem(title: "Next", action: #selector(nextAction), keyEquivalent: "")
        nextItem.target = self
        menu.addItem(nextItem)

        return menu
    }
}
