//
//  AlgorithmsTests.swift
//  Terrain2Tests
//
//  Created by Eryn Wells on 11/8/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import XCTest
@testable import Terrain2

public typealias Box = DiamondSquareAlgorithm.Box
public typealias Point = DiamondSquareAlgorithm.Box.Point
public typealias Size = DiamondSquareAlgorithm.Box.Size

class DiamondSquareBFSTests: XCTestCase {

}

class DiamondSquareBoxTests: XCTestCase {
    func testNorthwest() {
        let box = Box(origin: (x: 3, y: 4), size: (w: 5, h: 5))
        let pt = box.northwest
        XCTAssertEqual(pt.x, 3)
        XCTAssertEqual(pt.y, 4)
    }

    func testNortheast() {
        let box = Box(origin: (x: 3, y: 4), size: (w: 5, h: 5))
        let pt = box.northeast
        XCTAssertEqual(pt.x, 8)
        XCTAssertEqual(pt.y, 4)
    }

    func testSouthwest() {
        let box = Box(origin: (x: 3, y: 4), size: (w: 5, h: 5))
        let pt = box.southwest
        XCTAssertEqual(pt.x, 3)
        XCTAssertEqual(pt.y, 9)
    }

    func testSoutheast() {
        let box = Box(origin: (x: 3, y: 4), size: (w: 5, h: 5))
        let pt = box.southeast
        XCTAssertEqual(pt.x, 8)
        XCTAssertEqual(pt.y, 9)
    }

    func testMidpoint() {
        let box = Box(origin: (x: 3, y: 4), size: (w: 5, h: 5))
        let midpoint = box.midpoint
        XCTAssertEqual(midpoint.x, 6)
        XCTAssertEqual(midpoint.y, 7)
    }

    func testSubdivision() {
        let box = Box(origin: (x: 3, y: 4), size: (w: 5, h: 5))
        let subdivs = box.subdivisions
        XCTAssertEqual(subdivs.count, 4)
        XCTAssertEqual(subdivs[0], Box(origin: (x: 3, y: 4), size: (w: 3, h: 3)))
        XCTAssertEqual(subdivs[1], Box(origin: (x: 6, y: 4), size: (w: 3, h: 3)))
        XCTAssertEqual(subdivs[2], Box(origin: (x: 3, y: 7), size: (w: 3, h: 3)))
        XCTAssertEqual(subdivs[3], Box(origin: (x: 6, y: 7), size: (w: 3, h: 3)))
    }
}
