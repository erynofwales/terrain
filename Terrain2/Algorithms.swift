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
    static var name: String { get }
    var outTexture: MTLTexture { get }
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

    var outTexture: MTLTexture {
        return textures[indexes.out]
    }

    private(set) var indexes: (`in`: Int, out: Int) = (in: 0, out: 1)

    init(device: MTLDevice, library: MTLLibrary, functionName: String) throws {
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
    }

    func encode(in encoder: MTLComputeCommandEncoder, inTexture: MTLTexture?, outTexture: MTLTexture?) {
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(inTexture, index: GeneratorTextureIndex.in.rawValue)
        encoder.setTexture(inTexture, index: GeneratorTextureIndex.out.rawValue)
        encoder.dispatchThreads(Kernel.textureSize, threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
    }
}

/// "Compute" zero for every value of the height map.
class ZeroAlgorithm: Kernel, Algorithm {
    static let name = "Zero"

    init?(device: MTLDevice, library: MTLLibrary) {
        do {
            try super.init(device: device, library: library, functionName: "zeroKernel")
        } catch let e {
            print("Couldn't create compute kernel. Error: \(e)")
            return nil
        }
    }
}

/// Randomly generate heights that are independent of all others.
class RandomAlgorithm: Kernel, Algorithm {
    static let name = "Random"

    init?(device: MTLDevice, library: MTLLibrary) {
        do {
            try super.init(device: device, library: library, functionName: "randomKernel")
        } catch let e {
            print("Couldn't create compute kernel. Error: \(e)")
            return nil
        }
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
