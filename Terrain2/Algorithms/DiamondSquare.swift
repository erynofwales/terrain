//
//  DiamondSquare.swift
//  Terrain2
//
//  Created by Eryn Wells on 11/23/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Foundation
import Metal
import os

/// Implementation of the Diamond-Squares algorithm.
/// - https://en.wikipedia.org/wiki/Diamond-square_algorithm
public class DiamondSquareGenerator: TerrainGenerator {
    public struct Point {
        var x: Int
        var y: Int

        init() {
            self.init(x: 0, y: 0)
        }

        init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
    }

    public struct Size {
        var w: Int
        var h: Int

        var half: Size {
            return Size(w: w / 2, h: h / 2)
        }
    }

    public struct Box {
        var origin: Point
        var size: Size

        var corners: [Point] {
            return [northwest, southwest, northeast, northwest]
        }

        var sideMidpoints: [Point] {
            return [north, west, south, east]
        }

        var north: Point {
            return Point(x: origin.x + size.w / 2, y: origin.y)
        }

        var west: Point {
            return Point(x: origin.x, y: origin.y + size.h / 2)
        }

        var south: Point {
            return Point(x: origin.x + size.w / 2, y: origin.y + size.h - 1)
        }

        var east: Point {
            return Point(x: origin.x + size.w - 1, y: origin.y + size.h / 2)
        }

        var northwest: Point {
            return origin
        }

        var southwest: Point {
            return Point(x: origin.x, y: origin.y + size.h - 1)
        }

        var northeast: Point {
            return Point(x: origin.x + size.w - 1, y: origin.y)
        }

        var southeast: Point {
            return Point(x: origin.x + size.w - 1, y: origin.y + size.h - 1)
        }

        var midpoint: Point {
            return Point(x: origin.x + (size.w / 2), y: origin.y + (size.h / 2))
        }

        var subdivisions: [Box] {
            guard size.w > 2 && size.h > 2 else {
                return []
            }
            let halfSize = size.half
            let newSize = Size(w: halfSize.w + 1, h: halfSize.h + 1)
            return [
                Box(origin: origin, size: newSize),
                Box(origin: Point(x: origin.x + halfSize.w, y: origin.y), size: newSize),
                Box(origin: Point(x: origin.x, y: origin.y + halfSize.h), size: newSize),
                Box(origin: Point(x: origin.x + halfSize.w, y: origin.y + halfSize.h), size: newSize)
            ]
        }

        func breadthFirstSearch(progress: Progress, visit: (Box) -> (Void)) {
            var queue = Queue<Box>()

            queue.enqueue(item: self)
            progress.totalUnitCount += 1

            while let box = queue.dequeue() {
                visit(box)
                progress.completedUnitCount += 1

                let subdivisions = box.subdivisions
                queue.enqueue(items: subdivisions)
                progress.totalUnitCount += Int64(subdivisions.count)
            }
        }
    }

    struct Algorithm {
        let grid: Box

        var roughness: Float = 1.0 {
            didSet {
                randomRange = -roughness...roughness
            }
        }

        private var randomRange = Float(-1)...Float(1)

        init(grid: Box) {
            // TODO: Assert log2(w) and log2(h) are integral values.
            self.grid = grid
        }

        /// Run the algorithm and return the genreated height map.
        func render(progress: Progress) -> [Float] {
            let renderProgress = Progress(totalUnitCount: 1, parent: progress, pendingUnitCount: 1)

            os_signpost(.begin, log: Log, name: "DiamondSquare.render")

            var boxSize = grid.size
            var spread = randomRange
            var heightMap = [Float](repeating: 0, count: grid.size.w * grid.size.h)

            // 0. Set the corners to initial values if they haven't been set yet.
            for p in grid.corners {
                let idx = convert(pointToIndex: p)
                heightMap[idx] = Float.random(in: spread)
            }
            renderProgress.completedUnitCount += 1

            grid.breadthFirstSearch(progress: renderProgress) { (box: Box) in
                // 1. Diamond step. Find the midpoint of the square defined by `box` and set its value.
                let midpoint = box.midpoint
                let cornerValues = box.corners.map { (pt: Point) -> Float in
                    let idx = self.convert(pointToIndex: pt)
                    return heightMap[idx]
                }
                let midpointValue = Float.random(in: spread) + self.average(ofPoints: cornerValues)
                heightMap[convert(pointToIndex: midpoint)] = midpointValue

                // 2. Square step. For each of the side midpoints of this box, compute its value.
                for pt in box.sideMidpoints {
                    let corners = diamondCorners(forPoint: pt, diamondSize: box.size)
                    let cornerValues = corners.map { (pt: Point) -> Float in
                        let idx = self.convert(pointToIndex: pt)
                        return heightMap[idx]
                    }
                    let ptValue = Float.random(in: spread) + self.average(ofPoints: cornerValues)
                    heightMap[convert(pointToIndex: pt)] = ptValue
                }

                if box.size != boxSize {
                    // Reduce the spread as we recurse down to smaller squares.
                    spread = -(spread.lowerBound * 0.5)...(spread.upperBound * 0.5)
                    boxSize = box.size
                }
            }

            os_signpost(.end, log: Log, name: "DiamondSquare.render")

            return heightMap
        }

