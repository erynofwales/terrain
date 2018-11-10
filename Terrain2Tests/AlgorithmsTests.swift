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

class DiamondSquareBoxTests: XCTestCase {

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

    func testBFS() {
        let box = Box(origin: (x: 3, y: 4), size: (w: 5, h: 5))
        var expectedBoxes: [Box] = [
            box,
            Box(origin: (x: 3, y: 4), size: (w: 3, h: 3)),
            Box(origin: (x: 6, y: 4), size: (w: 3, h: 3)),
            Box(origin: (x: 3, y: 7), size: (w: 3, h: 3)),
            Box(origin: (x: 6, y: 7), size: (w: 3, h: 3)),

            Box(origin: (x: 3, y: 4), size: (w: 2, h: 2)),
            Box(origin: (x: 5, y: 4), size: (w: 2, h: 2)),
            Box(origin: (x: 3, y: 6), size: (w: 2, h: 2)),
            Box(origin: (x: 5, y: 6), size: (w: 2, h: 2)),

            Box(origin: (x: 6, y: 4), size: (w: 2, h: 2)),
            Box(origin: (x: 8, y: 4), size: (w: 2, h: 2)),
            Box(origin: (x: 6, y: 6), size: (w: 2, h: 2)),
            Box(origin: (x: 8, y: 6), size: (w: 2, h: 2)),

            Box(origin: (x: 3, y: 7), size: (w: 2, h: 2)),
            Box(origin: (x: 5, y: 7), size: (w: 2, h: 2)),
            Box(origin: (x: 3, y: 9), size: (w: 2, h: 2)),
            Box(origin: (x: 5, y: 9), size: (w: 2, h: 2)),

            Box(origin: (x: 6, y: 7), size: (w: 2, h: 2)),
            Box(origin: (x: 8, y: 7), size: (w: 2, h: 2)),
            Box(origin: (x: 6, y: 9), size: (w: 2, h: 2)),
            Box(origin: (x: 8, y: 9), size: (w: 2, h: 2)),
            ].reversed()

        box.breadthFirstSearch { (box: Box) -> (Void) in
            let exBox = expectedBoxes.popLast()
            XCTAssertNotNil(exBox)
            XCTAssertEqual(box, exBox!)
        }
        XCTAssertEqual(expectedBoxes.count, 0)
    }

    // MARK: Sides

    func testNorth() {
        let box = Box(origin: (x: 3, y: 4), size: (w: 5, h: 5))
        let pt = box.north
        XCTAssertEqual(pt.x, 6)
        XCTAssertEqual(pt.y, 4)
    }

    func testWest() {
        let box = Box(origin: (x: 3, y: 4), size: (w: 5, h: 5))
        let pt = box.west
        XCTAssertEqual(pt.x, 3)
        XCTAssertEqual(pt.y, 7)
    }

    func testSouth() {
        let box = Box(origin: (x: 3, y: 4), size: (w: 5, h: 5))
        let pt = box.south
        XCTAssertEqual(pt.x, 6)
        XCTAssertEqual(pt.y, 9)
    }

    func testEast() {
        let box = Box(origin: (x: 3, y: 4), size: (w: 5, h: 5))
        let pt = box.east
        XCTAssertEqual(pt.x, 8)
        XCTAssertEqual(pt.y, 7)
    }

    // MARK: Corners

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
}
