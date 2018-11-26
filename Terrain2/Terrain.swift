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

        desc.attributes[VertexAttribute.normal.rawValue].format = .float3
        desc.attributes[VertexAttribute.normal.rawValue].offset = 0
        desc.attributes[VertexAttribute.normal.rawValue].bufferIndex = BufferIndex.normals.rawValue

        desc.attributes[VertexAttribute.texCoord.rawValue].format = .float2
        desc.attributes[VertexAttribute.texCoord.rawValue].offset = 0
        desc.attributes[VertexAttribute.texCoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue

        desc.layouts[BufferIndex.meshPositions.rawValue].stride = 12
        desc.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        desc.layouts[BufferIndex.meshPositions.rawValue].stepFunction = .perVertex

        desc.layouts[BufferIndex.normals.rawValue].stride = 12
        desc.layouts[BufferIndex.normals.rawValue].stepRate = 1
        desc.layouts[BufferIndex.normals.rawValue].stepFunction = .perVertex

        desc.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
        desc.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
        desc.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = .perVertex

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
        attributes[VertexAttribute.normal.rawValue].name = MDLVertexAttributeNormal
        attributes[VertexAttribute.texCoord.rawValue].name = MDLVertexAttributeTextureCoordinate

        plane.vertexDescriptor = mdlVertexDescriptor

        return try MTKMesh(mesh:plane, device:device)
    }

    class func computePipeline(withFunctionNamed name: String, device: MTLDevice, library: MTLLibrary) throws -> MTLComputePipelineState {
        guard let function = library.makeFunction(name: name) else {
            throw RendererError.badComputeFunction
        }
        let pipeline = try device.makeComputePipelineState(function: function)
        return pipeline
    }

    private let generatorQueue = DispatchQueue(label: "Terrain Generation Queue")

    private let updateHeightsPipeline: MTLComputePipelineState
    private let updateSurfaceNormalsPipeline: MTLComputePipelineState
    private let updateVertexNormalsPipeline: MTLComputePipelineState

    let dimensions: float2
    let segments: uint2
    let vertexDescriptor: MTLVertexDescriptor
    let mesh: MTKMesh
    let faceNormalsBuffer: MTLBuffer
    let faceMidpointsBuffer: MTLBuffer

    var generator: TerrainGenerator

    init?(dimensions dim: float2, segments seg: uint2, device: MTLDevice, library: MTLLibrary) {
        dimensions = dim
        segments = seg
        vertexDescriptor = Terrain.buildVertexDescriptor()

        do {
            mesh = try Terrain.buildMesh(withDimensions: dimensions, segments: segments, device: device, vertexDescriptor: vertexDescriptor)
        } catch let e {
            print("Couldn't create mesh. Error: \(e)")
            return nil
        }

        guard let gen = DiamondSquareGenerator(device: device) else {
            print("Couldn't create algorithm")
            return nil
        }
        gen.roughness = 1.0
        generator = gen

        do {
            updateHeightsPipeline = try Terrain.computePipeline(withFunctionNamed: "updateGeometryHeights", device: device, library: library)
            updateSurfaceNormalsPipeline = try Terrain.computePipeline(withFunctionNamed: "updateGeometryNormals", device: device, library: library)
            updateVertexNormalsPipeline = try Terrain.computePipeline(withFunctionNamed: "updateGeometryVertexNormals", device: device, library: library)
        } catch {
            print("Unable to create compute pipelines for terrain geometry updates. Error: \(error)")
            return nil
        }

        // A normal is a float3. Two triangles per segment, x * t segments.
        let faceDataLength = 12 * 2 * Int(segments.x * segments.y)
        guard let faceNormalsBuf = device.makeBuffer(length: faceDataLength, options: .storageModeShared) else {
            print("Couldn't create buffer for face normals")
            return nil
        }
        faceNormalsBuffer = faceNormalsBuf

        guard let faceMidpointsBuf = device.makeBuffer(length: faceDataLength, options: .storageModeShared) else {
            print("Couldn't create buffer for face normals")
            return nil
        }
        faceMidpointsBuffer = faceMidpointsBuf

        super.init()
    }

    func generate(completion: @escaping () -> Void) -> Progress {
        let progress = Progress(totalUnitCount: 1)
        generatorQueue.async {
            progress.becomeCurrent(withPendingUnitCount: 1)
            _ = self.generator.render(progress: progress)
            progress.completedUnitCount += 1
            progress.resignCurrent()
            completion()
        }
        return progress
    }

    func scheduleGeometryUpdates(inCommandBuffer commandBuffer: MTLCommandBuffer, uniforms: PerFrameObject<Uniforms>) {
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            //print("Scheduling update geometry heights")
            computeEncoder.label = "Geometry Heights Encoder"
            computeEncoder.pushDebugGroup("Update Heights")
            computeEncoder.setComputePipelineState(updateHeightsPipeline)
            computeEncoder.setTexture(generator.outTexture, index: GeneratorTextureIndex.in.rawValue)
            let vertexBuffer = mesh.vertexBuffers[BufferIndex.meshPositions.rawValue]
            computeEncoder.setBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: GeneratorBufferIndex.meshPositions.rawValue)
            let texCoordBuffer = mesh.vertexBuffers[BufferIndex.meshGenerics.rawValue]
            computeEncoder.setBuffer(texCoordBuffer.buffer, offset: texCoordBuffer.offset, index: GeneratorBufferIndex.texCoords.rawValue)
            computeEncoder.setBuffer(uniforms.buffer, offset: uniforms.offset, index: GeneratorBufferIndex.uniforms.rawValue)

            let threads = MTLSize(width: mesh.vertexCount, height: 1, depth: 1)
            computeEncoder.dispatchThreads(threads, threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))

            computeEncoder.popDebugGroup()
            computeEncoder.endEncoding()
        }

        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            //print("Scheduling update geometry normals")
            computeEncoder.label = "Surface Normals Encoder"
            computeEncoder.pushDebugGroup("Update Surface Normals")
            computeEncoder.setComputePipelineState(updateSurfaceNormalsPipeline)
            let indexBuffer = mesh.submeshes[0].indexBuffer
            computeEncoder.setBuffer(indexBuffer.buffer, offset: indexBuffer.offset, index: GeneratorBufferIndex.indexes.rawValue)
            let positionsBuffer = mesh.vertexBuffers[BufferIndex.meshPositions.rawValue]
            computeEncoder.setBuffer(positionsBuffer.buffer, offset: positionsBuffer.offset, index: GeneratorBufferIndex.meshPositions.rawValue)
            computeEncoder.setBuffer(faceNormalsBuffer, offset: 0, index: GeneratorBufferIndex.faceNormals.rawValue)
            computeEncoder.setBuffer(faceMidpointsBuffer, offset: 0, index: GeneratorBufferIndex.faceMidpoints.rawValue)
            computeEncoder.dispatchThreads(MTLSize(width: 2 * Int(segments.x * segments.y), height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
            computeEncoder.popDebugGroup()
            computeEncoder.endEncoding()
        }

        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.label = "Vertex Normals Encoder"
            computeEncoder.pushDebugGroup("Update Vertex Normals")
            computeEncoder.setComputePipelineState(updateVertexNormalsPipeline)
            let indexBuffer = mesh.submeshes[0].indexBuffer
            computeEncoder.setBuffer(indexBuffer.buffer, offset: indexBuffer.offset, index: GeneratorBufferIndex.indexes.rawValue)
            let positionsBuffer = mesh.vertexBuffers[BufferIndex.meshPositions.rawValue]
            computeEncoder.setBuffer(positionsBuffer.buffer, offset: positionsBuffer.offset, index: GeneratorBufferIndex.meshPositions.rawValue)
            computeEncoder.setBuffer(faceNormalsBuffer, offset: 0, index: GeneratorBufferIndex.faceNormals.rawValue)
            let normalsBuffer = mesh.vertexBuffers[BufferIndex.normals.rawValue]
            computeEncoder.setBuffer(normalsBuffer.buffer, offset: normalsBuffer.offset, index: GeneratorBufferIndex.normals.rawValue)
            computeEncoder.setBuffer(uniforms.buffer, offset: uniforms.offset, index: GeneratorBufferIndex.uniforms.rawValue)
            computeEncoder.dispatchThreads(MTLSize(width: Int(segments.x + 1), height: Int(segments.y + 1), depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
            computeEncoder.popDebugGroup()
            computeEncoder.endEncoding()
        }
    }

    private func populateInitialFaceNormals() {
        let normalsCount = 2 * Int(segments.x * segments.y)
        let faceNormals = UnsafeMutableRawPointer(faceNormalsBuffer.contents()).bindMemory(to: float3.self, capacity: normalsCount)
        for i in 0..<normalsCount {
            faceNormals[i] = float3(0, 1, 0)
        }
    }
}
