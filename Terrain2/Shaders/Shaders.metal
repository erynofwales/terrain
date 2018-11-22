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

typedef struct {
    float3 position [[attribute(VertexAttributePosition)]];
    float3 normal   [[attribute(VertexAttributeNormal)]];
    float2 texCoord [[attribute(VertexAttributeTexCoord)]];
} Vertex;

typedef struct {
    float4 position [[position]];
    float3 eyeCoords;
    float3 normal;
    float2 texCoord;
} ColorInOut;

#pragma mark - Geometry Shaders

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant packed_float3 *faceNormals [[buffer(BufferIndexFaceNormals)]],
                               constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]],
                               uint vid [[vertex_id]])
{
    ColorInOut out;

    float4 vertexCoords = float4(in.position, 1.0);
    float4 eyeCoords = uniforms.modelViewMatrix * vertexCoords;

    out.position = uniforms.projectionMatrix * eyeCoords;
    out.eyeCoords = eyeCoords.xyz / eyeCoords.w;
    // TODO: Use the face normal.
    out.normal = normalize(in.normal);
    out.texCoord = in.texCoord;

    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant Light *lights [[buffer(BufferIndexLights)]],
                               constant Material *materials [[buffer(BufferIndexMaterials)]],
                               constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]])
{
    // Compute the normal at this position.
    float3 normal = normalize(uniforms.normalMatrix * in.normal);

    // Compute the vector pointing to the light from this position.
    float3 lightDirection;
    constant Light &light = lights[0];
    if (light.position.w == 0.0) {
        lightDirection = normalize(light.position.xyz);
    } else {
        lightDirection = normalize(light.position.xyz / light.position.w - in.eyeCoords);
    }

    // Compute the direction of the viewer from this position.
    float3 viewDirection = normalize(-in.eyeCoords.xyz);

    float4 out;
    float lightDirDotNormal = dot(lightDirection, normal);
    if (lightDirDotNormal <= 0.0) {
        // No color contribution to this pixel.
        out = float4(0);
    } else {
        constant Material &material = materials[0];

        // Comput the direction of reflection given the light direction and the normal at this point. Negate it because the vector returned points from the light to this position and we want it from this position toward the light.
        float3 reflection = -reflect(lightDirection, normal);

        float3 color = lightDirDotNormal * light.color * material.diffuseColor;
        float reflectDotViewDir = dot(reflection, viewDirection);
        if (reflectDotViewDir > 0.0) {
            float factor = pow(reflectDotViewDir, material.specularExponent);
            color += factor * material.specularColor * light.color;
        }
        out = float4(color, 1);
    }
    return out;
}

#pragma mark - Normal Shaders

vertex float4 normalVertexShader(constant packed_float3 *positions [[buffer(NormalBufferIndexPoints)]],
                                 constant packed_float3 *normals [[buffer(NormalBufferIndexNormals)]],
                                 constant Uniforms &uniforms [[buffer(NormalBufferIndexUniforms)]],
                                 uint instID [[instance_id]],
                                 uint vertID [[vertex_id]])
{
    float3 v = positions[instID];
    if ( vertID == 1 )
    {
        v += 0.25 * normals[instID];
    }
    float4 out = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(v, 1);
    return out;
}

fragment half4 normalFragmentShader()
{
    return half4(0, 1, 0, 1);
}
