//
//  Shader.swift
//  ampt
//

import Foundation
import SwiftData

@Model
final class Shader {
    var title: String
    var source: String
    var isActive: Bool
    var dateCreated: Date

    init(title: String, source: String, isActive: Bool = false) {
        self.title = title
        self.source = source
        self.isActive = isActive
        self.dateCreated = Date()
    }

    static func seedDefaultIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<Shader>()
        guard (try? context.fetchCount(descriptor)) == 0 else { return }
        let shader = Shader(title: "Aurora Ring", source: defaultSource, isActive: true)
        context.insert(shader)
        try? context.save()
    }

    static let newShaderTemplate = """
#include <metal_stdlib>
using namespace metal;

struct ShaderUniforms {
    float time;
    float amplitude;
    float peak;
    float bass;
    float mid;
    float treble;
    float2 resolution;
};

struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut visualizerVertex(uint vid [[vertex_id]]) {
    float2 pos = float2((vid << 1) & 2, vid & 2);
    VertexOut out;
    out.position = float4(pos * 2.0 - 1.0, 0.0, 1.0);
    return out;
}

fragment float4 visualizerFragment(VertexOut in [[stage_in]],
                                   constant ShaderUniforms &u [[buffer(0)]]) {
    float2 uv = in.position.xy / u.resolution;
    float3 color = float3(uv, 0.5 + 0.5 * sin(u.time));
    color *= 0.3 + u.amplitude * 0.7;
    return float4(color, 1.0);
}
"""

    static let defaultSource = """
#include <metal_stdlib>
using namespace metal;

struct ShaderUniforms {
    float time;
    float amplitude;
    float peak;
    float bass;
    float mid;
    float treble;
    float2 resolution;
};

struct VertexOut {
    float4 position [[position]];
};

// Full-screen triangle from vertex_id — no vertex buffer needed.
vertex VertexOut visualizerVertex(uint vid [[vertex_id]]) {
    VertexOut out;
    // Generates a triangle that covers [-1,1] clip space:
    //   vid 0 → (-1, -1)
    //   vid 1 → ( 3, -1)
    //   vid 2 → (-1,  3)
    float2 pos = float2((vid << 1) & 2, vid & 2);
    out.position = float4(pos * 2.0 - 1.0, 0.0, 1.0);
    return out;
}

// Attempt at an interesting reactive visualization.
fragment float4 visualizerFragment(VertexOut in [[stage_in]],
                                   constant ShaderUniforms &u [[buffer(0)]]) {
    float2 uv = (in.position.xy - u.resolution * 0.5) / min(u.resolution.x, u.resolution.y);
    float r = length(uv);
    float theta = atan2(uv.y, uv.x);

    float t = u.time;

    // Concentric rings — spacing and phase driven by bass
    float rings = sin(r * 14.0 - t * 1.8 - u.bass * 8.0);
    rings *= sin(r * 9.0 + t * 0.9 + u.amplitude * 5.0);

    // Angular warping from treble transients
    float angular = sin(theta * 5.0 + t * 0.4) * u.treble * 0.6;
    angular += sin(theta * 3.0 - t * 0.7) * u.mid * 0.3;

    float pattern = rings + angular;

    // Color palette — warm ↔ cool shift with frequency content
    float3 deep   = float3(0.05, 0.08, 0.18);   // near-black blue
    float3 warm   = float3(0.85, 0.25, 0.12);    // ember orange
    float3 cool   = float3(0.15, 0.45, 0.95);    // electric blue
    float3 accent = float3(0.30, 0.90, 0.50);    // green highlight

    float s = smoothstep(-1.0, 1.0, pattern);
    float3 color = mix(cool, warm, s);
    color = mix(color, accent, u.mid * 0.35 * smoothstep(0.4, 0.8, s));

    // Brightness reacts to amplitude — keep a floor so it's never black
    float brightness = 0.15 + u.amplitude * 0.85;
    color *= brightness;

    // Glow near center on peaks
    float glow = exp(-r * 3.5) * u.peak * 0.6;
    color += glow * mix(warm, cool, sin(t * 0.5) * 0.5 + 0.5);

    // Vignette
    color *= 1.0 - smoothstep(0.5, 1.3, r);

    // Darken to background color at edges
    color = mix(deep, color, smoothstep(1.4, 0.6, r));

    return float4(color, 1.0);
}
"""
}
