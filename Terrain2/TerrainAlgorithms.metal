//
//  TerrainAlgorithms.metal
//  Terrain2
//
//  Created by Eryn Wells on 11/4/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

#include <metal_stdlib>
#include "ShaderTypes.h"
using namespace metal;

kernel void zeroKernel(texture2d<float, access::write> outTexture [[texture(GeneratorTextureIndexOut)]],
                       uint2 tid [[thread_position_in_grid]])
{
    outTexture.write(0, tid);
}

kernel void randomKernel(texture2d<float, access::write> outTexture [[texture(GeneratorTextureIndexOut)]],
                         uint2 tid [[thread_position_in_grid]])
{
    float x = 2.0 * M_PI_F * (tid.x / 128.0);
    outTexture.write(sin(x), tid);
}
