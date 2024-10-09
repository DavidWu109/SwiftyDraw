//
//  Chartlet.swift
//  SwiftyDrawExample
//
//  Created by David on 2024/8/29.
//  Copyright © 2024 Walzy. All rights reserved.
//

import Foundation
import UIKit

class ChartletEditor: UIView {

    struct Result {
        var center: CGPoint
        var size: CGSize
        var angle: CGFloat
    }
    
    typealias ResultHandler = (_ editor: ChartletEditor) -> ()
    
    func convertCoordinate(to view: UIView) -> Result {
        let center = imageView.superview!.convert(imageView.center, to: view)
        return Result(center: center, size: imageView.bounds.size, angle: currentAngle)
    }
    
    private var texture: UIImage = UIImage(named: "image")!
    private var resultHandler: ResultHandler?
    
    var imageView: UIImageView =  UIImageView()
    var container: UIView = UIView()
    
    init(resultHandler: ResultHandler? = nil) {
        super.init(frame: CGRect.zero)
        self.resultHandler = resultHandler
        
        addSubview(container)
        container.frame = CGRect(origin: CGPoint(x: 100, y: 100), size: CGSize(width: 200, height: 300))
        
        container.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        imageView.image = texture
        
        container.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.centerX.equalTo(self.snp.left)
            make.centerY.equalTo(self.snp.top)
            make.size.equalTo(60)
        }
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        container.addGestureRecognizer(pan)
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        container.addGestureRecognizer(pinch)
        
//        let rotate = UIPanGestureRecognizer(target: self, action: #selector(handleRotationGesture(_:)))
//        container.addGestureRecognizer(rotate)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func cancelAction() {
    }
    
    func confirmAction() {
        resultHandler?(self)
    }
    
    // MARK: - Gestures
    func zoomOutAction(_ sender: Any) {
        let scale = currentScale + 0.1
        scaleContent(to: scale)
        currentScale = scale
    }
    func zoomInAction(_ sender: Any) {
        let scale = currentScale - 0.1
        scaleContent(to: scale)
        currentScale = scale
    }
    
    var panOffset = CGPoint.zero
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        
        if gesture.state == .began {
            panOffset = gesture.location(in: container)
        }
        if gesture.state == .changed {
            moveContent(to: location - panOffset + imageView.superview!.center)
        }
    }
    
    private var currentScale: CGFloat = 1
    
    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        let scale = currentScale * gesture.scale * gesture.scale
        if gesture.state == .ended {
            scaleContent(to: scale)
            currentScale = scale
        }
        if gesture.state == .changed {
            scaleContent(to: scale)
        }
    }
    
    private var currentAngle: CGFloat = 0
    
    @objc private func handleRotationGesture(_ gesture: UIPinchGestureRecognizer) {
        let location = gesture.location(in: self)
        let imageCenter = imageView.superview!.convert(imageView.center, to: self)
        currentAngle =  location.angel(to: imageCenter) - CGFloat.pi / 2
        rotateContent(to: currentAngle)
    }
    
    private func moveContent(to location: CGPoint) {
        imageView.snp.updateConstraints {
            $0.centerX.equalTo(self.snp.left).offset(location.x)
            $0.centerY.equalTo(self.snp.top).offset(location.y)
        }
    }
    
    private func scaleContent(to scale: CGFloat) {
        let scale = scale.valueBetween(min: 0.2, max: 5)
        let newSize = texture.size * scale
        imageView.snp.updateConstraints {
            $0.width.equalTo(newSize.width)
            $0.height.equalTo(newSize.height)
        }
    }
    
    private func rotateContent(to angle: CGFloat) {
        container.layer.anchorPoint = imageView.superview!.center / container.bounds.size
        container.transform = CGAffineTransform(rotationAngle: -angle)
    }
    
}
