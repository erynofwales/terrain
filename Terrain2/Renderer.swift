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
    var depthState: MTLDepthStencilState
    var colorMap: MTLTexture

    let updateGeometryHeightsPipeline: MTLComputePipelineState
    let updateGeometryNormalsPipeline: MTLComputePipelineState

    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    let regenerationSemaphore = DispatchSemaphore(value: 1)

    var uniformBufferOffset = 0
    var uniformBufferIndex = 0
    var uniforms: UnsafeMutablePointer<Uniforms>

    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    var rotation: Float = 0

    var terrain: Terrain

    var drawLines = true

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

        terrain = Terrain(dimensions: float2(10, 10), segments: uint2(100, 100), device: device, library: library)!

        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       library: library,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: terrain.vertexDescriptor)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }

        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        self.depthState = device.makeDepthStencilState(descriptor:depthStateDesciptor)!

        do {
            colorMap = try Renderer.loadTexture(device: device, textureName: "ColorMap")
        } catch {
            print("Unable to load texture. Error info: \(error)")
            return nil
        }

        do {
            updateGeometryHeightsPipeline = try Renderer.buildUpdateGeometryHeightsPipeline(withDevice: device, library: library)
            updateGeometryNormalsPipeline = try Renderer.buildUpdateGeometryNormalsPipeline(withDevice: device, library: library)
        } catch {
            print("Unable to create update geometry pipeline. Error: \(error)")
            return nil
        }

        super.init()

    }

    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             library: MTLLibrary,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object

        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor

        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat

        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    class func buildUpdateGeometryHeightsPipeline(withDevice device: MTLDevice, library: MTLLibrary) throws -> MTLComputePipelineState {
        guard let computeFunction = library.makeFunction(name: "updateGeometryHeights") else {
            throw RendererError.badComputeFunction
        }
        return try device.makeComputePipelineState(function: computeFunction)
    }

    class func buildUpdateGeometryNormalsPipeline(withDevice device: MTLDevice, library: MTLLibrary) throws -> MTLComputePipelineState {
        guard let computeFunction = library.makeFunction(name: "updateGeometryNormals") else {
            throw RendererError.badComputeFunction
        }
        return try device.makeComputePipelineState(function: computeFunction)
    }

    class func loadTexture(device: MTLDevice,
                           textureName: String) throws -> MTLTexture {
        /// Load texture data with optimal parameters for sampling

        let textureLoader = MTKTextureLoader(device: device)

        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ]

        return try textureLoader.newTexture(name: textureName,
                                            scaleFactor: 1.0,
                                            bundle: nil,
                                            options: textureLoaderOptions)

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
        uniforms[0].modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
        rotation += 0.003

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

            if didScheduleAlgorithmIteration || needsGeometryUpdate {
                if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                print("Scheduling update geometry heights")
                computeEncoder.label = "Geometry Heights Encoder"
                computeEncoder.pushDebugGroup("Update Geometry: Heights")
                computeEncoder.setComputePipelineState(updateGeometryHeightsPipeline)
                computeEncoder.setTexture(terrain.generator.outTexture, index: GeneratorTextureIndex.in.rawValue)
                let vertexBuffer = terrain.mesh.vertexBuffers[BufferIndex.meshPositions.rawValue]
                computeEncoder.setBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: GeneratorBufferIndex.vertexes.rawValue)
                let texCoordBuffer = terrain.mesh.vertexBuffers[BufferIndex.meshGenerics.rawValue]
                computeEncoder.setBuffer(texCoordBuffer.buffer, offset: texCoordBuffer.offset, index: GeneratorBufferIndex.texCoords.rawValue)
                computeEncoder.setBuffer(dynamicUniformBuffer, offset: uniformBufferOffset, index: GeneratorBufferIndex.uniforms.rawValue)
                computeEncoder.dispatchThreads(MTLSize(width: Int(terrain.segments.x + 1), height: Int(terrain.segments.y + 1), depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
                computeEncoder.popDebugGroup()
                computeEncoder.endEncoding()
                }

                if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                    print("Scheduling update geometry normals")
                    computeEncoder.label = "Geometry Normals Encoder"
                    computeEncoder.pushDebugGroup("Update Geometry: Normals")
                    computeEncoder.setComputePipelineState(updateGeometryNormalsPipeline)
                    let indexBuffer = terrain.mesh.submeshes[0].indexBuffer
                    computeEncoder.setBuffer(indexBuffer.buffer, offset: indexBuffer.offset, index: GeneratorBufferIndex.indexes.rawValue)
                    let vertexBuffer = terrain.mesh.vertexBuffers[BufferIndex.meshPositions.rawValue]
                    computeEncoder.setBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: GeneratorBufferIndex.vertexes.rawValue)
                    let normalBuffer = terrain.mesh.vertexBuffers[BufferIndex.normals.rawValue]
                    computeEncoder.setBuffer(normalBuffer.buffer, offset: normalBuffer.offset, index: GeneratorBufferIndex.normals.rawValue)
                    computeEncoder.dispatchThreads(MTLSize(width: terrain.mesh.vertexCount, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
                    computeEncoder.popDebugGroup()
                    computeEncoder.endEncoding()
                }
            }
            
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
                    
                    renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                    renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                    
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
                    renderEncoder.setFragmentTexture(colorMap, index: TextureIndex.color.rawValue)
                    
                    for submesh in terrain.mesh.submeshes {
                        renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                            indexCount: submesh.indexCount,
                                                            indexType: submesh.indexType,
                                                            indexBuffer: submesh.indexBuffer.buffer,
                                                            indexBufferOffset: submesh.indexBuffer.offset)
                    }
                    
                    renderEncoder.popDebugGroup()
                    
                    renderEncoder.endEncoding()
                    
                    if let drawable = view.currentDrawable {
                        commandBuffer.present(drawable)
                    }
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
}

// Generic matrix math utility functions
func matrix4x4_rotation(radians: Float, axis: float3) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, zs, -1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}
