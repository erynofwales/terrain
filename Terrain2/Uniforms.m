//
//  Uniforms.c
//  Terrain2
//
//  Created by Eryn Wells on 11/6/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

#include <stdio.h>
#include "ShaderTypes.h"

void RandomAlgorithmUniforms_refreshRandoms(RandomAlgorithmUniforms *uniforms) {
    for (int i = 0; i < kRandomAlgorithmUniforms_RandomCount; i++) {
        uniforms->randoms[i] = arc4random();
    }
}
