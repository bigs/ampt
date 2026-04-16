//
//  AudioAnalyzer.swift
//  ampt
//

import Foundation

@Observable
final class AudioAnalyzer {
    private let audioPlayer: AudioPlayer
    private var timer: Timer?
    private var startTime: TimeInterval = 0

    private(set) var uniforms = ShaderUniforms(
        time: 0, amplitude: 0, peak: 0,
        bass: 0, mid: 0, treble: 0,
        resolution: .zero
    )

    // Smoothing state
    private var smoothBass: Float = 0
    private var smoothMid: Float = 0
    private var smoothTreble: Float = 0
    private var smoothAmplitude: Float = 0
    private var smoothPeak: Float = 0

    init(audioPlayer: AudioPlayer) {
        self.audioPlayer = audioPlayer
        startTime = ProcessInfo.processInfo.systemUptime
    }

    func start() {
        guard timer == nil else { return }
        startTime = ProcessInfo.processInfo.systemUptime
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        let spectrum = audioPlayer.readSpectrum()
        let elapsed = Float(ProcessInfo.processInfo.systemUptime - startTime)

        // Exponential smoothing — different rates per band
        smoothBass = ema(smoothBass, target: spectrum.bass, alpha: 0.15)
        smoothMid = ema(smoothMid, target: spectrum.mid, alpha: 0.25)
        smoothTreble = ema(smoothTreble, target: spectrum.treble, alpha: 0.5)
        smoothAmplitude = ema(smoothAmplitude, target: spectrum.amplitude, alpha: 0.3)
        smoothPeak = ema(smoothPeak, target: spectrum.peak, alpha: 0.4)

        // Normalize to [0,1] — these scale factors are tuned empirically,
        // real magnitudes depend on content and mastering levels.
        uniforms.time = elapsed
        uniforms.amplitude = min(1, smoothAmplitude * 5.0)
        uniforms.peak = min(1, smoothPeak * 3.0)
        uniforms.bass = min(1, smoothBass * 8.0)
        uniforms.mid = min(1, smoothMid * 10.0)
        uniforms.treble = min(1, smoothTreble * 15.0)
    }

    private func ema(_ current: Float, target: Float, alpha: Float) -> Float {
        alpha * target + (1 - alpha) * current
    }
}
