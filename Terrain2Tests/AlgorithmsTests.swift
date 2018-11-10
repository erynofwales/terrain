//
//  AlgorithmsTests.swift
//  Terrain2Tests
//
//  Created by Eryn Wells on 11/8/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import XCTest
@testable import Terrain2

fileprivate typealias Box = DiamondSquareAlgorithm.Box
fileprivate typealias Point = DiamondSquareAlgorithm.Point
fileprivate typealias Size = DiamondSquareAlgorithm.Size

class DiamondSquareAlgorithmTests: XCTestCase {
    fileprivate let grid = Box(origin: Point(x: 0, y: 0), size: Size(w: 5, h: 5))

    lazy var alg = {
        DiamondSquareAlgorithm.Algorithm(grid: grid)
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
    fileprivate let box = Box(origin: Point(x: 3, y: 4), size: Size(w: 5, h: 5))

    func testMidpoint() {
        let midpoint = box.midpoint
        XCTAssertEqual(midpoint.x, 6)
        XCTAssertEqual(midpoint.y, 7)
    }

    func testSubdivision() {
        let subdivs = box.subdivisions
        XCTAssertEqual(subdivs.count, 4)
        XCTAssertEqual(subdivs[0], Box(origin: Point(x: 3, y: 4), size: Size(w: 3, h: 3)))
        XCTAssertEqual(subdivs[1], Box(origin: Point(x: 6, y: 4), size: Size(w: 3, h: 3)))
        XCTAssertEqual(subdivs[2], Box(origin: Point(x: 3, y: 7), size: Size(w: 3, h: 3)))
        XCTAssertEqual(subdivs[3], Box(origin: Point(x: 6, y: 7), size: Size(w: 3, h: 3)))
    }

    func testBFS() {
        var expectedBoxes: [Box] = [
            box,
            Box(origin: Point(x: 3, y: 4), size: Size(w: 3, h: 3)),
            Box(origin: Point(x: 6, y: 4), size: Size(w: 3, h: 3)),
            Box(origin: Point(x: 3, y: 7), size: Size(w: 3, h: 3)),
            Box(origin: Point(x: 6, y: 7), size: Size(w: 3, h: 3)),

            Box(origin: Point(x: 3, y: 4), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 5, y: 4), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 3, y: 6), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 5, y: 6), size: Size(w: 2, h: 2)),

            Box(origin: Point(x: 6, y: 4), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 8, y: 4), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 6, y: 6), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 8, y: 6), size: Size(w: 2, h: 2)),

            Box(origin: Point(x: 3, y: 7), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 5, y: 7), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 3, y: 9), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 5, y: 9), size: Size(w: 2, h: 2)),

            Box(origin: Point(x: 6, y: 7), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 8, y: 7), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 6, y: 9), size: Size(w: 2, h: 2)),
            Box(origin: Point(x: 8, y: 9), size: Size(w: 2, h: 2)),
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
        let pt = box.north
        XCTAssertEqual(pt.x, 6)
        XCTAssertEqual(pt.y, 4)
    }

    func testWest() {
        let pt = box.west
        XCTAssertEqual(pt.x, 3)
        XCTAssertEqual(pt.y, 7)
    }

    func testSouth() {
        let pt = box.south
        XCTAssertEqual(pt.x, 6)
        XCTAssertEqual(pt.y, 9)
    }

    func testEast() {
        let pt = box.east
        XCTAssertEqual(pt.x, 8)
        XCTAssertEqual(pt.y, 7)
    }

    // MARK: Corners

    func testNorthwest() {
        let pt = box.northwest
        XCTAssertEqual(pt.x, 3)
        XCTAssertEqual(pt.y, 4)
    }

    func testNortheast() {
        let pt = box.northeast
        XCTAssertEqual(pt.x, 8)
        XCTAssertEqual(pt.y, 4)
    }

    func testSouthwest() {
        let pt = box.southwest
        XCTAssertEqual(pt.x, 3)
        XCTAssertEqual(pt.y, 9)
    }

    func testSoutheast() {
        let pt = box.southeast
        XCTAssertEqual(pt.x, 8)
        XCTAssertEqual(pt.y, 9)
    }
}
