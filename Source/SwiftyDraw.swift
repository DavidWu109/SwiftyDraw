/*Copyright (c) 2016, Andrew Walz.
 
 Redistribution and use in source and binary forms, with or without modification,are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
 BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */

import UIKit

public class LineLayer: CAShapeLayer {
    
    override init() {
        super.init()
        
        setupUI()
    }
    
    public override init(layer: Any) {
        super.init(layer: layer)
        
        setupUI()
    }
    
    func setupUI() {
        fillColor = UIColor.clear.cgColor
        strokeColor = UIColor.white.cgColor
        lineWidth = 2
        lineJoin = .round
        lineDashPattern = [6, 3]
        shadowOpacity = 1
        shadowRadius = 3
        shadowOffset = CGSize(width: 0, height: 0)
        shadowColor = UIColor.black.withAlphaComponent(0.25).cgColor
        
    }
    
    public override func layoutSublayers() {
        super.layoutSublayers()
        let bezierPath = UIBezierPath(rect: self.bounds)
        path = bezierPath.cgPath
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Public Protocol Declarations

/// SwiftyDrawView Delegate
@objc public protocol SwiftyDrawViewDelegate: AnyObject {
    
    /**
     SwiftyDrawViewDelegate called when a touch gesture should begin on the SwiftyDrawView using given touch type
     
     - Parameter view: SwiftyDrawView where touches occured.
     - Parameter touchType: Type of touch occuring.
     */
    func swiftyDraw(shouldBeginDrawingIn drawingView: SwiftyDrawView, using touch: UITouch) -> Bool
    /**
     SwiftyDrawViewDelegate called when a touch gesture begins on the SwiftyDrawView.
     
     - Parameter view: SwiftyDrawView where touches occured.
     */
    func swiftyDraw(didBeginDrawingIn drawingView: SwiftyDrawView, using touch: UITouch)
    
    /**
     SwiftyDrawViewDelegate called when touch gestures continue on the SwiftyDrawView.
     
     - Parameter view: SwiftyDrawView where touches occured.
     */
    func swiftyDraw(isDrawingIn drawingView: SwiftyDrawView, using touch: UITouch)
    
    /**
     SwiftyDrawViewDelegate called when touches gestures finish on the SwiftyDrawView.
     
     - Parameter view: SwiftyDrawView where touches occured.
     */
    func swiftyDraw(didFinishDrawingIn drawingView: SwiftyDrawView, using touch: UITouch)
    
    /**
     SwiftyDrawViewDelegate called when there is an issue registering touch gestures on the  SwiftyDrawView.
     
     - Parameter view: SwiftyDrawView where touches occured.
     */
    func swiftyDraw(didCancelDrawingIn drawingView: SwiftyDrawView, using touch: UITouch)
    
    func showToast(_ message: String)
}

/// UIView Subclass where touch gestures are translated into Core Graphics drawing
open class SwiftyDrawView: UIView {
    
    public var currentLayer: PixelLayer!
    
    // 这里 pixelLayers 里面的index 和layers的index 刚好相反
    public var currentIndex: Int {
        return (pixelLayers.firstIndex(where: { $0.uuid == currentLayer.uuid }) ?? 0)
    }
    
    private(set) var tempCache: UIImage?
    
    private var tempCacheRevert: UIImage?
    
    var layerTransform: CGAffineTransform = .identity
    
    public var pixelLayers: [PixelLayer] = []
    
    public var caLayers: [String: SwiftyDrawLayer] = [:]
    
    public func getCaLayer(layer: PixelLayer) -> SwiftyDrawLayer? {
        return caLayers[layer.uuid]
    }
    
    public var isCurrentLayerHidden: Bool {
        return getCurrentLayer().isHidden
    }
    public var drawUndoManager: UndoManager?
    
    public var movingMode: Bool = false
    
    /// Current brush being used for drawing
    public var brush: Brush = .default {
        didSet {
            previousBrush = oldValue
        }
    }
    /// Determines whether touch gestures should be registered as drawing strokes on the current canvas
    public var isEnabled = true
    
    /// Determines how touch gestures are treated
    /// draw - freehand draw
    /// line - draws straight lines **WARNING:** experimental feature, may not work properly.
    public enum DrawMode { case draw, line, ellipse, rect }
    public var drawMode:DrawMode = .draw
    
    /// Determines whether paths being draw would be filled or stroked.
    public var shouldFillPath = false
    
    /// Determines whether responde to Apple Pencil interactions, like the Double tap for Apple Pencil 2 to switch tools.
    public var isPencilInteractive : Bool = true {
        didSet {
            if #available(iOS 12.1, *) {
                pencilInteraction.isEnabled  = isPencilInteractive
            }
        }
    }
    /// Public SwiftyDrawView delegate
    public weak var delegate: SwiftyDrawViewDelegate?
    
    public weak var imageView: UIImageView!
    
    public var lineLayer: LineLayer = {
        let lineLayer = LineLayer()
        return lineLayer
    }()
    
    @available(iOS 9.1, *)
    public enum TouchType: Equatable, CaseIterable {
        case finger, pencil
        
        var uiTouchTypes: [UITouch.TouchType] {
            switch self {
            case .finger:
                return [.direct, .indirect]
            case .pencil:
                return [.pencil, .stylus  ]
            }
        }
    }
    /// Determines which touch types are allowed to draw; default: `[.finger, .pencil]` (all)
    @available(iOS 9.1, *)
    public lazy var allowedTouchTypes: [TouchType] = [.finger, .pencil]
    
    public  var drawItems: [DrawItem] = []
    public  var firstPoint: CGPoint = .zero      // created this variable
    public  var currentPoint: CGPoint = .zero     // made public
    private var previousPoint: CGPoint = .zero
    private var previousPreviousPoint: CGPoint = .zero
    
    // For pencil interactions
    @available(iOS 12.1, *)
    lazy private var pencilInteraction = UIPencilInteraction()
    
    /// Save the previous brush for Apple Pencil interaction Switch to previous tool
    private var previousBrush: Brush = .default
    
    public enum ShapeType { case rectangle, roundedRectangle, ellipse }
    
    public struct DrawItem {
        public var path: CGMutablePath
        public var brush: Brush
        public var isFillPath: Bool
        
        public init(path: CGMutablePath, brush: Brush, isFillPath: Bool) {
            self.path = path
            self.brush = brush
            self.isFillPath = isFillPath
        }
    }
    
    /// Public init(frame:) implementation
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        // receive pencil interaction if supported
        if #available(iOS 12.1, *) {
            pencilInteraction.delegate = self
            self.addInteraction(pencilInteraction)
        }
                
