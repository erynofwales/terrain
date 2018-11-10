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
    case badSize
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
    public struct Point {
        let x: Int
        let y: Int

        init() {
            self.init(x: 0, y: 0)
        }

        init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
    }

    public struct Size {
        let w: Int
        let h: Int

        var half: Size {
            return Size(w: w / 2, h: h / 2)
        }
    }

    public struct Box {
        let origin: Point
        let size: Size

        var corners: [Point] {
            return [northwest, southwest, northeast, northwest]
        }

        var sideMidpoints: [Point] {
            return [north, west, south, east]
        }

        var north: Point {
            return Point(x: origin.x + (size.w / 2 + 1), y: origin.y)
        }

        var west: Point {
            return Point(x: origin.x, y: origin.y + (size.h / 2 + 1))
        }

        var south: Point {
            return Point(x: origin.x + (size.w / 2 + 1), y: origin.y + size.h)
        }

        var east: Point {
            return Point(x: origin.x + size.w, y: origin.y + (size.h / 2 + 1))
        }

        var northwest: Point {
            return origin
        }

        var southwest: Point {
            return Point(x: origin.x, y: origin.y + size.h)
        }

        var northeast: Point {
            return Point(x: origin.x + size.w, y: origin.y)
        }

        var southeast: Point {
            return Point(x: origin.x + size.w, y: origin.y + size.h)
        }

        var midpoint: Point {
            return Point(x: origin.x + (size.w / 2 + 1), y: origin.y + (size.h / 2 + 1))
        }

        var subdivisions: [Box] {
            guard size.w > 2 && size.h > 2 else {
                return []
            }
            let midp = midpoint
            let newSize = Size(w: midp.x - origin.x, h: midp.y - origin.y)
            return [
                Box(origin: origin, size: newSize),
                Box(origin: Point(x: origin.x + newSize.w, y: origin.y), size: newSize),
                Box(origin: Point(x: origin.x, y: origin.y + newSize.h), size: newSize),
                Box(origin: Point(x: origin.x + newSize.w, y: origin.y + newSize.h), size: newSize)
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

    struct Algorithm {
        let grid: Box
        private(set) var rng: RandomNumberGenerator

        init(grid: Box, rng: RandomNumberGenerator = SystemRandomNumberGenerator()) {
            // TODO: Assert log2(w) and log2(h) are integral values.
            self.grid = grid
            self.rng = rng
        }

        /// Run the algorithm and return the genreated height map.
        func render() -> [Float] {
            var heightMap = [Float](repeating: 0, count: grid.size.w * grid.size.h)

            // 0. Set the corners to initial values if they haven't been set yet.
            for p in grid.corners {
                let idx = convert(pointToIndex: p)
                heightMap[idx] = Float.random(in: 0...1)
            }

            grid.breadthFirstSearch { (box: Box) in
                // 1. Diamond step. Find the midpoint of the square defined by `box` and set its value.
                let midpoint = box.midpoint
                let cornerValues = box.corners.map { heightMap[self.convert(pointToIndex: $0)] }
                let midpointValue = Float.random(in: 0...1) + self.average(ofPoints: cornerValues)
                heightMap[convert(pointToIndex: midpoint)] = midpointValue

                // 2. Square step. For each of the side midpoints of this box, compute its value.
                for pt in box.sideMidpoints {
                    let corners = diamondCorners(forPoint: pt, diamondSize: box.size)
                    let cornerValues = corners.map { heightMap[self.convert(pointToIndex: $0)] }
                    let ptValue = Float.random(in: 0...1) + self.average(ofPoints: cornerValues)
                    heightMap[convert(pointToIndex: pt)] = ptValue
                }
            }

            return heightMap
        }

        /// Find our diamond's corners, wrapping around the grid if needed.
        func diamondCorners(forPoint pt: Point, diamondSize: Size) -> [Point] {
            let halfSize = diamondSize.half
            let n = Point(x: pt.x, y: pt.y - halfSize.h)
            let w = Point(x: pt.x - halfSize.w, y: pt.y)
            let s = Point(x: pt.x, y: pt.y + halfSize.h)
            let e = Point(x: pt.x + halfSize.w, y: pt.y)
            return [n, w, s, e].map { (p: Point) -> Point in
                if p.x < 0 {
                    return Point(x: p.x + grid.size.w - 1, y: p.y)
                } else if p.x > grid.size.w {
                    return Point(x: p.x - grid.size.w + 1, y: p.y)
                } else if p.y < 0 {
                    return Point(x: p.x, y: p.y + grid.size.h - 1)
                } else if p.y > grid.size.h {
                    return Point(x: p.x, y: p.y - grid.size.h + 1)
                } else {
                    return p
                }
            }
        }

        func average(ofPoints pts: [Float]) -> Float {
            let scale: Float = 1.0 / Float(pts.count)
            return scale * pts.reduce(0) { return $0 + $1 }
        }

        func convert(pointToIndex pt: Point) -> Int {
            return pt.y * grid.size.w + pt.x
        }
    }
    
    let name = "Diamond-Square"

    class var textureSize: MTLSize {
        // Needs to 2n + 1 on each side.
        return MTLSize(width: 513, height: 513, depth: 1)
    }

    var algorithm: Algorithm
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

        algorithm = Algorithm(grid: Box(origin: Point(), size: Size(w: DiamondSquareAlgorithm.textureSize.width, h: DiamondSquareAlgorithm.textureSize.height)))
    }

    func render() {
        let heightMap = algorithm.render()
        let region = MTLRegion(origin: MTLOrigin(), size: DiamondSquareAlgorithm.textureSize)
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

extension DiamondSquareAlgorithm.Point: Equatable {
    public static func == (lhs: DiamondSquareAlgorithm.Point, rhs: DiamondSquareAlgorithm.Point) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}

extension DiamondSquareAlgorithm.Point: CustomStringConvertible {
    public var description: String {
        return "(x: \(x), y: \(y))"
    }
}

extension DiamondSquareAlgorithm.Size: Equatable {
    public static func == (lhs: DiamondSquareAlgorithm.Size, rhs: DiamondSquareAlgorithm.Size) -> Bool {
        return lhs.w == rhs.w && lhs.h == rhs.h
    }
}

extension DiamondSquareAlgorithm.Size: CustomStringConvertible {
    public var description: String {
        return "(w: \(w), h: \(h))"
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
