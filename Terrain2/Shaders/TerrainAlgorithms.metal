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
                                  device packed_float3 *vertexes [[buffer(GeneratorBufferIndexVertexes)]],
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

kernel void updateGeometryNormals(constant float3 *vertexes [[buffer(GeneratorBufferIndexVertexes)]],
                                  constant packed_uint3 *indexes [[buffer(GeneratorBufferIndexIndexes)]],
                                  device packed_float3 *normals [[buffer(GeneratorBufferIndexNormals)]],
                                  uint tid [[thread_position_in_grid]])
{
    const uint3 triIdx = indexes[tid];
    float3 side1(vertexes[triIdx.y] - vertexes[triIdx.x]);
    float3 side2(vertexes[triIdx.y] - vertexes[triIdx.z]);
    float3 normal(normalize(cross(side1, side2)));
    normals[tid] = normal;
}

#pragma mark - ZeroGenerator

kernel void zeroKernel(texture2d<float, access::write> outTexture [[texture(GeneratorTextureIndexOut)]],
                       uint2 tid [[thread_position_in_grid]])
{
    outTexture.write(0, tid);
}

#pragma mark - RandomGenerator

kernel void randomKernel(texture2d<float, access::write> outTexture [[texture(GeneratorTextureIndexOut)]],
                         constant RandomAlgorithmUniforms &uniforms [[buffer(0)]],
                         uint2 tid [[thread_position_in_grid]])
{
    PRNG rng(uniforms.randoms[(tid.x * tid.y) % kRandomAlgorithmUniforms_RandomCount]);
    uint r = rng.xorShift();
    float x = float(r * (1.0 / float(UINT_MAX))) * 0.5f;
    outTexture.write(x, tid);
}
