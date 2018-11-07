//
//  Algorithms.swift
//  Terrain2
//
//  Created by Eryn Wells on 11/4/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Foundation
import Metal

enum KernelError: Error {
    case badFunction
    case textureCreationFailed
}

protocol Algorithm {
    var name: String { get }
    var outTexture: MTLTexture { get }

    func updateUniforms()
    func encode(in encoder: MTLComputeCommandEncoder)
}

class Kernel {
    static let textureSize = MTLSize(width: 512, height: 512, depth: 1)

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
            guard let tex = Kernel.buildTexture(device: device, size: Kernel.textureSize) else {
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
        encoder.dispatchThreads(Kernel.textureSize, threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
    }
}

/// "Compute" zero for every value of the height map.
class ZeroAlgorithm: Kernel, Algorithm {
    let name = "Zero"

    init?(device: MTLDevice, library: MTLLibrary) {
        do {
            try super.init(device: device, library: library, functionName: "zeroKernel")
        } catch let e {
            print("Couldn't create compute kernel. Error: \(e)")
            return nil
        }
    }

    // MARK: Algorithm

    func updateUniforms() { }
}

/// Randomly generate heights that are independent of all others.
class RandomAlgorithm: Kernel, Algorithm {
    let name = "Random"

    private var uniforms: UnsafeMutablePointer<RandomAlgorithmUniforms>

    init?(device: MTLDevice, library: MTLLibrary) {
        let bufferSize = (MemoryLayout<RandomAlgorithmUniforms>.stride & ~0xFF) + 0x100;
        guard let buffer = device.makeBuffer(length: bufferSize, options: [.storageModeShared]) else {
            print("Couldn't create uniform buffer")
            return nil
        }

        uniforms = UnsafeMutableRawPointer(buffer.contents()).bindMemory(to: RandomAlgorithmUniforms.self, capacity:1)

        do {
            try super.init(device: device, library: library, functionName: "randomKernel", uniformBuffer: buffer)
        } catch let e {
            print("Couldn't create compute kernel. Error: \(e)")
            return nil
        }

        updateUniforms()
    }

    func updateUniforms() {
        RandomAlgorithmUniforms_refreshRandoms(uniforms)
    }
}

/// Implementation of the Diamond-Squares algorithm.
/// - https://en.wikipedia.org/wiki/Diamond-square_algorithm
//class DiamondSquareAlgorithm: Algorithm {
//    static let name = "Diamond-Square"
//}

/// Implementation of the Circles algorithm.
//class CirclesAlgorithm: Algorithm {
//    static let name = "Circles"
//}
