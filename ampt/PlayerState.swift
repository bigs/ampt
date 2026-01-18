//
//  PlayerState.swift
//  ampt
//

import Foundation
import SwiftData

@Observable
final class PlayerState {
    let audioPlayer = AudioPlayer()

    var currentTrack: Track?
    var currentIndex: Int = -1

    private var tracks: [Track] = []

    init() {
        audioPlayer.onTrackFinished = { [weak self] in
            self?.next()
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
        }
    }

    func stop() {
        audioPlayer.stop()
    }

    func clearCurrentTrack() {
        audioPlayer.stop()
        currentTrack?.stopAccessing()
        currentTrack = nil
        currentIndex = -1
    }

    func isCurrentTrack(_ track: Track) -> Bool {
        currentTrack?.id == track.id
    }

    func seek(to time: TimeInterval) {
        audioPlayer.seek(to: time)
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
}