        addLayer()
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
//        if !movingMode {
//            layer.sublayers?.forEach({
//                if $0.frame != self.bounds {
//                    $0.frame = self.bounds
//                }
//            })
//        } else {
//            
//        }
        
    }
    
    public func getSnapShot() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { context in
            layer.render(in: context.cgContext)
        }
    }
    
    func setMovingMode() {
        movingMode = !movingMode
    }
    
    /// Public init(coder:) implementation
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.backgroundColor = .clear
        //Receive pencil interaction if supported
        if #available(iOS 12.1, *) {
            pencilInteraction.delegate = self
            self.addInteraction(pencilInteraction)
        }
    }
    
    /// Overriding draw(rect:) to stroke paths
    private func drawLastItem(shouldSave: Bool) {
        
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let date = Date()
        let image = renderer.image { context in
            currentLayer.image.draw(in: bounds)
            if let lastItem = drawItems.last {
                _drawItem(lastItem, in: context)
            }
        }
        
        print("刷新UI \(Date().timeIntervalSince(date))")
    
        tempCache = image
        
        // 这个理论上是同一个
//        getCaLayer(layer: currentLayer)?.contents = tempCache?.cgImage
        
        getCurrentLayer().contents = tempCache?.cgImage
        
        layer.display()
        
        print("刷新UI drawLastItem")
        
    }
    
    func saveImageToLayer(pixelLayer: PixelLayer, image: UIImage, isRedo: Bool = false) {
        var cacheImage = pixelLayer.image
        pixelLayer.image = image
        getCaLayer(layer: pixelLayer)?.contents = image.cgImage

        drawUndoManager?.registerUndo(withTarget:self, handler: { [weak self] _ in
            guard let self = self else { return }
//            self.delegate?.showToast("重做涂鸦")
            self.saveImageToLayer(pixelLayer: pixelLayer, image: cacheImage, isRedo: true)
        })
        
    }
    
    public func restore(document: PixelDocument) {
        guard !document.layers.isEmpty else { return }
        self.layer.sublayers?.filter({ $0.isKind(of: SwiftyDrawLayer.self)}).forEach({
            $0.removeFromSuperlayer()
        })
        document.layers.forEach({ (pixelLayer) in
            let calayer = SwiftyDrawLayer()
            calayer.isHidden = !pixelLayer.isVisible
            calayer.frame = pixelLayer.frame
            calayer.contents = pixelLayer.image.cgImage
            self.pixelLayers.append(pixelLayer)
            
            self.currentLayer = pixelLayer
            
            self.layer.addSublayer(calayer)
            self.caLayers[pixelLayer.uuid] = calayer
            
        })
        self.pixelLayers = document.layers
        
        setNeedsDisplay()
        
    }
    
    func getCurrentLayer() -> CALayer {
        return caLayers[currentLayer.uuid]!
    }
    
    private func drawItem(_ item: DrawItem, in context: CGContext) {
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(item.brush.width)
        context.setBlendMode(item.brush.blendMode.cgBlendMode)
        context.setAlpha(item.brush.opacity)
        if (item.isFillPath)
        {
            context.setFillColor(item.brush.color.uiColor.cgColor)
            context.addPath(item.path)
            context.fillPath()
        }
        else {
            context.beginPath()
            context.setStrokeColor(item.brush.color.uiColor.cgColor)
            context.addPath(item.path)
            context.strokePath()
        }
    }
    
    private func _drawItem(_ item: DrawItem, in rendererContext: UIGraphicsImageRendererContext) {
        let context = rendererContext.cgContext
        
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(item.brush.width)
        context.setBlendMode(item.brush.blendMode.cgBlendMode)
        
        // 注意：UIGraphicsImageRendererContext 不直接支持设置 alpha
        // 我们需要在颜色中设置 alpha 值
        let color = item.brush.color.uiColor.withAlphaComponent(item.brush.opacity)
        
        if item.isFillPath {
            context.setFillColor(color.cgColor)
            context.addPath(item.path)
            context.fillPath()
        } else {
            context.beginPath()
            context.setStrokeColor(color.cgColor)
            context.addPath(item.path)
            context.strokePath()
        }
    }
    
    // MARK: 图层管理
    public func setLayer(index: Int) {
        let cachedIndex = currentIndex
        currentLayer = pixelLayers[index]
        
        drawUndoManager?.registerUndo(withTarget: self, handler: { [weak self] _ in
            guard let self = self else { return }
            self.setLayer(index: cachedIndex)
//            self.delegate?.showToast("撤销移动图层")
        })
        
    }
    
    public func deleteLayer(index: Int) {
        guard pixelLayers.count > 1 else {
            delegate?.showToast("Cannot delete any more layers")
            return
        }
        let delLayer = pixelLayers.remove(at: index)
        getCaLayer(layer: delLayer)?.removeFromSuperlayer()
        
        drawUndoManager?.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.restoreLayer(deLayer: delLayer, index: index)
        })
    }
    
    public func restoreLayer(deLayer: PixelLayer, index: Int) {
        pixelLayers.insert(deLayer, at: index)
        if let deCalayer = getCaLayer(layer: deLayer) {
            
            let targetIndex = (layer.sublayers?.count ?? 0) - index
            layer.sublayers?.insert(deCalayer, at: targetIndex)
        }
        
        drawUndoManager?.registerUndo(withTarget: self, handler: { [weak self] _ in
            guard let self = self else { return }
            self.deleteLayer(index: index)
//            self.delegate?.showToast("撤销删除图层")
        })
    }
    
    public func hideLayer(index: Int) {
        let targetLayer = pixelLayers[index]
        targetLayer.isVisible = false
        
        getCaLayer(layer: targetLayer)?.isHidden = true
        
        drawUndoManager?.registerUndo(withTarget: self, handler: { [weak self] _ in
            guard let self = self else { return }
            self.showLayer(index: index)
//            self.delegate?.showToast("撤销隐藏图层")
        })
    }
    
    public func moveLayer(sourceIndex: Int, destinationIndex: Int) {
        
        guard sourceIndex != destinationIndex else { return }
            
            // 假设我们有一个名为 layers 的数组
        guard sourceIndex >= 0, sourceIndex < pixelLayers.count else { return }
        guard destinationIndex >= 0, destinationIndex < pixelLayers.count else { return }
        
        let pixelLayer = pixelLayers.remove(at: sourceIndex)
        pixelLayers.insert(pixelLayer, at: destinationIndex)
        
        if let caLayer = layer.sublayers?.remove(at: sourceIndex) {
            layer.sublayers?.insert(caLayer, at: destinationIndex)
        }
        
        drawUndoManager?.registerUndo(withTarget: self, handler: { [weak self] _ in
            guard let self = self else { return }
            self.moveLayer(sourceIndex: destinationIndex, destinationIndex: sourceIndex)
//            self.delegate?.showToast("撤销移动图层")
        })
    }
    
    public func showLayer(index: Int) {
        let targetLayer = pixelLayers[index]
        targetLayer.isVisible = true
        
        getCaLayer(layer: targetLayer)?.isHidden = false
        
        drawUndoManager?.registerUndo(withTarget: self, handler: { [weak self] _ in
            guard let self = self else { return }
            self.hideLayer(index: index)
//            self.delegate?.showToast("撤销显示图层")
        })
    }
    
    public func addLayer(image: UIImage = UIImage())  {
        let newLayer = PixelLayer(image: image, frame: self.bounds)
        let calayer = SwiftyDrawLayer()
        calayer.frame = newLayer.frame
        calayer.contents = image.cgImage
                
        if pixelLayers.count == 0 {
            pixelLayers.append(newLayer)
            layer.addSublayer(calayer)

        } else {
            pixelLayers.insert(newLayer, at: currentIndex + 1)
            layer.insertSublayer(calayer, at: UInt32(currentIndex + 1))
        }
        
        var lastCurrentLayer = currentLayer
        currentLayer = newLayer
        
        caLayers[newLayer.uuid] = calayer
        
        setNeedsDisplay()
        
        drawUndoManager?.registerUndo(withTarget: self, handler: { _ in
            if let index = self.pixelLayers.firstIndex(where: { $0.uuid == newLayer.uuid}) {
                self.deleteLayer(index: index)
//                self.delegate?.showToast("撤销添加图层")
            }
        })
    }
    
    public func setImage(image: UIImage, frame: CGRect) {
        
        
        addLayer(image: image)
        
        delegate?.swiftyDraw(didFinishDrawingIn: self, using: UITouch())
    }
    
    var firstPointHandler: (() -> Void)?
    
    var firstPointDate: Date?
    
    
    /// touchesBegan implementation to capture strokes
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
                
        print("touchesBegan")
        
        guard isEnabled, let touch = touches.first else { return }
        if #available(iOS 9.1, *) {
            guard allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }
        }
        
        guard !getCurrentLayer().isHidden else {
            return
        }
        
        if movingMode {
            super.touchesBegan(touches, with: event)
        } else {
            tempCacheRevert = currentLayer.image
            
            guard delegate?.swiftyDraw(shouldBeginDrawingIn: self, using: touch) ?? true else { return }
            delegate?.swiftyDraw(didBeginDrawingIn: self, using: touch)
            
            setTouchPoints(touch, view: self)
            firstPoint = touch.location(in: self)
            
            let newLine = DrawItem(path: CGMutablePath(),
                                   brush: Brush(color: brush.color.uiColor, width: brush.width, opacity: brush.opacity, blendMode: brush.blendMode), isFillPath: drawMode != .draw && drawMode != .line ? shouldFillPath : false)
            drawItems.append(newLine)
            
            // 创建第一个点
            let newPath = createNewPath()
            if let currentPath = drawItems.last {
                currentPath.path.addPath(newPath)
                firstPointHandler = { [weak self] in
                    guard let self = self else { return }
                    guard !self.drawItems.isEmpty else { return }
                    let item = self.drawItems.removeLast()
                    self.addLine(item, shouldSave: true)
                }
                firstPointDate = Date()
            }
            
        }
    }
    
    /// touchesMoves implementation to capture strokes
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        
        
        print("touchesMoved \(touches.count)")
        
        guard isEnabled, touches.count == 1, let touch = touches.first else { return }
        if #available(iOS 9.1, *) {
            guard allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }
        }
        
        guard !getCurrentLayer().isHidden else {
            delegate?.showToast("Current Layer is hidden")
            return
        }
        
        firstPointDate = nil
        
        if movingMode {
            super.touchesMoved(touches, with: event)
        } else {
            delegate?.swiftyDraw(isDrawingIn: self, using: touch)
            
            updateTouchPoints(for: touch, in: self)
            
            switch (drawMode) {
            case .line:
                drawItems.removeLast()
                setNeedsDisplay()
                let newLine = DrawItem(path: CGMutablePath(),
                                   brush: Brush(color: brush.color.uiColor, width: brush.width, opacity: brush.opacity, blendMode: brush.blendMode), isFillPath: false)
                newLine.path.addPath(createNewStraightPath())
                addLine(newLine, shouldSave: false)
                break
            case .draw:
                let newPath = createNewPath()
                if let currentPath = drawItems.last {
                    currentPath.path.addPath(newPath)
                    let item = drawItems.removeLast()
                    addLine(item, shouldSave: true)
                }
                break
            case .ellipse:
                drawItems.removeLast()
                setNeedsDisplay()
                let newLine = DrawItem(path: CGMutablePath(),
                                   brush: Brush(color: brush.color.uiColor, width: brush.width, opacity: brush.opacity, blendMode: brush.blendMode), isFillPath: shouldFillPath)
                newLine.path.addPath(createNewShape(type: .ellipse))
                addLine(newLine, shouldSave: false)
                break
            case .rect:
                drawItems.removeLast()
                setNeedsDisplay()
                let newLine = DrawItem(path: CGMutablePath(),
                                   brush: Brush(color: brush.color.uiColor, width: brush.width, opacity: brush.opacity, blendMode: brush.blendMode), isFillPath: shouldFillPath)
                newLine.path.addPath(createNewShape(type: .rectangle))
                addLine(newLine, shouldSave: false)
                break
            }
        }
    }
        
    /// touchedEnded implementation to capture strokes
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        
        
        print("touchesEnded")
        
        guard isEnabled, touches.count == 1, let touch = touches.first else { return }
        
        guard !getCurrentLayer().isHidden else {
            return
        }
        
        if movingMode {
            super.touchesEnded(touches, with: event)
        } else {
            if firstPointDate != nil {
                self.firstPointHandler?()
            }
                        
            drawItems.removeAll()
            
            let cachedImage = self.currentLayer.image
            let cachedLayer = self.currentLayer!
            
            self.currentLayer.image = tempCache ?? UIImage()
            tempCache = nil
            
            drawUndoManager?.registerUndo(withTarget:self, handler: { [weak self] _ in
                guard let self = self else { return }
//                self.delegate?.showToast("撤销移动图层")
                self.saveImageToLayer(pixelLayer: cachedLayer, image: cachedImage, isRedo: true)
            })
            
            delegate?.swiftyDraw(didFinishDrawingIn: self, using: touch)
        }
    }
    
    /// touchedCancelled implementation
    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        
        print("touchesCancelled")
        
        self.firstPointHandler = nil
        
        guard isEnabled, touches.count == 1, let touch = touches.first else { return }
        
        guard !getCurrentLayer().isHidden else {
            return
        }
        
        if movingMode {
            super.touchesCancelled(touches, with: event)
        } else {
            self.getCurrentLayer().contents = (tempCacheRevert ?? UIImage()).cgImage
            tempCache = nil
            tempCacheRevert = nil
            
            delegate?.swiftyDraw(didCancelDrawingIn: self, using: touch)
        }
    }
    
    
    func addLine(_ newLine: DrawItem, shouldSave: Bool) {
        drawItems.append(newLine)
        drawLastItem(shouldSave: shouldSave)
    }
    
    /// Determines whether a last change can be undone
    public var canUndo: Bool {
        return drawUndoManager?.canUndo ?? false
    }
    
    /// Determines whether an undone change can be redone
    public var canRedo: Bool {
        return drawUndoManager?.canRedo ?? false
    }
    
    /// Undo the last change
    public func undo() {
        guard canUndo else { return }
        drawUndoManager?.undo()
    }
    
    /// Redo the last change
    public func redo() {
        guard canRedo else { return }
        drawUndoManager?.redo()
    }
    
    /// Clear all stroked lines on canvas
    public func clear() {
        drawItems = []
        setNeedsDisplay()
        layer.sublayers?.forEach({
            $0.removeFromSuperlayer()
        })
        
        pixelLayers = []
        addLayer()
        drawUndoManager = UndoManager()
    }
    
    /********************************** Private Functions **********************************/
    
    private func setTouchPoints(_ touch: UITouch,view: UIView) {
        previousPoint = touch.previousLocation(in: view)
        previousPreviousPoint = touch.previousLocation(in: view)
        currentPoint = touch.location(in: view)
    }
    
    private func updateTouchPoints(for touch: UITouch,in view: UIView) {
        previousPreviousPoint = previousPoint
        previousPoint = touch.previousLocation(in: view)
        currentPoint = touch.location(in: view)
    }
    
    private func createNewPath() -> CGMutablePath {
        let midPoints = getMidPoints()
        let subPath = createSubPath(midPoints.0, mid2: midPoints.1)
        let newPath = addSubPathToPath(subPath)
        return newPath
    }
    
    private func createNewStraightPath() -> CGMutablePath {
        let pt1 : CGPoint = firstPoint
        let pt2 : CGPoint = currentPoint
        let subPath = createStraightSubPath(pt1, mid2: pt2)
        let newPath = addSubPathToPath(subPath)
        return newPath
    }
    
    private func createNewShape(type :ShapeType, corner:CGPoint = CGPoint(x: 1.0, y: 1.0)) -> CGMutablePath {
        let pt1 : CGPoint = firstPoint
        let pt2 : CGPoint = currentPoint
        let width = abs(pt1.x - pt2.x)
        let height = abs(pt1.y - pt2.y)
        let newPath = CGMutablePath()
        if width > 0, height > 0 {
            let bounds = CGRect(x: min(pt1.x, pt2.x), y: min(pt1.y, pt2.y), width: width, height: height)
            switch (type) {
            case .ellipse:
                newPath.addEllipse(in: bounds)
                break
            case .rectangle:
                newPath.addRect(bounds)
                break
            case .roundedRectangle:
                newPath.addRoundedRect(in: bounds, cornerWidth: corner.x, cornerHeight: corner.y)
            }
        }
        return addSubPathToPath(newPath)
    }
    
    private func calculateMidPoint(_ p1 : CGPoint, p2 : CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) * 0.5, y: (p1.y + p2.y) * 0.5);
    }
    
    private func getMidPoints() -> (CGPoint,  CGPoint) {
        let mid1 : CGPoint = calculateMidPoint(previousPoint, p2: previousPreviousPoint)
        let mid2 : CGPoint = calculateMidPoint(currentPoint, p2: previousPoint)
        return (mid1, mid2)
    }
    
    private func createSubPath(_ mid1: CGPoint, mid2: CGPoint) -> CGMutablePath {
        let subpath : CGMutablePath = CGMutablePath()
        subpath.move(to: CGPoint(x: mid1.x, y: mid1.y))
        subpath.addQuadCurve(to: CGPoint(x: mid2.x, y: mid2.y), control: CGPoint(x: previousPoint.x, y: previousPoint.y))
        return subpath
    }
    
    private func createStraightSubPath(_ mid1: CGPoint, mid2: CGPoint) -> CGMutablePath {
        let subpath : CGMutablePath = CGMutablePath()
        subpath.move(to: mid1)
        subpath.addLine(to: mid2)
        return subpath
    }
    
    private func addSubPathToPath(_ subpath: CGMutablePath) -> CGMutablePath {
        let bounds : CGRect = subpath.boundingBox
        let drawBox : CGRect = bounds.insetBy(dx: -2.0 * brush.width, dy: -2.0 * brush.width)
        self.setNeedsDisplay(drawBox)
        return subpath
    }
}

