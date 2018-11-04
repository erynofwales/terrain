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
        let desc = MTLVertexDescriptor()

        desc.attributes[VertexAttribute.position.rawValue].format = .float3
        desc.attributes[VertexAttribute.position.rawValue].offset = 0
        desc.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue

        desc.attributes[VertexAttribute.texcoord.rawValue].format = .float2
        desc.attributes[VertexAttribute.texcoord.rawValue].offset = 0
        desc.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue

        desc.attributes[VertexAttribute.gridCoord.rawValue].format = .uint2
        desc.attributes[VertexAttribute.gridCoord.rawValue].offset = 0
        desc.attributes[VertexAttribute.gridCoord.rawValue].bufferIndex = BufferIndex.meshGridCoords.rawValue

        desc.layouts[BufferIndex.meshPositions.rawValue].stride = 12
        desc.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        desc.layouts[BufferIndex.meshPositions.rawValue].stepFunction = .perVertex

        desc.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
        desc.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
        desc.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = .perVertex

        desc.layouts[BufferIndex.meshGridCoords.rawValue].stride = MemoryLayout<uint2>.stride
        desc.layouts[BufferIndex.meshGridCoords.rawValue].stepRate = 1
        desc.layouts[BufferIndex.meshGridCoords.rawValue].stepFunction = .perVertex

        return desc
    }

    /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor.
    ///
    /// - parameter dimensions: Coordinate dimensions of the plane.
    /// - parameter segments: Number of segments to divide each dimension into.
    /// - parameter device: Metal device.
    /// - parameter vertexDescriptor: Description of how to lay out vertex data in GPU memory.
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
        attributes[VertexAttribute.gridCoord.rawValue].name = "Grid Coordinate"

        plane.vertexDescriptor = mdlVertexDescriptor

        return try MTKMesh(mesh:plane, device:device)
    }

    private static let heightMapSize = MTLSize(width: 512, height: 512, depth: 1)

    class func buildHeightsTexture(device: MTLDevice) -> MTLTexture? {
        let heightsDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: heightMapSize.width, height: heightMapSize.height, mipmapped: false)
        heightsDesc.usage = [.shaderRead, .shaderWrite]

        let tex = device.makeTexture(descriptor: heightsDesc)

        if let tex = tex {
            var initialHeights = [Float]()
            let numberOfHeights = tex.height * tex.width
            initialHeights.reserveCapacity(numberOfHeights)
            for _ in 0..<numberOfHeights {
                initialHeights.append(Float.random(in: 0...0.5))
            }
            let origin = MTLOrigin(x: 0, y: 0, z: 0)
            let size = MTLSize(width: tex.width, height: tex.height, depth: 1)
            let region = MTLRegion(origin: origin, size: size)
            let bytesPerRow = MemoryLayout<Float>.stride * tex.width
            tex.replace(region: region, mipmapLevel: 0, withBytes: initialHeights, bytesPerRow: bytesPerRow)
        }

        return tex
    }

    let dimensions: float2
    let segments: uint2
    let vertexDescriptor: MTLVertexDescriptor
    let mesh: MTKMesh
    let heightMap: MTLTexture

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

        guard let tex = Terrain.buildHeightsTexture(device: device) else {
            print("Couldn't create heights texture")
            return nil
        }
        heightMap = tex

        super.init()
    }
}