        /// Find our diamond's corners, wrapping around the grid if needed.
        func diamondCorners(forPoint pt: Point, diamondSize: Size) -> [Point] {
            let halfSize = diamondSize.half
            var corners = [Point(x: pt.x, y: pt.y - halfSize.h),
                           Point(x: pt.x - halfSize.w, y: pt.y),
                           Point(x: pt.x, y: pt.y + halfSize.h),
                           Point(x: pt.x + halfSize.w, y: pt.y)]
            for i in 0..<corners.count {
                if corners[i].x < 0 {
                    corners[i].x += grid.size.w - 1
                } else if corners[i].x >= grid.size.w {
                    corners[i].x -= grid.size.w - 1
                } else if corners[i].y < 0 {
                    corners[i].y += grid.size.h - 1
                } else if corners[i].y >= grid.size.h {
                    corners[i].y -= grid.size.h - 1
                }
            }
            return corners
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
    let needsGPU: Bool = false

    class var textureSize: MTLSize {
        // Needs to 2n + 1 on each side.
        return MTLSize(width: 129, height: 129, depth: 1)
    }

    var roughness: Float = 1.0 {
        didSet {
            algorithm.roughness = roughness
        }
    }

    var algorithm: Algorithm
    let textures: [MTLTexture]
    private var activeTexture: Int = 0

    init?(device: MTLDevice) {
        let size = DiamondSquareGenerator.textureSize
        do {
            textures = try (0..<2).map { (i: Int) -> MTLTexture in
                let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: size.width, height: size.height, mipmapped: false)
                desc.usage = [.shaderRead, .shaderWrite]
                guard let tex = device.makeTexture(descriptor: desc) else {
                    throw KernelError.textureCreationFailed
                }
                return tex
            }
        } catch {
            print("Couldn't create texture for Diamond-Squares algorithm.")
            return nil
        }

        algorithm = Algorithm(grid: Box(origin: Point(), size: Size(w: DiamondSquareGenerator.textureSize.width, h: DiamondSquareGenerator.textureSize.height)))
    }

    func render(progress: Progress) -> [Float] {
        let algProgress = Progress(totalUnitCount: 2, parent: progress, pendingUnitCount: 2)

        let heights = algorithm.render(progress: algProgress)
        algProgress.completedUnitCount += 1

        // Swap the active texture to the new one. Copy the height map into the new texture.
        let region = MTLRegion(origin: MTLOrigin(), size: DiamondSquareGenerator.textureSize)
        let newActiveTexture = (self.activeTexture + 1) % self.textures.count
        self.textures[newActiveTexture].replace(region: region, mipmapLevel: 0, withBytes: heights, bytesPerRow: MemoryLayout<Float>.stride * DiamondSquareGenerator.textureSize.width)
        self.activeTexture = newActiveTexture
        algProgress.completedUnitCount += 1

        return heights
    }

    // MARK: Algorithm

    var outTexture: MTLTexture {
        return textures[activeTexture]
    }

    func encode(in encoder: MTLComputeCommandEncoder) {
    }
}

extension DiamondSquareGenerator.Point: Equatable {
    public static func == (lhs: DiamondSquareGenerator.Point, rhs: DiamondSquareGenerator.Point) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}

extension DiamondSquareGenerator.Point: CustomStringConvertible {
    public var description: String {
        return "(x: \(x), y: \(y))"
    }
}

extension DiamondSquareGenerator.Size: Equatable {
    public static func == (lhs: DiamondSquareGenerator.Size, rhs: DiamondSquareGenerator.Size) -> Bool {
        return lhs.w == rhs.w && lhs.h == rhs.h
    }
}

extension DiamondSquareGenerator.Size: CustomStringConvertible {
    public var description: String {
        return "(w: \(w), h: \(h))"
    }
}

extension DiamondSquareGenerator.Box: Equatable {
    public static func == (lhs: DiamondSquareGenerator.Box, rhs: DiamondSquareGenerator.Box) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}
