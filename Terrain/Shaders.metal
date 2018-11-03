//
//  Shaders.metal
//  Terrain
//
//  Created by Eryn Wells on 11/3/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// From HelloCompute sample code project.
// Vertex shader outputs and per-fragmeht inputs. Includes clip-space position and vertex outputs interpolated by rasterizer and fed to each fragment genterated by clip-space primitives.
struct RasterizerData {
    // The [[position]] attribute qualifier of this member indicates this value is the clip space position of the vertex when this structure is returned from the vertex shader.
    float4 position [[position]];

    // Since this member does not have a special attribute qualifier, the rasterizer will interpolate its value with values of other vertices making up the triangle and pass that interpolated value to the fragment shader for each fragment in that triangle.
    float2 textureCoordinate;
};

vertex RasterizerData passthroughVertex(constant packed_float3 *vertexes [[buffer(0)]],
                                        uint vid [[vertex_id]])
{
    constant packed_float3 &v = vertexes[vid];
    RasterizerData out;
    out.position = float4(v, 1.0);
    out.textureCoordinate = float2();
    return out;
}

fragment half4 passthroughFragment(RasterizerData in [[stage_in]])
{
    return half4(1.0);
}
