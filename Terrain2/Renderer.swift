//
//  Renderer.swift
//  Terrain2
//
//  Created by Eryn Wells on 11/3/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size & ~0xFF) + 0x100

let maxBuffersInFlight = 3

let terrainDimensions = float2(10, 10)
let terrainSegments = uint2(5, 5)

enum RendererError: Error {
    case badVertexDescriptor
    case badComputeFunction
}

class Renderer: NSObject, MTKViewDelegate {

    public let device: MTLDevice
    let library: MTLLibrary
    let commandQueue: MTLCommandQueue
    var dynamicUniformBuffer: MTLBuffer
    var pipelineState: MTLRenderPipelineState
    var normalPipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState

    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    let regenerationSemaphore = DispatchSemaphore(value: 1)

    var uniformBufferOffset = 0
    var uniformBufferIndex = 0
    var uniforms: UnsafeMutablePointer<Uniforms>

    var lightsBuffer: MTLBuffer
    var lights: UnsafeMutablePointer<Light>
    var materialBuffer: MTLBuffer
    var material: UnsafeMutablePointer<Material>

    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    var rotation: Float = 0

    var terrain: Terrain

    var drawLines = true {
        didSet {
            print("Line drawing \(drawLines ? "enabled" : "disabled")")
        }
    }

    var drawNormals = false {
        didSet {
            print("Normal drawing \(drawNormals ? "enabled" : "disabled")")
        }
    }

    private var iterateTerrainAlgorithm = true
    private var didUpdateTerrain = false

    init?(metalKitView: MTKView) {
        self.device = metalKitView.device!
        self.commandQueue = self.device.makeCommandQueue()!

        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight

        self.dynamicUniformBuffer = self.device.makeBuffer(length:uniformBufferSize,
                                                           options:[MTLResourceOptions.storageModeShared])!

        self.dynamicUniformBuffer.label = "UniformBuffer"

        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)

        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1

        guard let library = device.makeDefaultLibrary() else {
            print("Unable to create default library")
            return nil
        }
        self.library = library

