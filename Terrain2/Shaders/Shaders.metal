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
    float2 texCoord [[attribute(VertexAttributeTexCoord)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float3 normal;
    float2 texCoord;
} ColorInOut;

#pragma mark - Geometry Shaders

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]])
{
    ColorInOut out;

    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(in.position, 1.0);
    out.normal = uniforms.normalMatrix * in.normal;
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

vertex float4 normalVertexShader(constant packed_float3 *positions [[buffer(BufferIndexMeshPositions)]],
                                 constant packed_float3 *normals [[buffer(BufferIndexNormals)]],
                                 constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]],
                                 uint instID [[instance_id]],
                                 uint vertID [[vertex_id]])
{
    float3 v = positions[instID];
    if ( vertID == 1 )
    {
        v += 0.25 * normals[instID];
    }
    float4 out = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(v, 1.0);
    return out;
}

fragment half4 normalFragmentShader()
{
    return half4(0, 1, 0, 1);
}
