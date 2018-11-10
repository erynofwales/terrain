//
//  Queue.swift
//  Terrain2
//
//  Created by Eryn Wells on 11/10/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Foundation

struct Queue<Element> {
    class Node<Element> {
        var item: Element
        var next: Node?

        init(item i: Element) {
            item = i
        }
    }

    var count: Int = 0
    var head: Node<Element>?
    var tail: Node<Element>?

    mutating func enqueue(item: Element) {
        let newNode = Node(item: item)
        if head == nil {
            head = newNode
            tail = newNode
        } else {
            tail!.next = newNode
            tail = newNode
        }
        count += 1
    }

    mutating func enqueue<S>(items: S) where Element == S.Element, S : Sequence {
        for i in items {
            enqueue(item: i)
        }
    }

    mutating func dequeue() -> Element? {
        guard let oldHead = head else {
            return nil
        }
        head = oldHead.next
        if head == nil {
            tail = nil
        }
        count -= 1
        return oldHead.item
    }
}
