//
//  VisualizerRenderer.swift
//  ampt
//

import MetalKit

final class VisualizerRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState
    let audioAnalyzer: AudioAnalyzer
    var compilationState: ShaderCompilationState?
    private(set) var currentSource: String?

    init(device: MTLDevice, audioAnalyzer: AudioAnalyzer) {
        self.device = device
        self.audioAnalyzer = audioAnalyzer

        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
        }
        self.commandQueue = queue

        // Initial pipeline from compiled default library as fallback
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to load Metal shader library")
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "visualizerVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "visualizerFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create render pipeline state: \(error)")
        }

        super.init()
    }

    @discardableResult
    func updateShader(source: String) -> String? {
        do {
            let library = try device.makeLibrary(source: source, options: nil)

            guard let vertexFn = library.makeFunction(name: "visualizerVertex") else {
                let msg = "Shader must define a 'visualizerVertex' function"
                compilationState?.error = msg
                return msg
            }
            guard let fragmentFn = library.makeFunction(name: "visualizerFragment") else {
                let msg = "Shader must define a 'visualizerFragment' function"
                compilationState?.error = msg
                return msg
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFn
            descriptor.fragmentFunction = fragmentFn
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            currentSource = source
            compilationState?.error = nil
            return nil
        } catch {
            let msg = error.localizedDescription
            compilationState?.error = msg
            return msg
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        var uniforms = audioAnalyzer.uniforms
        uniforms.resolution = SIMD2<Float>(
            Float(view.drawableSize.width),
            Float(view.drawableSize.height)
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ShaderUniforms>.size, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
