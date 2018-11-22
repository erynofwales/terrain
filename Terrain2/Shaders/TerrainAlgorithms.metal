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
#include "Random.hh"

using namespace metal;

inline uint segmentIndex(uint2 pos, uint2 dims)
{
    return pos.y * dims.x + pos.x;
}

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
    faceMidpoints[tid] = (1.0 / 3.0) * (v1 + v2 + v3);
}

/// Update the vertex normals based on the computed face normals.
///
/// Credit for this procedure goes to https://github.com/emilyhorsman.
///
/// {A..F} are the adjacent face normals to the vertex @.
///
/// (0, 0) *----*----*
///        |   /|   /|
///        |  / |  / |
///        | /  |F/  |
///        |/  A|/E  |
///        *----@----*
///        |  B/|D  /|
///        |  /C|  / |
///        | /  | /  |
///        |/   |/   |
///        *----*----* (2, 2)
///
/// Adding each vector divided by n would be better, but numerical stability
/// isn't low risk here since these vectors are all normalized.
///
kernel void updateGeometryVertexNormals(constant packed_float3 *meshPositions [[buffer(GeneratorBufferIndexMeshPositions)]],
                                        constant packed_float3 *faceNormals [[buffer(GeneratorBufferIndexFaceNormals)]],
                                        constant Uniforms &uniforms [[buffer(GeneratorBufferIndexUniforms)]],
                                        device packed_float3 *vertexNormals [[buffer(GeneratorBufferIndexNormals)]],
                                        uint2 tid [[thread_position_in_grid]])
{
    const uint2 segs = uniforms.terrainSegments;

    float3 normal = float3();
    uint adjacent = 0;

    if (tid.y > 0 && tid.x > 0) {
        uint aIndex = 2 * segmentIndex(uint2(tid.x - 1, tid.y - 1), segs) + 1;
        normal += faceNormals[aIndex];
        adjacent += 1;
    }
    if (tid.y > 0 && tid.x < segs.x) {
        uint segment = segmentIndex(uint2(tid.x, tid.y - 1), segs);
        uint bIndex = 2 * segment;
        uint cIndex = 2 * segment + 1;
        normal += faceNormals[bIndex] + faceNormals[cIndex];
        adjacent += 2;
    }
    if (tid.x < segs.x && tid.y < segs.y) {
        uint dIndex = 2 * segmentIndex(tid, segs);
        normal += faceNormals[dIndex];
        adjacent += 1;
    }
    if (tid.x > 0 && tid.y < segs.y) {
        uint segment = segmentIndex(uint2(tid.x - 1, tid.y), segs);
        uint eIndex = 2 * segment + 1;
        uint fIndex = 2 * segment;
        normal += faceNormals[eIndex] + faceNormals[fIndex];
        adjacent += 2;
    }

    if (adjacent != 0) {
        normal = normalize(normal / float(adjacent));
        uint idx = segmentIndex(tid, segs);
        vertexNormals[idx] = normal;
    }
}

#pragma mark - ZeroGenerator

kernel void zeroKernel(texture2d<float, access::write> outTexture [[texture(GeneratorTextureIndexOut)]],
                       uint2 tid [[thread_position_in_grid]])
{
    outTexture.write(0, tid);
}

