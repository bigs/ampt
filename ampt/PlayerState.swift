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

    private var tracks: [Track] = []

    init() {
        audioPlayer.onTrackFinished = { [weak self] in
            self?.next()
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
        }
    }

    func play(track: Track, at index: Int) {
        // Stop accessing previous track's security scope
        currentTrack?.stopAccessing()

        currentTrack = track
        currentIndex = index

        // Resolve bookmark and start accessing
        guard track.startAccessing(),
              let url = track.resolveURL() else {
            print("Failed to access track: \(track.title)")
            return
        }

        do {
            try audioPlayer.load(url)
            audioPlayer.play()
            updateRemoteNowPlaying()
        } catch {
            print("Failed to load track: \(error)")
            track.stopAccessing()
        }
    }

    func togglePlayPause() {
        if isPlaying {
            audioPlayer.pause()
        } else if currentTrack != nil {
            audioPlayer.play()
        } else if !tracks.isEmpty {
            play(track: tracks[0], at: 0)
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
        currentTrack?.stopAccessing()
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
        let newIndex = currentIndex > 0 ? currentIndex - 1 : tracks.count - 1
        play(track: tracks[newIndex], at: newIndex)
    }

    func next() {
        guard !tracks.isEmpty else { return }
        let newIndex = (currentIndex + 1) % tracks.count
        play(track: tracks[newIndex], at: newIndex)
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
