//
//  Random.hh
//  Terrain
//
//  Created by Eryn Wells on 11/22/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

#ifndef Random_hh
#define Random_hh

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

#endif /* Random_hh */