// MARK: - Extensions

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

@available(iOS 12.1, *)
extension SwiftyDrawView : UIPencilInteractionDelegate{
    public func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        let preference = UIPencilInteraction.preferredTapAction
        if preference == .switchEraser {
            let currentBlend = self.brush.blendMode
            if currentBlend != .clear {
                self.brush.blendMode = .clear
            } else {
                self.brush.blendMode = .normal
            }
        } else if preference == .switchPrevious {
            self.brush = self.previousBrush
        }
    }
}

extension SwiftyDrawView.DrawItem: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let pathData = try container.decode(Data.self, forKey: .path)
        let uiBezierPath = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(pathData) as! UIBezierPath
        path = uiBezierPath.cgPath as! CGMutablePath
    
        brush = try container.decode(Brush.self, forKey: .brush)
        isFillPath = try container.decode(Bool.self, forKey: .isFillPath)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let uiBezierPath = UIBezierPath(cgPath: path)
        var pathData: Data?
        if #available(iOS 11.0, *) {
            pathData = try NSKeyedArchiver.archivedData(withRootObject: uiBezierPath, requiringSecureCoding: false)
        } else {
            pathData = NSKeyedArchiver.archivedData(withRootObject: uiBezierPath)
        }
        try container.encode(pathData!, forKey: .path)
        
        try container.encode(brush, forKey: .brush)
        try container.encode(isFillPath, forKey: .isFillPath)
    }
    
    enum CodingKeys: String, CodingKey {
        case brush
        case path
        case isFillPath
    }
}

