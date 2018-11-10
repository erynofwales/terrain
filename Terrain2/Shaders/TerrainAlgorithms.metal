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

kernel void zeroKernel(texture2d<float, access::write> outTexture [[texture(GeneratorTextureIndexOut)]],
                       uint2 tid [[thread_position_in_grid]])
{
    outTexture.write(0, tid);
}

#pragma mark - RandomAlgorithm

kernel void randomKernel(texture2d<float, access::write> outTexture [[texture(GeneratorTextureIndexOut)]],
                         constant RandomAlgorithmUniforms &uniforms [[buffer(0)]],
                         uint2 tid [[thread_position_in_grid]])
{
    PRNG rng(uniforms.randoms[(tid.x * tid.y) % kRandomAlgorithmUniforms_RandomCount]);
    uint r = rng.xorShift();
    float x = float(r * (1.0 / float(UINT_MAX))) * 0.5f;
    outTexture.write(x, tid);
}
