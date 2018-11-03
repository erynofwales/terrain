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

    func setupMetal(withView view: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Unable to create system Metal device")
        }
        self.device = device

        setup(view: view, withDevice: device)

        guard let queue = device.makeCommandQueue() else {
            fatalError("Unable to create Metal command queue")
        }
        queue.label = "Terrain"
        self.commandQueue = queue

        let bundle = Bundle(for: type(of: self))
        self.library = try! device.makeDefaultLibrary(bundle: bundle)

        setupRenderPipeline(withDevice: device, library: library, pixelFormat: view.colorPixelFormat)
    }

    func setup(view: MTKView, withDevice device: MTLDevice) {
        view.device = device
        view.clearColor = MTLClearColor(red: 1, green: 0, blue: 0, alpha: 1)
        view.colorPixelFormat = .bgra8Unorm
    }

    func setupRenderPipeline(withDevice device: MTLDevice, library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        let vertexShader = library.makeFunction(name: "passthroughVertex")
        let fragmentShader = library.makeFunction(name: "passthroughFragment")

        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Passthrough Pipeline"
        desc.vertexFunction = vertexShader
        desc.fragmentFunction = fragmentShader
        if let renderAttachment = desc.colorAttachments[0] {
            renderAttachment.pixelFormat = pixelFormat
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

    // MARK: - MTKViewDelegate

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
