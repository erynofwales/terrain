//
//  GameViewController.swift
//  Terrain2
//
//  Created by Eryn Wells on 11/3/18.
//  Copyright © 2018 Eryn Wells. All rights reserved.
//

import Cocoa
import MetalKit

// Our macOS specific view controller
class GameViewController: NSViewController {

    var renderer: Renderer!
    var mtkView: MTKView!
    var progressIndicator: NSProgressIndicator!

    private var progressObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let mtkView = self.view as? MTKView else {
            print("View attached to GameViewController is not an MTKView")
            return
        }

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }

        mtkView.device = defaultDevice

        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer

        progressIndicator = NSProgressIndicator()
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0.0
        progressIndicator.maxValue = 1.0
        self.view.addSubview(progressIndicator)
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.widthAnchor.constraint(equalToConstant: 200.0).isActive = true
        progressIndicator.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        progressIndicator.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -40.0).isActive = true
        progressIndicator.isHidden = true
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        switch event.charactersIgnoringModifiers {
        case .some(" "):
            if let progress = renderer.scheduleAlgorithmIteration() {
                progressIndicator.isHidden = false
                progressObservation = progress.observe(\.fractionCompleted) { [weak self] (progress: Progress, change: NSKeyValueObservedChange<Double>) in
                    DispatchQueue.main.async {
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.progressIndicator.doubleValue = progress.fractionCompleted
                        if progress.isFinished {
                            // TODO: Delay this.
                            strongSelf.progressIndicator.isHidden = true
                            strongSelf.progressObservation = nil
                        }
                    }
                }
            }
        case .some("n"):
            renderer.drawNormals = !renderer.drawNormals
        case .some("z"):
            renderer.drawLines = !renderer.drawLines
        default:
            print("key down: \(String(describing: event.charactersIgnoringModifiers))")
            super.keyDown(with: event)
        }
    }
}