extension CALayer {
    // 存储属性来跟踪变换状态
    private struct AssociatedKeys {
        static var translation = "TranslationKey"
        static var scale = "ScaleKey"
        static var rotation = "RotationKey"
    }
    
    var translation: CGPoint {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.translation) as? CGPoint ?? .zero
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.translation, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var scale: CGFloat {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.scale) as? CGFloat ?? 1.0
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.scale, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var rotation: CGFloat {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.rotation) as? CGFloat ?? 0.0
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.rotation, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // 应用平移变换
    func applyTranslation(_ deltaTranslation: CGPoint) {
        translation.x += deltaTranslation.x
        translation.y += deltaTranslation.y
        applyTransforms()
    }
    
    // 应用缩放变换
    func applyScale(_ deltaScale: CGFloat) {
        scale *= deltaScale
        applyTransforms()
    }
    
    // 应用旋转变换
    func applyRotation(_ deltaRotation: CGFloat) {
        rotation += deltaRotation
        applyTransforms()
    }
    
    // 应用所有变换
    private func applyTransforms() {
        var transform = CATransform3DIdentity
        transform = CATransform3DTranslate(transform, translation.x, translation.y, 0)
        transform = CATransform3DRotate(transform, rotation, 0, 0, 1)
        transform = CATransform3DScale(transform, scale, scale, 1)
        self.transform = transform
    }
    
    // 重置所有变换
    func resetTransforms() {
        translation = .zero
        scale = 1.0
        rotation = 0.0
        applyTransforms()
    }
}
