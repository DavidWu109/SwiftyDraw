import UIKit

extension ViewController: SwiftyDrawViewDelegate {
    func swiftyDraw(shouldBeginDrawingIn drawingView: SwiftyDrawView, using touch: UITouch) -> Bool { return true }
    func swiftyDraw(didBeginDrawingIn    drawingView: SwiftyDrawView, using touch: UITouch) { updateHistoryButtons() }
    func swiftyDraw(isDrawingIn          drawingView: SwiftyDrawView, using touch: UITouch) {  }
    func swiftyDraw(didFinishDrawingIn   drawingView: SwiftyDrawView, using touch: UITouch) {  }
    func swiftyDraw(didCancelDrawingIn   drawingView: SwiftyDrawView, using touch: UITouch) {  }
}

class ViewController: UIViewController {
    
    var drawView: SwiftyDrawView = {
        let view = SwiftyDrawView()
        view.bounds = CGRect(origin: CGPoint.zero, size: UIScreen.main.bounds.size)
        return view
    }()
    
    var toolBar: UIToolbar = UIToolbar()
    
    var layeredImageView: LayeredImageView = LayeredImageView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        view.addSubview(layeredImageView)
        layeredImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        view.sendSubviewToBack(layeredImageView)
        
        updateHistoryButtons()
        
        drawView.delegate = self
        drawView.brush.width = 7
        
        if #available(iOS 9.1, *) {
            drawView.allowedTouchTypes = [.finger, .pencil]
        }
        
        setupUI()
        setupToolBar()
    }
    
    func setupUI() {
        view.addSubview(drawView)
        drawView.snp.makeConstraints { make in
            make.left.top.right.equalToSuperview()
        }
        
        view.addSubview(toolBar)
        toolBar.snp.makeConstraints { make in
            make.top.equalTo(drawView.snp.bottom)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }
    
    func setupToolBar() {
    
        let colorButton = UIColorWell()
        colorButton.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: 40, height: 40))
        
        toolBar.setItems([
            UIBarButtonItem(customView: colorButton),
            UIBarButtonItem(title: "移动", style: .done, target: self, action: #selector(moveLayer)),
            UIBarButtonItem(title: "图层管理", style: .done, target: self, action: #selector(showLayer)),
            UIBarButtonItem(title: "新增图层", style: .done, target: self, action: #selector(addLayer)),
            UIBarButtonItem(title: "撤销", style: .done, target: self, action: #selector(undo)),
            UIBarButtonItem(title: "重做", style: .done, target: self, action: #selector(redo))
        ], animated: true)
    }
    
    @IBAction func selectedColor(_ button: UIButton) {
        guard let color = button.backgroundColor else { return }
        drawView.brush.color = Color(color)
        deactivateEraser()
    }
    
    @IBAction func undo() {
        drawView.undo()
        updateHistoryButtons()
    }
    
    @IBAction func redo() {
        drawView.redo()
        updateHistoryButtons()
    }
    
    @objc func moveLayer() {
        drawView.setMovingMode()
    }
    
    @IBAction func showLayer() {
        let vc = LayerManagementViewController()
        vc.layers = drawView.pixelLayers.reversed()
        self.present(vc, animated: true)
    }
    
    @IBAction func addLayer() {
//        layeredImageView.setImages(drawView.layer.reversed())
        drawView.addLayer()
    }
    
    func updateHistoryButtons() {
//        undoButton.isEnabled = drawView.canUndo
//        redoButton.isEnabled = drawView.canRedo
    }
    
    @IBAction func toggleEraser() {
        if drawView.brush.blendMode == .normal {
            //Switch to clear
            activateEraser()
        } else {
            //Switch to normal
            deactivateEraser()
        }
    }
    
    @IBAction func clearCanvas() {
        drawView.clear()
        deactivateEraser()
    }
    
    @IBAction func setDrawMode() {
//        switch (drawModeSelector.selectedSegmentIndex) {
//        case 1:
//            drawView.drawMode = .line
//            fillModeButton.isHidden = true
//            break
//        case 2:
//            drawView.drawMode = .ellipse
//            fillModeButton.isHidden = false
//            break
//        case 3:
//            drawView.drawMode = .rect
//            fillModeButton.isHidden = false
//            break
//        default:
//            drawView.drawMode = .draw
//            fillModeButton.isHidden = true
//            break
//        }
    }
    
    @IBAction func toggleStraightLine() {
        drawView.shouldFillPath = !drawView.shouldFillPath
//        if (drawView.shouldFillPath) {
//            fillModeButton.tintColor = .red
//            fillModeButton.setTitle("activate stroke mode", for: .normal)
//        } else {
//            fillModeButton.tintColor = self.view.tintColor
//            fillModeButton.setTitle("activate fill mode", for: .normal)
//        }
    }
        
    @IBAction func changedWidth(_ slider: UISlider) {
        drawView.brush.width = CGFloat(slider.value)
    }
    
    @IBAction func changedOpacity(_ slider: UISlider) {
        drawView.brush.opacity = CGFloat(slider.value)
        deactivateEraser()
    }
    
    func activateEraser() {
        drawView.brush.blendMode = .clear
//        eraserButton.tintColor = .red
//        eraserButton.setTitle("deactivate eraser", for: .normal)
    }
    
    func deactivateEraser() {
        drawView.brush.blendMode = .normal
//        eraserButton.tintColor = self.view.tintColor
//        eraserButton.setTitle("activate eraser", for: .normal)
    }
}

