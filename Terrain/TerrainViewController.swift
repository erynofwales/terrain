//
//  TerrainViewController.swift
//  Terrain
//
//  Created by Eryn Wells on 11/3/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Cocoa
import MetalKit

class TerrainViewController: NSViewController {

    let renderer = Renderer()

    private var metalView: MTKView! {
        return view as? MTKView
    }

    override func loadView() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
        let v = MTKView(frame: CGRect(), device: device)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(greaterThanOrEqualToConstant: 640).isActive = true
        v.heightAnchor.constraint(greaterThanOrEqualToConstant: 480).isActive = true
        v.delegate = renderer
        view = v
    }
    
}
