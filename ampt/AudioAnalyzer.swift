//
//  AudioAnalyzer.swift
//  ampt
//

import Foundation

/// Turns raw spectrum readings into smoothed, normalised shader uniforms.
/// Sampled once per rendered frame by `VisualizerRenderer`, so it runs at
/// the display rate and only while a visualizer window is open.
final class AudioAnalyzer {
    private let audioPlayer: AudioPlayer
    private let startTime = ProcessInfo.processInfo.systemUptime

    // Smoothing state
    private var smoothBass: Float = 0
    private var smoothMid: Float = 0
    private var smoothTreble: Float = 0
    private var smoothAmplitude: Float = 0
    private var smoothPeak: Float = 0

    init(audioPlayer: AudioPlayer) {
        self.audioPlayer = audioPlayer
    }

    func sample() -> ShaderUniforms {
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
        return ShaderUniforms(
            time: elapsed,
            amplitude: min(1, smoothAmplitude * 5.0),
            peak: min(1, smoothPeak * 3.0),
            bass: min(1, smoothBass * 8.0),
            mid: min(1, smoothMid * 10.0),
            treble: min(1, smoothTreble * 15.0),
            resolution: .zero
        )
    }

    private func ema(_ current: Float, target: Float, alpha: Float) -> Float {
        alpha * target + (1 - alpha) * current
    }
}
