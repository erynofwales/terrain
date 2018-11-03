//
//  Renderer.swift
//  Terrain
//
//  Created by Eryn Wells on 11/3/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Cocoa
import Metal
import MetalKit

class Renderer: NSObject, MTKViewDelegate {

    var device: MTLDevice!
    var library: MTLLibrary!
    var commandQueue: MTLCommandQueue!
    var renderPipeline: MTLRenderPipelineState!

    var terrainGridSize = CGSize(width: 11, height: 11)
    var terrain = Terrain()

    func setupMetal(withDevice device: MTLDevice, pixelFormat: MTLPixelFormat) {
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            fatalError("Unable to create Metal command queue")
        }
        queue.label = "Terrain"
        self.commandQueue = queue

        let bundle = Bundle(for: type(of: self))
        guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
            fatalError("Unable to create default Metal library")
        }
        self.library = library

        setupRenderPipeline(withDevice: device, library: library, pixelFormat: pixelFormat)
    }

    func setupRenderPipeline(withDevice device: MTLDevice, library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        let vertexShader = library.makeFunction(name: "passthroughVertex")
        let fragmentShader = library.makeFunction(name: "passthroughFragment")

        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Pixel Pipeline"
        desc.vertexFunction = vertexShader
        desc.fragmentFunction = fragmentShader
        if let renderAttachment = desc.colorAttachments[0] {
            renderAttachment.pixelFormat = pixelFormat
            // Pulled all this from SO. I don't know what it means, but it makes the alpha channel work.
            // TODO: Learn what this means???
            // https://stackoverflow.com/q/43727335/1174185
            renderAttachment.isBlendingEnabled = true
            renderAttachment.alphaBlendOperation = .add
            renderAttachment.rgbBlendOperation = .add
            renderAttachment.sourceRGBBlendFactor = .sourceAlpha
            renderAttachment.sourceAlphaBlendFactor = .sourceAlpha
            renderAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            renderAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }

        do {
            renderPipeline = try device.makeRenderPipelineState(descriptor: desc)
        } catch let e {
            print("Couldn't set up pixel pipeline! \(e)")
            renderPipeline = nil
        }
    }

    func prepareToRender() {
        guard let buffer = device.makeBuffer(length: terrain.minimumBufferSize(forGridSize: terrainGridSize), options: .storageModeShared) else {
            fatalError("Couldn't create terrain buffer")
        }
        terrain.generateVertexes(intoBuffer: buffer, size: terrainGridSize)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("Size of \(view.debugDescription) will change to \(size)")
    }

    func draw(in view: MTKView) {
        guard let buffer = commandQueue.makeCommandBuffer() else {
            return
        }

        var didEncode = false
        buffer.label = "Terrain"

        if let renderPass = view.currentRenderPassDescriptor {
            if let encoder = buffer.makeRenderCommandEncoder(descriptor: renderPass) {
                encoder.label = "Terrain"
                encoder.setRenderPipelineState(renderPipeline)
                encoder.setVertexBuffer(terrain.buffer, offset: 0, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: terrain.vertexCount(forGridSize: terrainGridSize))
                encoder.setTriangleFillMode(.lines)
                encoder.endEncoding()
                didEncode = true
            }
        }

        if didEncode, let drawable = view.currentDrawable {
            buffer.present(drawable)
        }
        buffer.commit()
    }

}
