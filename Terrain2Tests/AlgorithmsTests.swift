//
//  AlgorithmsTests.swift
//  Terrain2Tests
//
//  Created by Eryn Wells on 11/8/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import XCTest
import Terrain2

class DiamondSquareBoxTests: XCTestCase {
    func testNorthwest() {
        let box = DiamondSquareAlgorithm.Box(origin: DiamondSquareAlgorithm.Box.Point(x: 3, y: 4),
                                             size: DiamondSquareAlgorithm.Box.Size(w: 5, h: 5))
        let pt = box.northwest
        XCTAssertEqual(pt.x, 3)
        XCTAssertEqual(pt.y, 4)
    }

    func testNortheast() {
        let box = DiamondSquareAlgorithm.Box(origin: DiamondSquareAlgorithm.Box.Point(x: 3, y: 4),
                                             size: DiamondSquareAlgorithm.Box.Size(w: 5, h: 5))
        let pt = box.northeast
        XCTAssertEqual(pt.x, 8)
        XCTAssertEqual(pt.y, 4)
    }

    func testSouthwest() {
        let box = DiamondSquareAlgorithm.Box(origin: DiamondSquareAlgorithm.Box.Point(x: 3, y: 4),
                                             size: DiamondSquareAlgorithm.Box.Size(w: 5, h: 5))
        let pt = box.southwest
        XCTAssertEqual(pt.x, 3)
        XCTAssertEqual(pt.y, 9)
    }

    func testSoutheast() {
        let box = DiamondSquareAlgorithm.Box(origin: DiamondSquareAlgorithm.Box.Point(x: 3, y: 4),
                                             size: DiamondSquareAlgorithm.Box.Size(w: 5, h: 5))
        let pt = box.southeast
        XCTAssertEqual(pt.x, 8)
        XCTAssertEqual(pt.y, 9)
    }

    func testMidpoint() {
        let box = DiamondSquareAlgorithm.Box(origin: DiamondSquareAlgorithm.Box.Point(x: 3, y: 4),
                                             size: DiamondSquareAlgorithm.Box.Size(w: 5, h: 5))
        let midpoint = box.midpoint
        XCTAssertEqual(midpoint.x, 6)
        XCTAssertEqual(midpoint.y, 7)
    }
}
