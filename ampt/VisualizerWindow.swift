//
//  VisualizerWindow.swift
//  ampt
//

import SwiftUI
import SwiftData

struct VisualizerWindow: View {
    let audioAnalyzer: AudioAnalyzer
    let compilationState: ShaderCompilationState
    @Query(filter: #Predicate<Shader> { $0.isActive }) private var activeShaders: [Shader]

    private var activeShaderSource: String {
        activeShaders.first?.source ?? Shader.defaultSource
    }

    var body: some View {
        MetalVisualizerView(
            audioAnalyzer: audioAnalyzer,
            shaderSource: activeShaderSource,
            compilationState: compilationState
        )
        .ignoresSafeArea()
    }
}
