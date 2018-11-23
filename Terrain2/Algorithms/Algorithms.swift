//
//  Algorithms.swift
//  Terrain2
//
//  Created by Eryn Wells on 11/4/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Foundation
import Metal
import os

let Log = OSLog(subsystem: "me.erynwells.Terrain2.Algorithms", category: "DiamondSquare")

enum KernelError: Error {
    case badFunction
    case badSize
    case textureCreationFailed
}

protocol TerrainGenerator {
    var name: String { get }
    var needsGPU: Bool { get }
    var outTexture: MTLTexture { get }

    func encode(in encoder: MTLComputeCommandEncoder)
    func render(progress: Progress) -> [Float]
}

class Kernel {

    class var textureSize: MTLSize {
        return MTLSize(width: 512, height: 512, depth: 1)
    }

    class func buildTexture(device: MTLDevice, size: MTLSize) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: size.width, height: size.height, mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite]
        let tex = device.makeTexture(descriptor: desc)
        return tex
    }

    let pipeline: MTLComputePipelineState
    let textures: [MTLTexture]
    let uniformBuffer: MTLBuffer?

    var outTexture: MTLTexture {
        return textures[textureIndexes.out]
    }

    private(set) var textureIndexes: (`in`: Int, out: Int) = (in: 0, out: 1)

    init(device: MTLDevice, library: MTLLibrary, functionName: String, uniformBuffer: MTLBuffer? = nil) throws {
        guard let computeFunction = library.makeFunction(name: functionName) else {
            throw KernelError.badFunction
        }
        self.pipeline = try device.makeComputePipelineState(function: computeFunction)

        // Create our input and output textures
        var textures = [MTLTexture]()
        for i in 0..<2 {
            guard let tex = Kernel.buildTexture(device: device, size: type(of: self).textureSize) else {
                print("Couldn't create heights texture i=\(i)")
                throw KernelError.textureCreationFailed
            }
            textures.append(tex)
        }
        self.textures = textures

        self.uniformBuffer = uniformBuffer
    }

    func encode(in encoder: MTLComputeCommandEncoder) {
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(textures[textureIndexes.in], index: textureIndexes.in)
        encoder.setTexture(textures[textureIndexes.out], index: textureIndexes.out)
        encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.dispatchThreads(type(of: self).textureSize, threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
    }
}

/// "Compute" zero for every value of the height map.
class ZeroAlgorithm: Kernel, TerrainGenerator {
    let name = "Zero"

    let needsGPU: Bool = true

    init?(device: MTLDevice, library: MTLLibrary) {
        do {
            try super.init(device: device, library: library, functionName: "zeroKernel")
        } catch let e {
            print("Couldn't create compute kernel. Error: \(e)")
            return nil
        }
    }

    // MARK: Algorithm

    func render(progress: Progress) -> [Float] {
        return []
    }
}

/// Implementation of the Circles algorithm.
//class CirclesAlgorithm: Algorithm {
//    static let name = "Circles"
//}
