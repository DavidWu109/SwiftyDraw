//
//  LayeredImageView.swift
//  SwiftyDrawExample
//
//  Created by David on 2024/8/28.
//  Copyright © 2024 Walzy. All rights reserved.
//

import Foundation
import UIKit
import SnapKit

class LayeredImageView: UIView {
    private var imageLayers: [CALayer] = []
    private var selectedLayer: CALayer?
    private var initialTouchPoint: CGPoint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }
    
    func setImages(_ images: [UIImage]) {
        // Remove existing layers
        imageLayers.forEach { $0.removeFromSuperlayer() }
        imageLayers.removeAll()
        
        // Create new layers for each image
        for (index, image) in images.enumerated() {
            let layer = CALayer()
            layer.contents = image.cgImage
            layer.contentsGravity = .resizeAspectFill
            layer.masksToBounds = true
            layer.frame = bounds
            
            self.layer.addSublayer(layer)
            imageLayers.append(layer)
            
            // Set z-index to ensure proper stacking order
            layer.zPosition = CGFloat(index)
        }
        
        setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update frame for all image layers
        imageLayers.forEach { layer in
            layer.frame = bounds
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Find the topmost layer at the touch point
        if let hitLayer = layer.presentation()?.hitTest(location) {
            selectedLayer = imageLayers.first { $0 == hitLayer }
            initialTouchPoint = location
            
            // Bring the selected layer to front
            if let selectedLayer = selectedLayer {
                selectedLayer.zPosition = CGFloat(imageLayers.count)
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let selectedLayer = selectedLayer,
              let initialTouchPoint = initialTouchPoint else { return }
        
        let location = touch.location(in: self)
        let translation = CGPoint(x: location.x - initialTouchPoint.x,
                                  y: location.y - initialTouchPoint.y)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        selectedLayer.position = CGPoint(x: selectedLayer.position.x + translation.x,
                                         y: selectedLayer.position.y + translation.y)
        CATransaction.commit()
        
        self.initialTouchPoint = location
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        selectedLayer = nil
        initialTouchPoint = nil
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        selectedLayer = nil
        initialTouchPoint = nil
    }
}
