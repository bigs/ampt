//
//  VisualizerWindow.swift
//  ampt
//

import SwiftUI

struct VisualizerWindow: View {
    let audioAnalyzer: AudioAnalyzer

    var body: some View {
        MetalVisualizerView(audioAnalyzer: audioAnalyzer)
            .ignoresSafeArea()
    }
}
