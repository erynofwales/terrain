//
//  Terrain.swift
//  Terrain
//
//  Created by Eryn Wells on 11/3/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Cocoa

class Terrain: NSObject {
    static let vertexesPerCell = 6

    var buffer: MTLBuffer?

    override init() {
        super.init()
    }

    func vertexCount(forGridSize size: CGSize) -> Int {
        let (width, height) = (Int(size.width), Int(size.height))
        let count = Terrain.vertexesPerCell * width * height
        return count
    }

    func minimumBufferSize(forGridSize size: CGSize) -> Int {
        let float3Stride = MemoryLayout<Float3>.stride
        let count = vertexCount(forGridSize: size)
        let minimumLength = float3Stride * count
        return minimumLength
    }

    /// Generate a grid of triangles and place the result in the given buffer.
    /// @param buffer The buffer to copy the results into
    /// @param size The size of the grid. Each square is a pair of triangles.
    func generateVertexes(intoBuffer buffer: MTLBuffer, size: CGSize) {
        let expectedLength = minimumBufferSize(forGridSize: size)
        guard buffer.length >= expectedLength else {
            fatalError("Terrain.generateVertexes: buffer must be at least \(expectedLength) bytes to fix grid of size \(size)")
        }

        var vertexes = [Float3]()
        vertexes.reserveCapacity(vertexCount(forGridSize: size))

        let (cellWidth, cellHeight) = (Float(2.0) / Float(size.width), Float(2.0) / Float(size.height))
        for y in 0..<Int(size.height) {
            for x in 0..<Int(size.width) {
                vertexes.append(Float3(x: -1 + Float(x) * cellWidth,
                                       y: -1 + Float(y) * cellHeight,
                                       z: 0.0))
                vertexes.append(Float3(x: -1 + Float(x) * cellWidth,
                                       y: -1 + Float(y) * cellHeight + cellHeight,
                                       z: 0.0))
                vertexes.append(Float3(x: -1 + Float(x) * cellWidth + cellWidth,
                                       y: -1 + Float(y) * cellHeight,
                                       z: 0.0))
                vertexes.append(Float3(x: -1 + Float(x) * cellWidth + cellWidth,
                                       y: -1 + Float(y) * cellHeight,
                                       z: 0.0))
                vertexes.append(Float3(x: -1 + Float(x) * cellWidth,
                                       y: -1 + Float(y) * cellHeight + cellHeight,
                                       z: 0.0))
                vertexes.append(Float3(x: -1 + Float(x) * cellWidth + cellWidth,
                                       y: -1 + Float(y) * cellHeight + cellHeight,
                                       z: 0.0))
            }
        }

        buffer.label = "Terrain Vertex Data"
        self.buffer = buffer
        memcpy(buffer.contents(), vertexes, expectedLength)
    }
}
