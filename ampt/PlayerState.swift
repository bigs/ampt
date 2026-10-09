//
//  PlayerState.swift
//  ampt
//

import Foundation
import SwiftData

@Observable
final class PlayerState {
    let audioPlayer = AudioPlayer()
    private let remoteManager = MediaRemoteManager()

    var currentTrack: Track?
    var currentIndex: Int = -1

    /// Tracks whose file could not be opened the last time playback was
    /// attempted. Cleared per-track on a later successful play. Nothing is
    /// deleted automatically: an unmounted drive shouldn't wipe the playlist.
    private(set) var unavailableTrackIDs: Set<Track.ID> = []

    private var tracks: [Track] = []
    /// Open security scope for `currentTrack`; released when replaced or cleared.
    private var trackAccess: TrackAccess?

    init() {
        audioPlayer.onTrackFinished = { [weak self] in
            self?.next()
        }
        audioPlayer.onPlaybackInterrupted = { [weak self] in
            self?.updateRemoteNowPlaying()
        }
        setupRemoteCommands()
    }

    private func setupRemoteCommands() {
        remoteManager.onPlay = { [weak self] in
            self?.audioPlayer.play()
            self?.updateRemoteNowPlaying()
        }
        remoteManager.onPause = { [weak self] in
            self?.audioPlayer.pause()
            self?.updateRemoteNowPlaying()
        }
        remoteManager.onTogglePlayPause = { [weak self] in
            self?.togglePlayPause()
        }
        remoteManager.onNext = { [weak self] in
            self?.next()
        }
        remoteManager.onPrevious = { [weak self] in
            self?.previous()
        }
        remoteManager.onStop = { [weak self] in
            self?.stop()
        }
        remoteManager.onSeek = { [weak self] time in
            self?.seek(to: time)
        }
    }

    var isPlaying: Bool { audioPlayer.isPlaying }
    var currentTime: TimeInterval { audioPlayer.currentTime }
    var duration: TimeInterval { audioPlayer.duration }

    func updatePlaylist(_ tracks: [Track]) {
        self.tracks = tracks
        // Update current index if track still exists
        if let current = currentTrack,
           let newIndex = tracks.firstIndex(where: { $0.id == current.id }) {
            currentIndex = newIndex
        } else if currentTrack != nil {
            clearCurrentTrack()
        } else {
            currentIndex = -1
        }
    }

    /// Opens and starts the track. On failure the previous track keeps its
    /// access and state; the failed track is marked unavailable.
    @discardableResult
    func play(track: Track, at index: Int) -> Bool {
        guard let newAccess = TrackAccess(track: track) else {
            print("Failed to access track: \(track.title)")
            unavailableTrackIDs.insert(track.id)
            return false
        }

        do {
            try audioPlayer.load(newAccess.url)
        } catch {
            print("Failed to load track \(track.title): \(error)")
            unavailableTrackIDs.insert(track.id)
            return false
        }

        trackAccess = newAccess
        currentTrack = track
        currentIndex = index
        unavailableTrackIDs.remove(track.id)
        audioPlayer.play()
        updateRemoteNowPlaying()
        return true
    }

    func togglePlayPause() {
        if isPlaying {
            audioPlayer.pause()
        } else if currentTrack != nil {
            audioPlayer.play()
        } else {
            playFirstAvailable(from: 0, step: 1)
            return
        }
        updateRemoteNowPlaying()
    }

    func stop() {
        audioPlayer.stop()
        updateRemoteNowPlaying()
    }

    func clearCurrentTrack() {
        audioPlayer.stop()
        trackAccess = nil
        currentTrack = nil
        currentIndex = -1
        updateRemoteNowPlaying()
    }

    func isCurrentTrack(_ track: Track) -> Bool {
        currentTrack?.id == track.id
    }

    func seek(to time: TimeInterval) {
        audioPlayer.seek(to: time)
        updateRemoteNowPlaying()
    }

    func previous() {
        guard !tracks.isEmpty else { return }
        let start = currentIndex > 0 ? currentIndex - 1 : tracks.count - 1
        playFirstAvailable(from: start, step: -1)
    }

    func next() {
        guard !tracks.isEmpty else { return }
        let start = currentIndex + 1
        if start >= tracks.count || !playFirstAvailable(from: start, step: 1) {
            // End of playlist (or nothing playable after this point)
            stop()
        }
    }

    /// Walks the playlist from `from` in direction `step` until a track
    /// opens. Returns false if none did.
    @discardableResult
    private func playFirstAvailable(from: Int, step: Int) -> Bool {
        var index = from
        while tracks.indices.contains(index) {
            if play(track: tracks[index], at: index) { return true }
            index += step
        }
        return false
    }

    private func updateRemoteNowPlaying() {
        guard let track = currentTrack else {
            remoteManager.clearNowPlayingInfo()
            return
        }

        remoteManager.updateNowPlayingInfo(
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: audioPlayer.duration,
            currentTime: audioPlayer.currentTime,
            playbackRate: audioPlayer.isPlaying ? 1.0 : 0.0
        )
    }
}
