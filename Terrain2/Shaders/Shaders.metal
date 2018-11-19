//
//  Shaders.metal
//  Terrain2
//
//  Created by Eryn Wells on 11/3/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

typedef struct
{
    float3 position [[attribute(VertexAttributePosition)]];
    float3 normal   [[attribute(VertexAttributeNormal)]];
    float2 texCoord [[attribute(VertexAttributeTexcoord)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float3 normal;
    float2 texCoord;
} ColorInOut;

#pragma mark - Geometry Shaders

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               texture2d<float> heights [[texture(0)]],
                               constant Uniforms & uniforms [[buffer(BufferIndexUniforms)]])
{
//    constexpr sampler s(coord::normalized, address::clamp_to_zero, filter::linear);

    ColorInOut out;

//    float4 height = heights.sample(s, in.texCoord);

    // Replace the y coordinate with the height we read from the texture.
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(in.position, 1.0);
    out.normal = in.normal;
    out.texCoord = in.texCoord;

    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(TextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);

    half4 colorSample   = colorMap.sample(colorSampler, in.texCoord.xy);

    return float4(1.0);
}

#pragma mark - Normal Shaders

vertex float4 normalVertexShader(constant float3 *positions [[buffer(BufferIndexMeshPositions)]],
                                 constant float3 *normals [[buffer(BufferIndexNormals)]],
                                 uint instID [[instance_id]],
                                 uint vertID [[vertex_id]])
{
    float3 out = positions[instID];
    if ( vertID == 1 )
    {
        out += normals[instID];
    }
    return float4(out, 1.0);
}

fragment half4 normalFragmentShader()
{
    return half4(0.0, 0.0, 1.0, 1.0);
}
