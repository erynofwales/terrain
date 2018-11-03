//
//  Terrain.swift
//  Terrain
//
//  Created by Eryn Wells on 11/3/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Cocoa

class Terrain: NSObject {
    override init() {
        super.init()
    }

    /// Generate a grid of triangles and place the result in the given buffer.
    /// @param buffer The buffer to copy the results into
    /// @param size The size of the grid. Each square is a pair of triangles.
    func generateVertexes(intoBuffer buffer: MTLBuffer, size: CGSize) {
        let VertexesPerCell = 6

        let float3Stride = MemoryLayout<Float3>.stride
        let (width, height) = (Int(size.width), Int(size.height))
        let expectedCount = VertexesPerCell * width * height
        let expectedLength = float3Stride * expectedCount
        guard buffer.length >= expectedLength else {
            fatalError("Terrain.generateVertexes: buffer must be at least \(expectedLength) bytes to fix grid of size \(size)")
        }

        var vertexes = [Float3]()
        vertexes.reserveCapacity(expectedCount)

        let (cellWidth, cellHeight) = (Float(2.0) / Float(width), Float(2.0) / Float(height))
        for y in 0..<Int(size.height) {
            for x in 0..<Int(size.width) {
                let base = VertexesPerCell * (y * width + x)
                vertexes[base+0] = Float3(x: Float(x) * cellWidth, y: Float(y) * cellHeight, z: 0.0)
                vertexes[base+1] = Float3(x: Float(x) * cellWidth, y: Float(y) * cellHeight + cellHeight, z: 0.0)
                vertexes[base+2] = Float3(x: Float(x) * cellWidth + cellWidth, y: Float(y) * cellHeight, z: 0.0)
                vertexes[base+3] = Float3(x: Float(x) * cellWidth + cellWidth, y: Float(y) * cellHeight, z: 0.0)
                vertexes[base+4] = Float3(x: Float(x) * cellWidth, y: Float(y) * cellHeight + cellHeight, z: 0.0)
                vertexes[base+5] = Float3(x: Float(x) * cellWidth + cellWidth, y: Float(y) * cellHeight + cellHeight, z: 0.0)
            }
        }

        memcpy(buffer.contents(), vertexes, expectedLength)
    }
}
