#include <metal_stdlib>
using namespace metal;

struct FullscreenVertexOut {
    float4 position [[position]];
    float2 uv;
};

struct BrightnessContrastUniforms {
    float brightness;
    float contrast;
};

struct GaussianBlurUniforms {
    float2 texelStep;
    float sigma;
};

struct DeepGlowUniforms {
    float3 weights;
    float intensity;
    float4 color;
};

vertex FullscreenVertexOut fullscreenVertex(uint vertexID [[vertex_id]]) {
    constexpr float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };
    constexpr float2 coordinates[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };
    FullscreenVertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = coordinates[vertexID];
    return out;
}

inline float3 unpremultiply(float4 color) {
    return color.a > 0.0001 ? color.rgb / color.a : float3(0.0);
}

inline float4 premultiply(float3 color, float alpha) {
    return float4(clamp(color, 0.0, 1.0) * alpha, alpha);
}

fragment float4 copyFragment(
    FullscreenVertexOut in [[stage_in]],
    texture2d<float> source [[texture(0)]],
    sampler linearSampler [[sampler(0)]]
) {
    return source.sample(linearSampler, in.uv);
}

fragment float4 brightnessContrastFragment(
    FullscreenVertexOut in [[stage_in]],
    texture2d<float> source [[texture(0)]],
    sampler linearSampler [[sampler(0)]],
    constant BrightnessContrastUniforms &uniforms [[buffer(0)]]
) {
    float4 pixel = source.sample(linearSampler, in.uv);
    float3 color = unpremultiply(pixel) + uniforms.brightness;
    color = (color - 0.5) * (1.0 + uniforms.contrast) + 0.5;
    return premultiply(color, pixel.a);
}

fragment float4 gaussianBlurFragment(
    FullscreenVertexOut in [[stage_in]],
    texture2d<float> source [[texture(0)]],
    sampler linearSampler [[sampler(0)]],
    constant GaussianBlurUniforms &uniforms [[buffer(0)]]
) {
    float4 sum = source.sample(linearSampler, in.uv);
    float total = 1.0;
    float sigma = max(uniforms.sigma, 0.0001);
    for (uint index = 1; index <= 24; ++index) {
        float distance = float(index);
        float weight = exp(-0.5 * distance * distance / (sigma * sigma));
        if (weight < 0.002) {
            break;
        }
        float2 offset = uniforms.texelStep * distance;
        sum += (source.sample(linearSampler, in.uv + offset) +
                source.sample(linearSampler, in.uv - offset)) * weight;
        total += 2.0 * weight;
    }
    return sum / total;
}

fragment float4 deepGlowCombineFragment(
    FullscreenVertexOut in [[stage_in]],
    texture2d<float> source [[texture(0)]],
    texture2d<float> blurSmall [[texture(1)]],
    texture2d<float> blurMedium [[texture(2)]],
    texture2d<float> blurLarge [[texture(3)]],
    sampler linearSampler [[sampler(0)]],
    constant DeepGlowUniforms &uniforms [[buffer(0)]]
) {
    float4 original = source.sample(linearSampler, in.uv);
    float4 glow = blurSmall.sample(linearSampler, in.uv) * uniforms.weights.x
                + blurMedium.sample(linearSampler, in.uv) * uniforms.weights.y
                + blurLarge.sample(linearSampler, in.uv) * uniforms.weights.z;
    float3 light = glow.rgb * uniforms.color.rgb * uniforms.color.a * uniforms.intensity;
    float alpha = clamp(max(original.a, max(light.r, max(light.g, light.b))), 0.0, 1.0);
    return float4(min(original.rgb + light, float3(alpha)), alpha);
}
