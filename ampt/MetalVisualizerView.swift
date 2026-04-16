//
//  MetalVisualizerView.swift
//  ampt
//

import SwiftUI
import MetalKit

struct MetalVisualizerView: NSViewRepresentable {
    let audioAnalyzer: AudioAnalyzer

    func makeCoordinator() -> VisualizerRenderer {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        return VisualizerRenderer(device: device, audioAnalyzer: audioAnalyzer)
    }

    func makeNSView(context: Context) -> MTKView {
        let renderer = context.coordinator
        let mtkView = MTKView(frame: .zero, device: renderer.device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.framebufferOnly = true
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.delegate = renderer
        mtkView.layer?.isOpaque = true
        mtkView.autoresizingMask = [.width, .height]
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}
}
