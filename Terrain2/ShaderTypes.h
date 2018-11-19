//
//  ShaderTypes.h
//  Terrain2
//
//  Created by Eryn Wells on 11/3/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

typedef NS_ENUM(NSInteger, BufferIndex)
{
    BufferIndexMeshPositions  = 0,
    BufferIndexNormals        = 1,
    BufferIndexMeshGenerics   = 2,
    BufferIndexUniforms       = 3,
};

typedef NS_ENUM(NSInteger, VertexAttribute)
{
    VertexAttributePosition  = 0,
    VertexAttributeNormal    = 1,
    VertexAttributeTexCoord  = 2,
};

typedef NS_ENUM(NSInteger, TextureIndex)
{
    TextureIndexColor    = 0,
};

typedef NS_ENUM(NSInteger, GeneratorBufferIndex) {
    GeneratorBufferIndexMeshPositions = 0,
    GeneratorBufferIndexTexCoords = 1,
    GeneratorBufferIndexIndexes = 2,
    GeneratorBufferIndexNormals = 3,
    GeneratorBufferIndexUniforms = 4,
};

typedef NS_ENUM(NSInteger, GeneratorTextureIndex) {
    GeneratorTextureIndexIn  = 0,
    GeneratorTextureIndexOut = 1,
};

typedef struct {
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
    packed_float2 terrainDimensions;
    packed_uint2 terrainSegments;
} Uniforms;

#define kRandomAlgorithmUniforms_RandomCount (41)

typedef struct {
    uint randoms[kRandomAlgorithmUniforms_RandomCount];
} RandomAlgorithmUniforms;

#ifndef __METAL_VERSION__
extern void RandomAlgorithmUniforms_refreshRandoms(RandomAlgorithmUniforms *uniforms);
#endif

#endif /* ShaderTypes_h */

