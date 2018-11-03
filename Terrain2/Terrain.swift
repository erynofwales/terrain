//
//  Terrain.swift
//  Terrain
//
//  Created by Eryn Wells on 11/3/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Cocoa
import MetalKit

class Terrain: NSObject {

    /// Create a Metal vertex descriptor specifying how vertices will by laid out for input into our render pipeline and how we'll layout our Model IO vertices.
    class func buildVertexDescriptor() -> MTLVertexDescriptor {
        let mtlVertexDescriptor = MTLVertexDescriptor()

        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = .float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue

        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].format = .float2
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue

        mtlVertexDescriptor.attributes[VertexAttribute.gridCoord.rawValue].format = .uint2
        mtlVertexDescriptor.attributes[VertexAttribute.gridCoord.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.gridCoord.rawValue].bufferIndex = BufferIndex.meshGridCoords.rawValue

        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 12
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = .perVertex

        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = .perVertex

        mtlVertexDescriptor.layouts[BufferIndex.meshGridCoords.rawValue].stride = MemoryLayout<uint2>.stride
        mtlVertexDescriptor.layouts[BufferIndex.meshGridCoords.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshGridCoords.rawValue].stepFunction = .perVertex

        return mtlVertexDescriptor
    }

    /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor.
    /// @param dimensions Coordinate dimensions of the plane
    /// @param segments Number of segments to divide each dimension into
    /// @param device Metal device
    /// @param vertexDescriptor Description of how to lay out vertex data in GPU memory
    class func buildMesh(withDimensions dimensions: float2, segments: uint2, device: MTLDevice, vertexDescriptor: MTLVertexDescriptor) throws -> MTKMesh {
        let metalAllocator = MTKMeshBufferAllocator(device: device)

        let plane = MDLMesh.newPlane(withDimensions: dimensions,
                                     segments: segments,
                                     geometryType: .triangles,
                                     allocator: metalAllocator)

        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)

        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate

        plane.vertexDescriptor = mdlVertexDescriptor

        return try MTKMesh(mesh:plane, device:device)
    }

    let dimensions: float2
    let segments: uint2
    let vertexDescriptor: MTLVertexDescriptor
    let mesh: MTKMesh
    let heights: MTLTexture

    init?(dimensions dim: float2, segments seg: uint2, device: MTLDevice) {
        dimensions = dim
        segments = seg
        vertexDescriptor = Terrain.buildVertexDescriptor()

        do {
            mesh = try Terrain.buildMesh(withDimensions: dimensions, segments: segments, device: device, vertexDescriptor: vertexDescriptor)
        } catch let e {
            print("Couldn't create mesh. Error: \(e)")
            return nil
        }

        let heightsDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Float, width: Int(segments.x), height: Int(segments.y), mipmapped: false)
        heightsDesc.usage = [.shaderRead, .shaderWrite]
        guard let tex = device.makeTexture(descriptor: heightsDesc) else {
            print("Couldn't create heights texture")
            return nil
        }
        heights = tex

        super.init()
    }
}
