//
//  DockIconUpdater.swift
//  ampt
//
//  Observes PlayerState and updates the dock icon with playback progress
//

import AppKit
import Observation

@Observable
final class DockIconUpdater {

    // MARK: - Properties

    private weak var playerState: PlayerState?
    private var updateTask: Task<Void, Never>?
    private var lastUpdateProgress: Double = -1
    private let progressThreshold: Double = 0.01 // Update on 1% change

    private let iconGenerator = SpiralIconGenerator()

    // MARK: - Lifecycle

    init() {}

    deinit {
        stopObserving()
    }

    // MARK: - Public API

    @MainActor
    func startObserving(playerState: PlayerState) {
        // Stop any existing observation
        stopObserving()

        // Store reference
        self.playerState = playerState

        // Start observation loop
        updateTask = Task { @MainActor in
            while !Task.isCancelled {
                // Track changes to player state
                withObservationTracking {
                    _ = playerState.currentTime
                    _ = playerState.duration
                    _ = playerState.isPlaying
                } onChange: {
                    Task { @MainActor in
                        await self.updateIconIfNeeded()
                    }
                }

                // Throttle: check at most every 100ms
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    func stopObserving() {
        updateTask?.cancel()
        updateTask = nil
        playerState = nil
        lastUpdateProgress = -1
    }

    // MARK: - Private Methods

    @MainActor
    private func updateIconIfNeeded() {
        guard let playerState else { return }

        // Only update when playing
        guard playerState.isPlaying else {
            // Reset to static icon when not playing
            if lastUpdateProgress != 0 {
                updateDockIcon(progress: 0.0)
                lastUpdateProgress = 0
            }
            return
        }

        // Calculate progress
        let duration = playerState.duration
        guard duration > 0 else { return }

        let progress = playerState.currentTime / duration

        // Only update if progress changed by at least 1% (bucketization)
        let progressDiff = abs(progress - lastUpdateProgress)
        guard progressDiff >= progressThreshold else { return }

        // Update the dock icon
        updateDockIcon(progress: progress)
        lastUpdateProgress = progress
    }

    @MainActor
    private func updateDockIcon(progress: Double) {
        // Generate icon with progress fill
        let iconSize = CGSize(width: 512, height: 512)
        let icon = iconGenerator.generateIcon(size: iconSize, progress: progress)

        // Update dock icon
        NSApplication.shared.applicationIconImage = icon
    }
}
