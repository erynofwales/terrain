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

    private var metalView: MTKView {
        return view as! MTKView
    }

    override func loadView() {
        let v = MTKView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(greaterThanOrEqualToConstant: 640).isActive = true
        v.heightAnchor.constraint(greaterThanOrEqualToConstant: 480).isActive = true
        view = v
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        metalView.delegate = renderer
        renderer.setupMetal(withView: metalView)
        renderer.prepareToRender()
    }
    
}
