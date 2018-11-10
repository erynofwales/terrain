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

protocol TerrainGenerator {
    var name: String { get }
    var outTexture: MTLTexture { get }

    func updateUniforms()
    func encode(in encoder: MTLComputeCommandEncoder)
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
class RandomAlgorithm: Kernel, TerrainGenerator {
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
public class DiamondSquareAlgorithm: TerrainGenerator {
    public struct Box {
        public typealias Point = (x: Int, y: Int)
        public typealias Size = (w: Int, h: Int)

        let origin: Point
        let size: Size

        init(origin o: Point, size s: Size) {
            origin = o
            size = s
        }

        var corners: [Point] {
            return [northwest, southwest, northeast, northwest]
        }

        var sideMidpoints: [Point] {
            return [north, west, south, east]
        }

        var north: Point {
            return (x: origin.x + (size.w / 2 + 1), y: origin.y)
        }

        var west: Point {
            return (x: origin.x, y: origin.y + (size.h / 2 + 1))
        }

        var south: Point {
            return (x: origin.x + (size.w / 2 + 1), y: origin.y + size.h)
        }

        var east: Point {
            return (x: origin.x + size.w, y: origin.y + (size.h / 2 + 1))
        }

        var northwest: Point {
            return origin
        }

        var southwest: Point {
            return (x: origin.x, y: origin.y + size.h)
        }

        var northeast: Point {
            return (x: origin.x + size.w, y: origin.y)
        }

        var southeast: Point {
            return (x: origin.x + size.w, y: origin.y + size.h)
        }

        var midpoint: Point {
            return (x: origin.x + (size.w / 2 + 1), y: origin.y + (size.h / 2 + 1))
        }

        var subdivisions: [Box] {
            guard size.w > 2 && size.h > 2 else {
                return []
            }
            let midp = midpoint
            let newSize = (w: midp.x - origin.x, h: midp.y - origin.y)
            return [
                Box(origin: origin, size: newSize),
                Box(origin: (origin.x + newSize.w, origin.y), size: newSize),
                Box(origin: (origin.x, origin.y + newSize.h), size: newSize),
                Box(origin: (origin.x + newSize.w, origin.y + newSize.h), size: newSize)
            ]
        }

        func breadthFirstSearch(visit: (Box) -> (Void)) {
            var queue = [self]
            while queue.count > 0 {
                let box = queue.removeFirst()
                visit(box)
                queue.append(contentsOf: box.subdivisions)
            }
        }
    }
    
    let name = "Diamond-Square"

    class var textureSize: MTLSize {
        // Needs to 2n + 1 on each side.
        return MTLSize(width: 513, height: 513, depth: 1)
    }

    let texture: MTLTexture
    let textureSemaphore = DispatchSemaphore(value: 1)

    init?(device: MTLDevice) {
        let size = DiamondSquareAlgorithm.textureSize
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: size.width, height: size.height, mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite]
        desc.resourceOptions = .storageModeShared
        guard let tex = device.makeTexture(descriptor: desc) else {
            print("Couldn't create texture for Diamond-Squares algorithm.")
            return nil
        }
        texture = tex
    }

    func render() {
        let size = DiamondSquareAlgorithm.textureSize

        func ptToIndex(_ pt: Box.Point) -> Int {
            return pt.y * size.width + pt.x
        }

        var heightMap = [Float](repeating: 0, count: size.width * size.height)

        // 0. Set the corners to initial values if they haven't been set yet.
        let box = Box(origin: (0, 0), size: (size.width, size.height))
        for p in box.corners {
            let idx = ptToIndex(p)
            if heightMap[idx] == 0.0 {
                heightMap[idx] = Float.random(in: 0...1)
            }
        }

        box.breadthFirstSearch { (box: Box) in
            let halfSize = (w: box.size.w / 2 + 1, h: box.size.h / 2 + 1)

            // 1. Diamond. Average the corners, add a random value. Set the midpoint.
            let midpoint = box.midpoint
            let cornerAverage = Float.random(in: 0...1) + 0.25 * box.corners.reduce(0.0) { (acc, pt) -> Float in
                let index = ptToIndex(pt)
                let value = heightMap[index]
                return acc + value
            }
            let midptIdx = ptToIndex(midpoint)
            heightMap[midptIdx] = cornerAverage

            // 2. Square. Find the midpoints of the sides of this box. These four points are the origins of the new subdivided boxes.
            for p in box.sideMidpoints {
                // Find our diamond's corners, wrapping around the grid if needed.
                let diamondCorners = [
                    (x: p.x, y: p.y - halfSize.h), // North
                    (x: p.x - halfSize.w, y: p.y), // West
                    (x: p.x, y: (p.y + halfSize.h) % size.height), // South
                    (x: (p.x + halfSize.w) % size.width, y: p.y), // West
                ].map { (p: Box.Point) -> Box.Point in
                    if p.x < 0 {
                        return (x: p.x + size.width, y: p.y)
                    } else if p.y < 0 {
                        return (x: p.x, y: p.y + size.height)
                    } else {
                        return p
                    }
                }

                let idx = ptToIndex(p)
                let value = Float.random(in: 0...1) + 0.25 * diamondCorners.reduce(0) { (acc, pt) -> Float in
                    let idx = ptToIndex(pt)
                    let value = heightMap[idx]
                    return acc + value
                }
                heightMap[idx] = value
            }
        }

        let region = MTLRegion(origin: MTLOrigin(), size: size)
        texture.replace(region: region, mipmapLevel: 0, withBytes: heightMap, bytesPerRow: MemoryLayout<Float>.stride * size.width)
    }

    // MARK: Algorithm

    var outTexture: MTLTexture {
        return texture
    }

    func encode(in encoder: MTLComputeCommandEncoder) {
    }

    func updateUniforms() {
    }
}

extension DiamondSquareAlgorithm.Box: Equatable {
    public static func == (lhs: DiamondSquareAlgorithm.Box, rhs: DiamondSquareAlgorithm.Box) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}

/// Implementation of the Circles algorithm.
//class CirclesAlgorithm: Algorithm {
//    static let name = "Circles"
//}