        terrain = Terrain(dimensions: terrainDimensions, segments: terrainSegments, device: device, library: library)!

        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       library: library,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: terrain.vertexDescriptor)
            normalPipelineState = try Renderer.buildNormalRenderPipeline(withDevice: device, library: library, view: metalKitView)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }

        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        self.depthState = device.makeDepthStencilState(descriptor:depthStateDesciptor)!

        let lightsBufferLength = MemoryLayout<Light>.size * 4
        self.lightsBuffer = self.device.makeBuffer(length: lightsBufferLength, options: .storageModeShared)!
        self.lights = UnsafeMutableRawPointer(lightsBuffer.contents()).bindMemory(to: Light.self, capacity: 4)

        let materialBufferLength = MemoryLayout<Material>.size
        self.materialBuffer = self.device.makeBuffer(length: materialBufferLength, options: .storageModeShared)!
        self.material = UnsafeMutableRawPointer(materialBuffer.contents()).bindMemory(to: Material.self, capacity: 1)

        super.init()

        populateLights()
        populateMaterials()
    }

    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             library: MTLLibrary,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object

        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Geometry Render Pipeline"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor

        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat

        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    class func buildNormalRenderPipeline(withDevice device: MTLDevice, library: MTLLibrary, view: MTKView) throws -> MTLRenderPipelineState {
        let vertexFunction = library.makeFunction(name: "normalVertexShader")
        let fragmentFunction = library.makeFunction(name: "normalFragmentShader")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Normal Render Pipeline"
        pipelineDescriptor.sampleCount = view.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction

        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat

        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    class func buildUpdateGeometryNormalsPipeline(withDevice device: MTLDevice, library: MTLLibrary) throws -> MTLComputePipelineState {
        guard let computeFunction = library.makeFunction(name: "updateGeometryNormals") else {
            throw RendererError.badComputeFunction
        }
        return try device.makeComputePipelineState(function: computeFunction)
    }

    func scheduleAlgorithmIteration() -> Progress? {
        var progress: Progress? = nil
        regenerationSemaphore.wait()
        if !terrain.generator.needsGPU {
            print("Rendering terrain...")
            progress = self.terrain.generate {
                print("Rendering terrain...complete!")
                self.didUpdateTerrain = true
            }
        }
        regenerationSemaphore.signal()
        return progress
    }

    private func populateLights() {
        for i in 0..<4 {
            lights[i].enabled = false
        }

        lights[0].enabled = true
        lights[0].position = simd_float4(x: 2, y: 10, z: 2, w: 1)
        lights[0].color = simd_float3(0.5, 0.5, 0.3)
    }

    private func populateMaterials() {
        material[0].diffuseColor = simd_float3(0.5)
        material[0].specularColor = simd_float3(1)
        material[0].specularExponent = 10
    }

    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering

        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight

        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex

        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)
    }

    private func updateGameState() {
        /// Update any game state before rendering
        if iterateTerrainAlgorithm {
            if terrain.generator.needsGPU {
                terrain.generator.updateUniforms()
            }
        }

        uniforms[0].projectionMatrix = projectionMatrix

        let rotationAxis = float3(0, 1, 0)
        let modelMatrix = matrix4x4_rotation(radians: rotation, axis: rotationAxis)
        let viewMatrix = matrix4x4_translation(0.0, -2.0, -8.0)
        let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
        uniforms[0].modelViewMatrix = modelViewMatrix
        rotation += 0.003

        // Remove the fourth row and column from our model-view matrix. Since we're only doing rotations and translations (no scales), this serves as our normal transform matrix.
        let rotSclModelViewMatrix = float3x3(modelViewMatrix.columns.0.xyz, modelViewMatrix.columns.1.xyz, modelViewMatrix.columns.2.xyz)
        uniforms[0].normalMatrix = rotSclModelViewMatrix

        uniforms[0].terrainDimensions = terrain.dimensions
        uniforms[0].terrainSegments = terrain.segments
    }

    func draw(in view: MTKView) {
        /// Per frame updates hare

        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        _ = regenerationSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            let needsGeometryUpdate = didUpdateTerrain
            var didScheduleAlgorithmIteration = false
            let inFlightSem = inFlightSemaphore
            let regenSem = regenerationSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                if didScheduleAlgorithmIteration && self.iterateTerrainAlgorithm {
                    self.iterateTerrainAlgorithm = false
                }
                if needsGeometryUpdate {
                    self.didUpdateTerrain = false
                }
                regenSem.signal()
                inFlightSem.signal()
            }
            
            self.updateDynamicBufferState()
            
            self.updateGameState()

            if iterateTerrainAlgorithm && terrain.generator.needsGPU, let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                print("Scheduling terrain generator iteration with \(terrain.generator.name) algorithm")
                computeEncoder.label = "Generator Encoder"
                computeEncoder.pushDebugGroup("Generate Terrain: \(terrain.generator.name)")
                terrain.generator.encode(in: computeEncoder)
                computeEncoder.popDebugGroup()
                computeEncoder.endEncoding()
                didScheduleAlgorithmIteration = true
            }

            terrain.scheduleGeometryUpdates(inCommandBuffer: commandBuffer, uniforms: dynamicUniformBuffer, uniformsOffset: uniformBufferOffset)

            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            let renderPassDescriptor = view.currentRenderPassDescriptor
            
            if let renderPassDescriptor = renderPassDescriptor {
                /// Final pass rendering code here
                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                    renderEncoder.label = "Primary Render Encoder"
                    renderEncoder.pushDebugGroup("Draw Plane")
                    
                    renderEncoder.setCullMode(.none)
                    
                    renderEncoder.setFrontFacing(.counterClockwise)
                    
                    renderEncoder.setRenderPipelineState(pipelineState)
                    
                    renderEncoder.setDepthStencilState(depthState)

                    renderEncoder.setTriangleFillMode(drawLines ? .lines : .fill)

                    renderEncoder.setVertexBuffer(terrain.faceNormalsBuffer, offset: 0, index: BufferIndex.faceNormals.rawValue)
                    renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                    renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)

                    renderEncoder.setFragmentBuffer(lightsBuffer, offset: 0, index: BufferIndex.lights.rawValue)
                    renderEncoder.setFragmentBuffer(materialBuffer, offset: 0, index: BufferIndex.materials.rawValue)
                    
                    for (index, element) in terrain.mesh.vertexDescriptor.layouts.enumerated() {
                        guard let layout = element as? MDLVertexBufferLayout else {
                            return
                        }
                        
                        if layout.stride != 0 {
                            let buffer = terrain.mesh.vertexBuffers[index]
                            renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
                        }
                    }

                    renderEncoder.setVertexTexture(terrain.generator.outTexture, index: 0)
                    
                    for submesh in terrain.mesh.submeshes {
                        renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                            indexCount: submesh.indexCount,
                                                            indexType: submesh.indexType,
                                                            indexBuffer: submesh.indexBuffer.buffer,
                                                            indexBufferOffset: submesh.indexBuffer.offset)
                    }
                    
                    renderEncoder.popDebugGroup()
                    renderEncoder.endEncoding()
                }

                if drawNormals {
                    let normalsRenderPassDescriptor = renderPassDescriptor.copy() as! MTLRenderPassDescriptor
                    normalsRenderPassDescriptor.colorAttachments[0].loadAction = .load
                    normalsRenderPassDescriptor.colorAttachments[0].storeAction = .store

                    if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: normalsRenderPassDescriptor) {
                        renderEncoder.label = "Normals Render Encoder"

                        renderEncoder.setRenderPipelineState(normalPipelineState)
                        renderEncoder.setDepthStencilState(depthState)

                        encodeVertexNormalsDrawCall(encoder: renderEncoder)
                        encodeFaceNormalsDrawCall(encoder: renderEncoder)

                        renderEncoder.endEncoding()
                    }
                }

                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
            }
            
            commandBuffer.commit()
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here

        let aspect = Float(size.width) / Float(size.height)
        projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(65), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
    }

    private func encodeVertexNormalsDrawCall(encoder: MTLRenderCommandEncoder) {
        encoder.pushDebugGroup("Draw Vertex Normals")

        let vertexBuffer = terrain.mesh.vertexBuffers[BufferIndex.meshPositions.rawValue]
        let normalBuffer = terrain.mesh.vertexBuffers[BufferIndex.normals.rawValue]

        encoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: NormalBufferIndex.points.rawValue)
        encoder.setVertexBuffer(normalBuffer.buffer, offset: normalBuffer.offset, index: NormalBufferIndex.normals.rawValue)
        encoder.setVertexBuffer(dynamicUniformBuffer, offset: uniformBufferOffset, index: NormalBufferIndex.uniforms.rawValue)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: 2, instanceCount: terrain.mesh.vertexCount)

        encoder.popDebugGroup()
    }

    private func encodeFaceNormalsDrawCall(encoder: MTLRenderCommandEncoder) {
        encoder.pushDebugGroup("Draw Face Normals")

        let faceMidpointsBuffer = terrain.faceMidpointsBuffer
        let faceNormalsBuffer = terrain.faceNormalsBuffer
        let instanceCount = 2 * Int(terrain.segments.x * terrain.segments.y)

        encoder.setVertexBuffer(faceMidpointsBuffer, offset: 0, index: NormalBufferIndex.points.rawValue)
        encoder.setVertexBuffer(faceNormalsBuffer, offset: 0, index: NormalBufferIndex.normals.rawValue)
        encoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: NormalBufferIndex.uniforms.rawValue)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: 2, instanceCount: instanceCount)

        encoder.popDebugGroup()
    }
}
