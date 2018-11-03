//
//  Math.swift
//  Metaballs
//
//  Created by Eryn Wells on 9/22/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Cocoa
import Foundation
import simd

public typealias Float2 = packed_float2
public typealias Float3 = float3
public typealias Float4 = float4
public typealias Matrix2x2 = float2x2
public typealias Matrix3x3 = float3x3
public typealias Matrix4x4 = float4x4

extension Float2 {
    var CGPoint: CGPoint {
        return CoreGraphics.CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}

extension Float2: CustomStringConvertible {
    public var description: String {
        return "(\(x), \(y))"
    }
}

extension Float3 {
    func dot(other: Float3) -> Float3 {
        return Float3(x * other.x, y * other.y, z * other.z)
    }
}

extension Float4 {
    public init(r: Float, g: Float, b: Float, a: Float) {
        self.init(r, g, b, a)
    }

    public init(color: NSColor) {
        if let convertedColor = color.usingColorSpace(NSColorSpace.deviceRGB) {
            self.init(Float(convertedColor.redComponent), Float(convertedColor.greenComponent), Float(convertedColor.blueComponent), Float(convertedColor.alphaComponent))
        } else {
            self.init()
        }
    }
}

extension Matrix3x3 {
    static func rotation(angle theta: Float) -> Matrix3x3 {
        return self.init(rows: [
            Float3(cos(theta), -sin(theta), 0.0),
            Float3(sin(theta),  cos(theta), 0.0),
            Float3(0, 0, 1),
        ])
    }

    static func translation(dx: Float, dy: Float) -> Matrix3x3 {
        var mat = self.init(1.0)
        mat.columns.2.x = dx
        mat.columns.2.y = dy
        return mat
    }

    static func scale(x: Float, y: Float) -> Matrix3x3 {
        var mat = self.init(1.0)
        mat.columns.0.x = x
        mat.columns.1.y = y
        return mat
    }
}

extension Matrix3x3 {
    static func *(left: Matrix3x3, right: Matrix3x3) -> Matrix3x3 {
        return matrix_multiply(left, right)
    }
}

extension Matrix4x4 {
    /// Create a 4x4 orthographic projection matrix with the provided 6-tuple.
    /// @see https://en.wikipedia.org/wiki/Orthographic_projection
    static func orthographicProjection(top: Float32, left: Float32, bottom: Float32, right: Float32, near: Float32, far: Float32) -> Matrix4x4 {
        let rows = [
            Float4(2.0 / (right - left), 0.0, 0.0, -(right + left) / (right - left)),
            Float4(0.0, 2.0 / (top - bottom), 0.0, -(top + bottom) / (top - bottom)),
            Float4(0.0, 0.0, -2.0 / (far - near), -(far + near) / (far - near)),
            Float4(0.0, 0.0, 0.0, 1.0)
        ]
        return Matrix4x4(rows: rows)
    }

    static func translation(dx: Float, dy: Float, dz: Float) -> Matrix4x4 {
        var mat = self.init(1.0)
        mat.columns.3.x = dx
        mat.columns.3.y = dy
        mat.columns.3.z = dz
        return mat
    }

    static func scale(x: Float, y: Float, z: Float) -> Matrix4x4 {
        var mat = self.init(1.0)
        mat.columns.0.x = x
        mat.columns.1.y = y
        mat.columns.2.z = z
        return mat
    }
}

extension Matrix4x4 {
    static func *(left: Matrix4x4, right: Matrix4x4) -> Matrix4x4 {
        return matrix_multiply(left, right)
    }
}

extension CGSize {
    init(size: Size) {
        self.init(width: CGFloat(size.x), height: CGFloat(size.y))
    }
}
