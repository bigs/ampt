//
//  MetalVisualizerView.swift
//  ampt
//

import SwiftUI
import MetalKit

struct MetalVisualizerView: NSViewRepresentable {
    let audioAnalyzer: AudioAnalyzer
    var shaderSource: String
    var compilationState: ShaderCompilationState

    func makeCoordinator() -> VisualizerRenderer {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        let renderer = VisualizerRenderer(device: device, audioAnalyzer: audioAnalyzer)
        renderer.compilationState = compilationState
        return renderer
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

        // Compile initial shader from source
        renderer.updateShader(source: shaderSource)

        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let renderer = context.coordinator
        if shaderSource != renderer.currentSource {
            renderer.updateShader(source: shaderSource)
        }
    }
}
