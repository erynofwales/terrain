//
//  TerrainAlgorithms.metal
//  Terrain2
//
//  Created by Eryn Wells on 11/4/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

#include <metal_stdlib>
#include <metal_types>
#include "ShaderTypes.h"
using namespace metal;

/// A pseudo-random number generator providing several algorithms.
/// - http://reedbeta.com/blog/quick-and-easy-gpu-random-numbers-in-d3d11/
struct PRNG {
    PRNG(uint seed) : mSeed(wangHash(seed)) { }

    /// Generate a random unsigned integer using a linear congruential generator.
    uint lcg() {
        mSeed = 1664525 * mSeed + 1013904223;
        return mSeed;
    }

    /// Generate a random unsigned integer using the Xorshift algorithm from George Marsaglia's paper.
    uint xorShift() {
        mSeed ^= (mSeed << 13);
        mSeed ^= (mSeed >> 17);
        mSeed ^= (mSeed << 5);
        return mSeed;
    }

    uint wangHash(uint seed) {
        seed = (seed ^ 61) ^ (seed >> 16);
        seed *= 9;
        seed = seed ^ (seed >> 4);
        seed *= 0x27d4eb2d;
        seed = seed ^ (seed >> 15);
        return seed;
    }

private:
    uint mSeed;
};

kernel void updateGeometryHeights(texture2d<float> texture [[texture(GeneratorTextureIndexIn)]],
                                  constant float2 *texCoords [[buffer(GeneratorBufferIndexTexCoords)]],
                                  constant Uniforms &uniforms [[buffer(GeneratorBufferIndexUniforms)]],
                                  device packed_float3 *vertexes [[buffer(GeneratorBufferIndexMeshPositions)]],
                                  uint2 tid [[thread_position_in_grid]])
{
    constexpr sampler s(coord::normalized, address::clamp_to_zero, filter::linear);

    const uint vIdx = tid.y * uniforms.terrainSegments.x + tid.x;

    // Get the height from the texture.
    float2 texCoord = texCoords[vIdx];
    float4 height = texture.sample(s, texCoord);

    // Update the vertex data.
    vertexes[vIdx].y = height.r;
}

kernel void updateGeometryNormals(constant packed_float3 *meshPositions [[buffer(GeneratorBufferIndexMeshPositions)]],
                                  constant packed_ushort3 *indexes [[buffer(GeneratorBufferIndexIndexes)]],
                                  device packed_float3 *faceNormals [[buffer(GeneratorBufferIndexFaceNormals)]],
                                  device packed_float3 *faceMidpoints [[buffer(GeneratorBufferIndexFaceMidpoints)]],
                                  uint tid [[thread_position_in_grid]])
{
    const ushort3 triangleIndex = indexes[tid];

    const float3 v1 = meshPositions[triangleIndex.x];
    const float3 v2 = meshPositions[triangleIndex.y];
    const float3 v3 = meshPositions[triangleIndex.z];

    float3 side1 = v1 - v2;
    float3 side2 = v1 - v3;
    float3 normal = normalize(cross(side1, side2));
    faceNormals[tid] = normal;
    faceMidpoints[tid] = 0.3333333333 * (v1 + v2 + v3);
}

kernel void updateGeometryVertexNormals()
{
    
}

#pragma mark - ZeroGenerator

kernel void zeroKernel(texture2d<float, access::write> outTexture [[texture(GeneratorTextureIndexOut)]],
                       uint2 tid [[thread_position_in_grid]])
{
    outTexture.write(0, tid);
}

