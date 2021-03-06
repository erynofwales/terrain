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

typedef NS_ENUM(NSInteger, BufferIndex) {
    BufferIndexMeshPositions = 0,
    BufferIndexNormals = 1,
    BufferIndexMeshGenerics = 2,
    BufferIndexFaceNormals = 3,
    BufferIndexUniforms = 4,
    BufferIndexLights = 5,
    BufferIndexMaterials = 6,
};

typedef NS_ENUM(NSInteger, NormalBufferIndex) {
    NormalBufferIndexPoints = 0,
    NormalBufferIndexNormals = 1,
    NormalBufferIndexGeometryUniforms = 2,
    NormalBufferIndexNormalUniforms = 3,
    NormalBufferIndexType = 4,
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
    GeneratorBufferIndexFaceNormals = 4,
    GeneratorBufferIndexFaceMidpoints = 5,
    GeneratorBufferIndexUniforms = 6,
};

typedef NS_ENUM(NSInteger, GeneratorTextureIndex) {
    GeneratorTextureIndexIn  = 0,
    GeneratorTextureIndexOut = 1,
};

typedef struct {
    bool enabled;
#ifdef __METAL_VERSION__
    simd::float4 position;
    simd::float3 color;
#else
    simd_float4 position;
    simd_float3 color;
#endif
} Light;

struct Material {
#ifdef __METAL_VERSION__
    simd::float3 diffuseColor;
    simd::float3 specularColor;
#else
    simd_float3 diffuseColor;
    simd_float3 specularColor;
#endif
    float specularExponent;
};

struct Uniforms {
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
    matrix_float3x3 normalMatrix;
#ifdef __METAL_VERSION__
    simd::packed_float2 terrainDimensions;
    simd::packed_uint2 terrainSegments;
#else
    simd_packed_float2 terrainDimensions;
    simd_packed_uint2 terrainSegments;
#endif
};

typedef NS_ENUM(NSInteger, NormalType) {
    NormalTypeVertex = 1,
    NormalTypeFace = 2,
};

struct NormalUniforms {
#ifdef __METAL_VERSION__
    simd::float3 vertexNormalColor;
    simd::float3 faceNormalColor;
#else
    simd_float3 vertexNormalColor;
    simd_float3 faceNormalColor;
#endif
};

#endif /* ShaderTypes_h */

