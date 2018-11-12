//
//  AlgorithmsTests.swift
//  Terrain2Tests
//
//  Created by Eryn Wells on 11/8/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import XCTest
@testable import Terrain2

fileprivate typealias Box = DiamondSquareGenerator.Box
fileprivate typealias Point = DiamondSquareGenerator.Point
fileprivate typealias Size = DiamondSquareGenerator.Size

class DiamondSquareAlgorithmPerformanceTests: XCTestCase {
    func testAlgorithmOn129() {
        let box = Box(origin: Point(x: 0, y: 0), size: Size(w: 129, h: 129))
        let alg = DiamondSquareGenerator.Algorithm(grid: box)
        measure {
            _ = alg.queue_render()
        }
    }
}

class DiamondSquareAlgorithmTests: XCTestCase {
    fileprivate let grid = Box(origin: Point(x: 0, y: 0), size: Size(w: 5, h: 5))

    lazy var alg = {
        DiamondSquareGenerator.Algorithm(grid: grid)
    }()

    func testPointToIndexConversion() {
        let idx = alg.convert(pointToIndex: Point(x: 2, y: 2))
        XCTAssertEqual(idx, 12)
    }

    // MARK: Diamond Corners

    func testDiamondCornersNorth() {
        let corners = alg.diamondCorners(forPoint: Point(x: 2, y: 0), diamondSize: grid.size)
        XCTAssertEqual(corners.count, 4)
        XCTAssertEqual(corners[0], Point(x: 2, y: 2))
        XCTAssertEqual(corners[1], Point(x: 0, y: 0))
        XCTAssertEqual(corners[2], Point(x: 2, y: 2))
        XCTAssertEqual(corners[3], Point(x: 4, y: 0))
    }

    func testDiamondCornersWest() {
        let corners = alg.diamondCorners(forPoint: Point(x: 0, y: 2), diamondSize: grid.size)
        XCTAssertEqual(corners.count, 4)
        XCTAssertEqual(corners[0], Point(x: 0, y: 0))
        XCTAssertEqual(corners[1], Point(x: 2, y: 2))
        XCTAssertEqual(corners[2], Point(x: 0, y: 4))
        XCTAssertEqual(corners[3], Point(x: 2, y: 2))
    }

    func testDiamondCornersSouth() {
        let corners = alg.diamondCorners(forPoint: Point(x: 2, y: 4), diamondSize: grid.size)
        XCTAssertEqual(corners.count, 4)
        XCTAssertEqual(corners[0], Point(x: 2, y: 2))
        XCTAssertEqual(corners[1], Point(x: 0, y: 4))
        XCTAssertEqual(corners[2], Point(x: 2, y: 2))
        XCTAssertEqual(corners[3], Point(x: 4, y: 4))
    }

    func testDiamondCornersEast() {
        let corners = alg.diamondCorners(forPoint: Point(x: 4, y: 2), diamondSize: grid.size)
        XCTAssertEqual(corners.count, 4)
        XCTAssertEqual(corners[0], Point(x: 4, y: 0))
        XCTAssertEqual(corners[1], Point(x: 2, y: 2))
        XCTAssertEqual(corners[2], Point(x: 4, y: 4))
        XCTAssertEqual(corners[3], Point(x: 2, y: 2))
    }
}

class DiamondSquareBoxTests: XCTestCase {
    fileprivate let box = Box(origin: Point(x: 0, y: 0), size: Size(w: 5, h: 5))

    func testMidpoint() {
        let midpoint = box.midpoint
        XCTAssertEqual(midpoint.x, 2)
        XCTAssertEqual(midpoint.y, 2)
    }

    func testSubdivision() {
        let subdivs = box.subdivisions
        XCTAssertEqual(subdivs.count, 4)
        XCTAssertEqual(subdivs[0], Box(origin: Point(x: 0, y: 0), size: Size(w: 3, h: 3)))
        XCTAssertEqual(subdivs[1], Box(origin: Point(x: 2, y: 0), size: Size(w: 3, h: 3)))
        XCTAssertEqual(subdivs[2], Box(origin: Point(x: 0, y: 2), size: Size(w: 3, h: 3)))
        XCTAssertEqual(subdivs[3], Box(origin: Point(x: 2, y: 2), size: Size(w: 3, h: 3)))
    }

    func testBFS() {
        var expectedBoxes: [Box] = [
            box,

            Box(origin: Point(x: 0, y: 0), size: Size(w: 3, h: 3)),
            Box(origin: Point(x: 2, y: 0), size: Size(w: 3, h: 3)),
            Box(origin: Point(x: 0, y: 2), size: Size(w: 3, h: 3)),
            Box(origin: Point(x: 2, y: 2), size: Size(w: 3, h: 3)),

            Box(origin: Point(x: 0, y: 0), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 1, y: 0), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 0, y: 1), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 1, y: 1), size: Size(w: 2, h: 2)),

            Box(origin: Point(x: 2, y: 0), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 3, y: 0), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 2, y: 1), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 3, y: 1), size: Size(w: 2, h: 2)),

            Box(origin: Point(x: 0, y: 2), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 1, y: 2), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 0, y: 3), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 1, y: 3), size: Size(w: 2, h: 2)),

            Box(origin: Point(x: 2, y: 2), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 3, y: 2), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 2, y: 3), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 3, y: 3), size: Size(w: 2, h: 2)),
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
        XCTAssertEqual(box.north, Point(x: 2, y: 0))
    }

    func testWest() {
        XCTAssertEqual(box.west, Point(x: 0, y: 2))
    }

    func testSouth() {
        XCTAssertEqual(box.south, Point(x: 2, y: 4))
    }

    func testEast() {
        XCTAssertEqual(box.east, Point(x: 4, y: 2))
    }

    // MARK: Corners

    func testNorthwest() {
        let pt = box.northwest
        XCTAssertEqual(pt, Point())
    }

    func testNortheast() {
        let pt = box.northeast
        XCTAssertEqual(pt, Point(x: 4, y: 0))
    }

    func testSouthwest() {
        let pt = box.southwest
        XCTAssertEqual(pt, Point(x: 0, y: 4))
    }

    func testSoutheast() {
        let pt = box.southeast
        XCTAssertEqual(pt, Point(x: 4, y: 4))
    }
}
