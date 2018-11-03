//
//  Renderer.swift
//  Terrain
//
//  Created by Eryn Wells on 11/3/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Cocoa
import Metal
import MetalKit

class Renderer: NSObject, MTKViewDelegate {

    let device: MTLDevice

    init(device: MTLDevice) {
        self.device = device
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("Size of \(view.debugDescription) will change to \(size)")
    }

    func draw(in view: MTKView) {
        // TODO.
    }

}
