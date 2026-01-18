//
//  AudioPlayer.swift
//  ampt
//

import Foundation
import AVFoundation

@Observable
final class AudioPlayer {
    private let engine = AudioEngine()
    private var progressTimer: Timer?

    private(set) var isPlaying: Bool = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    var volume: Float = 1.0 {
        didSet { engine.volume = volume }
    }

    var onTrackFinished: (() -> Void)?

    init() {
        engine.onFinished = { [weak self] in
            self?.handleTrackFinished()
        }
    }

    func load(_ url: URL) throws {
        stopProgressTimer()
        try engine.load(url)
        duration = engine.duration
        currentTime = 0
        isPlaying = false
    }

    func play() {
        engine.play()
        isPlaying = true
        startProgressTimer()
    }

    func pause() {
        engine.pause()
        isPlaying = false
        stopProgressTimer()
    }

    func stop() {
        engine.stop()
        currentTime = 0
        isPlaying = false
        stopProgressTimer()
    }

    func seek(to time: TimeInterval) {
        engine.seek(to: time)
        currentTime = time
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        currentTime = engine.currentTime
    }

    private func handleTrackFinished() {
        isPlaying = false
        stopProgressTimer()
        onTrackFinished?()
    }
}

private final class AudioEngine: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    var onFinished: (() -> Void)?

    var duration: TimeInterval { player?.duration ?? 0 }
    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var volume: Float = 1.0 {
        didSet { player?.volume = volume }
    }

    func load(_ url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.volume = volume
        player?.prepareToPlay()
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            DispatchQueue.main.async { [weak self] in
                self?.onFinished?()
            }
        }
    }
}
