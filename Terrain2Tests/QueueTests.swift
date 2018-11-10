//
//  QueueTests.swift
//  Terrain2Tests
//
//  Created by Eryn Wells on 11/10/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import XCTest
@testable import Terrain2

class QueueTests: XCTestCase {

    func testEnqueue() {
        var queue = Queue<Int>()
        queue.enqueue(item: 1)
        queue.enqueue(item: 2)
        queue.enqueue(item: 3)
        XCTAssertEqual(queue.count, 3)
        XCTAssertEqual(queue.head?.item, 1)
        XCTAssertEqual(queue.head?.next?.item, 2)
        XCTAssertEqual(queue.head?.next?.next?.item, 3)
    }

    func testDequeue() {
        var queue = Queue<Int>()
        queue.enqueue(item: 1)
        queue.enqueue(item: 2)
        queue.enqueue(item: 3)

        XCTAssertEqual(queue.count, 3)
        XCTAssertEqual(queue.head?.item, 1)
        XCTAssertEqual(queue.tail?.item, 3)

        XCTAssertEqual(queue.dequeue(), 1)
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue.head?.item, 2)
        XCTAssertEqual(queue.tail?.item, 3)

        XCTAssertEqual(queue.dequeue(), 2)
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.head?.item, 3)
        XCTAssertEqual(queue.tail?.item, 3)

        XCTAssertEqual(queue.dequeue(), 3)
        XCTAssertEqual(queue.count, 0)
        XCTAssertNil(queue.head)
        XCTAssertNil(queue.tail)
    }

}
