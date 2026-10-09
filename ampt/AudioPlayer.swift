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
    /// Playback stopped without user action (engine could not resume after an
    /// output device change). `isPlaying` is already false when this fires.
    var onPlaybackInterrupted: (() -> Void)?

    init() {
        engine.onFinished = { [weak self] in
            self?.handleTrackFinished()
        }
        engine.onInterrupted = { [weak self] in
            self?.handleInterrupted()
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
        guard engine.play() else { return }
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

    private func handleInterrupted() {
        isPlaying = false
        stopProgressTimer()
        currentTime = engine.currentTime
        onPlaybackInterrupted?()
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

/// Owns the AVAudioEngine graph. Resilient to the system output device
/// changing underneath it (AirPods hopping to another device, headphones
/// unplugged, sample-rate changes):
///
/// - On `AVAudioEngineConfigurationChange` the engine's graph is torn down by
///   the framework, but on macOS `engine.isRunning` may still report true.
///   Touching the player node in that state blocks on a dead render thread.
///   We therefore never trust `isRunning` after a stop: any stop marks the
///   graph dirty and the next `play()` rebuilds connections before starting.
/// - Pausing stops IO entirely rather than idling the output unit, so resume
///   is a fresh hardware start. That start is what macOS keys AirPods
///   automatic switching on; a continuously-open silent output never
///   re-triggers it.
private final class AudioEngine {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let spectrumAnalyzer = SpectrumAnalyzer()
    private var audioFile: AVAudioFile?
    private var configObserver: NSObjectProtocol?

    /// First frame of the currently scheduled segment.
    private var seekFrame: AVAudioFramePosition = 0
    /// Last observed absolute position; equals `seekFrame` while not playing.
    /// Survives the engine dying, which makes `playerNode.lastRenderTime` nil.
    private var lastKnownFrame: AVAudioFramePosition = 0
    private var needsSchedule = true
    private var graphNeedsRebuild = true
    private var completionToken = 0

    private(set) var isPlaying = false

    var onFinished: (() -> Void)?
    /// Playback stopped for a reason other than user action or end of track
    /// (e.g. the engine could not be restarted after an output device change).
    var onInterrupted: (() -> Void)?

    var duration: TimeInterval {
        guard let file = audioFile else { return 0 }
        return Double(file.length) / file.processingFormat.sampleRate
    }

    var currentTime: TimeInterval {
        guard let file = audioFile else { return 0 }
        return Double(currentFrame()) / file.processingFormat.sampleRate
    }

    var volume: Float = 1.0 {
        didSet { engine.mainMixerNode.outputVolume = volume }
    }

    init() {
        engine.attach(playerNode)
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }
    }

    deinit {
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
        }
    }

    func load(_ url: URL) throws {
        haltPlayback()
        audioFile = try AVAudioFile(forReading: url)
        setPosition(0)
    }

    /// Returns false if the engine could not be started; state is left paused.
    @discardableResult
    func play() -> Bool {
        guard audioFile != nil else { return false }

        if graphNeedsRebuild {
            rebuildGraph()
        }
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("Failed to start audio engine: \(error)")
                graphNeedsRebuild = true
                return false
            }
        }

        if needsSchedule {
            scheduleSegment(from: seekFrame)
            needsSchedule = false
        }

        playerNode.play()
        isPlaying = true
        return true
    }

    func pause() {
        let frame = currentFrame()
        haltPlayback()
        setPosition(frame)
    }

    func stop() {
        haltPlayback()
        setPosition(0)
    }

    func seek(to time: TimeInterval) {
        guard let file = audioFile else { return }
        let wasPlaying = isPlaying

        completionToken += 1
        isPlaying = false
        playerNode.stop()

        let frame = AVAudioFramePosition(time * file.processingFormat.sampleRate)
        setPosition(max(0, min(frame, file.length)))

        if wasPlaying, !play() {
            onInterrupted?()
        }
    }

    func readSpectrum() -> AudioSpectrum {
        spectrumAnalyzer.spectrum
    }

    // MARK: - Private

    private func handleConfigurationChange() {
        let wasPlaying = isPlaying
        let frame = currentFrame()
        haltPlayback()
        setPosition(frame)

        guard wasPlaying else { return }
        if !play() {
            onInterrupted?()
        }
    }

    /// Stops IO and the player node, invalidates pending completions, and
    /// marks the graph for rebuild. Engine is stopped first: once the output
    /// unit is down the player node cannot block waiting on a render cycle.
    private func haltPlayback() {
        completionToken += 1
        isPlaying = false
        engine.stop()
        playerNode.stop()
        needsSchedule = true
        graphNeedsRebuild = true
    }

    private func setPosition(_ frame: AVAudioFramePosition) {
        seekFrame = frame
        lastKnownFrame = frame
        needsSchedule = true
    }

    private func currentFrame() -> AVAudioFramePosition {
        guard isPlaying,
              let file = audioFile,
              let nodeTime = playerNode.lastRenderTime,
              nodeTime.isSampleTimeValid,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return lastKnownFrame
        }
        // playerTime is in the player's output format, i.e. file.processingFormat.
        lastKnownFrame = max(0, min(file.length, seekFrame + playerTime.sampleTime))
        return lastKnownFrame
    }

    /// Reconnects the player to the mixer and reinstalls the analysis tap.
    /// Must be called with the engine stopped. The mixer's output format is
    /// resolved against the *current* output device, so a stale tap or
    /// connection from a previous device never survives.
    private func rebuildGraph() {
        guard let file = audioFile else { return }
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.disconnectNodeOutput(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)
        engine.mainMixerNode.outputVolume = volume
        installTap()
        engine.prepare()
        graphNeedsRebuild = false
    }

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
                self.isPlaying = false
                self.setPosition(file.length)
                self.onFinished?()
            }
        }
    }

    private func installTap() {
        let analyzer = spectrumAnalyzer
        // format: nil → tap follows whatever the mixer currently outputs. A
        // fixed format captured at load time would mismatch after a device
        // with a different sample rate becomes the output.
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            analyzer.process(buffer, sampleRate: Float(buffer.format.sampleRate))
        }
    }
}
