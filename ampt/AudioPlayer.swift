//
//  AudioPlayer.swift
//  ampt
//

import Foundation
import AVFoundation
import Accelerate
import os

struct AudioSpectrum: Sendable {
    var bass: Float = 0
    var mid: Float = 0
    var treble: Float = 0
    var amplitude: Float = 0
    var peak: Float = 0
}

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

    func readSpectrum() -> AudioSpectrum {
        engine.readSpectrum()
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

// MARK: - Spectrum Analyzer

final class SpectrumAnalyzer: @unchecked Sendable {
    private let fftSize: Int
    private let fftSetup: FFTSetup?
    private let lock = OSAllocatedUnfairLock(initialState: AudioSpectrum())

    init(fftSize: Int = 1024) {
        self.fftSize = fftSize
        let log2n = vDSP_Length(log2(Float(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    var spectrum: AudioSpectrum {
        lock.withLock { $0 }
    }

    func process(_ buffer: AVAudioPCMBuffer, sampleRate: Float) {
        guard let channelData = buffer.floatChannelData,
              let fftSetup else { return }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let n = min(frameCount, fftSize)
        guard n > 0 else { return }

        // Mix to mono
        var mono = [Float](repeating: 0, count: n)
        for ch in 0..<channelCount {
            let ptr = channelData[ch]
            for i in 0..<n {
                mono[i] += ptr[i]
            }
        }
        if channelCount > 1 {
            var scale = 1.0 / Float(channelCount)
            vDSP_vsmul(mono, 1, &scale, &mono, 1, vDSP_Length(n))
        }

        // RMS amplitude
        var rms: Float = 0
        vDSP_rmsqv(mono, 1, &rms, vDSP_Length(n))

        // Peak
        var peak: Float = 0
        vDSP_maxmgv(mono, 1, &peak, vDSP_Length(n))

        // Apply Hann window
        var windowed = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(mono, 1, window, 1, &windowed, 1, vDSP_Length(n))

        // FFT
        let halfN = fftSize / 2
        var real = [Float](repeating: 0, count: halfN)
        var imag = [Float](repeating: 0, count: halfN)

        real.withUnsafeMutableBufferPointer { realBP in
            imag.withUnsafeMutableBufferPointer { imagBP in
                var split = DSPSplitComplex(realp: realBP.baseAddress!, imagp: imagBP.baseAddress!)

                windowed.withUnsafeBufferPointer { wBP in
                    wBP.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { ptr in
                        vDSP_ctoz(ptr, 2, &split, 1, vDSP_Length(halfN))
                    }
                }

                let log2n = vDSP_Length(log2(Float(fftSize)))
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))

                // Squared magnitudes
                var mags = [Float](repeating: 0, count: halfN)
                vDSP_zvmags(&split, 1, &mags, 1, vDSP_Length(halfN))

                // Scale
                var scaleFactor = 2.0 / Float(fftSize)
                vDSP_vsmul(mags, 1, &scaleFactor, &mags, 1, vDSP_Length(halfN))

                // Square root for magnitude
                var count = Int32(halfN)
                vvsqrtf(&mags, mags, &count)

                // Bin into frequency bands
                let binHz = sampleRate / Float(fftSize)
                let bassEnd = max(1, min(halfN, Int(250.0 / binHz)))
                let midEnd = min(halfN, Int(4000.0 / binHz))
                let trebleEnd = min(halfN, Int(20000.0 / binHz))

                let bass = Self.bandAverage(mags, from: 1, to: bassEnd)
                let mid = Self.bandAverage(mags, from: bassEnd, to: midEnd)
                let treble = Self.bandAverage(mags, from: midEnd, to: trebleEnd)

                let result = AudioSpectrum(
                    bass: bass,
                    mid: mid,
                    treble: treble,
                    amplitude: rms,
                    peak: peak
                )

                lock.withLock { $0 = result }
            }
        }
    }

    private static func bandAverage(_ mags: [Float], from: Int, to: Int) -> Float {
        guard to > from, from >= 0, to <= mags.count else { return 0 }
        var sum: Float = 0
        for i in from..<to {
            sum += mags[i]
        }
        return sum / Float(to - from)
    }
}

// MARK: - Audio Engine

private final class AudioEngine {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let spectrumAnalyzer = SpectrumAnalyzer()
    private var audioFile: AVAudioFile?
    private var seekFrame: AVAudioFramePosition = 0
    private var needsSchedule = true
    private var completionToken = 0

    var onFinished: (() -> Void)?

    var duration: TimeInterval {
        guard let file = audioFile else { return 0 }
        return Double(file.length) / file.processingFormat.sampleRate
    }

    var currentTime: TimeInterval {
        guard let nodeTime = playerNode.lastRenderTime,
              nodeTime.isSampleTimeValid,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return Double(seekFrame) / (audioFile?.processingFormat.sampleRate ?? 44100)
        }
        let frames = seekFrame + playerTime.sampleTime
        return max(0, Double(frames) / playerTime.sampleRate)
    }

    var volume: Float = 1.0 {
        didSet { engine.mainMixerNode.outputVolume = volume }
    }

    init() {
        engine.attach(playerNode)
    }

    func load(_ url: URL) throws {
        completionToken += 1
        playerNode.stop()
        engine.mainMixerNode.removeTap(onBus: 0)

        if engine.isRunning {
            engine.stop()
        }

        audioFile = try AVAudioFile(forReading: url)
        guard let file = audioFile else { return }

        engine.disconnectNodeOutput(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)
        engine.mainMixerNode.outputVolume = volume

        installTap()
        engine.prepare()

        seekFrame = 0
        needsSchedule = true
    }

    func play() {
        guard audioFile != nil else { return }

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("Failed to start audio engine: \(error)")
                return
            }
        }

        if needsSchedule {
            scheduleSegment(from: seekFrame)
            needsSchedule = false
        }

        playerNode.play()
    }

    func pause() {
        // Capture current position before pausing so seek-while-paused works.
        // After pause, playerTime still resolves because the schedule remains,
        // but saving the frame here makes the position available even if the
        // engine is later stopped (e.g. on load).
        if let nodeTime = playerNode.lastRenderTime,
           nodeTime.isSampleTimeValid,
           let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            seekFrame = seekFrame + playerTime.sampleTime
        }
        completionToken += 1
        playerNode.stop()
        needsSchedule = true
    }

    func stop() {
        completionToken += 1
        playerNode.stop()
        seekFrame = 0
        needsSchedule = true
    }

    func seek(to time: TimeInterval) {
        guard let file = audioFile else { return }
        let wasPlaying = playerNode.isPlaying

        completionToken += 1
        playerNode.stop()

        seekFrame = AVAudioFramePosition(time * file.processingFormat.sampleRate)
        seekFrame = max(0, min(seekFrame, file.length))
        needsSchedule = true

        if wasPlaying {
            scheduleSegment(from: seekFrame)
            needsSchedule = false
            playerNode.play()
        }
    }

    func readSpectrum() -> AudioSpectrum {
        spectrumAnalyzer.spectrum
    }

    // MARK: - Private

    private func scheduleSegment(from frame: AVAudioFramePosition) {
        guard let file = audioFile else { return }
        let remaining = AVAudioFrameCount(file.length - frame)
        guard remaining > 0 else { return }

        let token = completionToken

        playerNode.scheduleSegment(
            file,
            startingFrame: frame,
            frameCount: remaining,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.completionToken == token else { return }
                self.needsSchedule = true
                self.onFinished?()
            }
        }
    }

    private func installTap() {
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let analyzer = spectrumAnalyzer
        let sampleRate = Float(format.sampleRate)

        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) { buffer, _ in
            analyzer.process(buffer, sampleRate: sampleRate)
        }
    }
}
