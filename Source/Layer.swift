//
//  Layer.swift
//  SwiftyDrawExample
//
//  Created by David on 2024/8/28.
//  Copyright © 2024 Walzy. All rights reserved.
//

import Foundation
import UIKit
import SnapKit

open class SwiftyDrawLayer: CALayer {
    
    open override class func defaultAction(forKey event: String) -> CAAction? {
        return nil // 或者返回 NSNull()
    }
    
}

open class PixelDocument: NSObject, NSCoding {
    open var layers: [PixelLayer]
    
    public init(layers: [PixelLayer]) {
        self.layers = layers
        super.init()
    }
    
    open func encode(with coder: NSCoder) {
        coder.encode(layers, forKey: "layers")
    }
    
    public required init?(coder: NSCoder) {
        layers = coder.decodeObject(forKey: "layers") as? [PixelLayer] ?? []
        super.init()
    }
}

open class PixelLayer: NSObject, NSCoding {
    
    open var uuid: String = UUID().uuidString
    open var image: UIImage
    open var frame: CGRect
    open var isVisible: Bool = true
    open var opacity: Float = 1
    
    public init(image: UIImage, frame: CGRect, isVisible: Bool = true) {
        self.image = image
        self.frame = frame
        self.isVisible = isVisible
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(uuid, forKey: "uuid")
        coder.encode(image.pngData(), forKey: "image")
        coder.encode(NSCoder.string(for: frame), forKey: "frame")
        coder.encode(isVisible, forKey: "isVisible")
        coder.encode(opacity, forKey: "opacity")
    }
    
    public required init?(coder: NSCoder) {
        guard let uuid = coder.decodeObject(forKey: "uuid") as? String,
              let imageData = coder.decodeObject(forKey: "image") as? Data,
              let image = UIImage(data: imageData),
              let frameString = coder.decodeObject(forKey: "frame") as? String
        else {
            return nil
        }
        
        self.uuid = uuid
        self.image = image
        self.frame = NSCoder.cgRect(for: frameString)
        self.isVisible = coder.decodeBool(forKey: "isVisible")
        self.opacity = coder.decodeFloat(forKey: "opacity")
        
        super.init()
    }
}

class LayerItem: UIView {
    private let visibilityButton = UIButton()
    private let imageView = UIImageView()
    private let deleteButton = UIButton()
    
    var isVisible: Bool = true {
        didSet {
            updateVisibilityButton()
        }
    }
    
    var onToggleVisibility: (() -> Void)?
    var onDelete: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        // Visibility button setup
        visibilityButton.setImage(UIImage(systemName: "eye.fill"), for: .normal)
        visibilityButton.addTarget(self, action: #selector(toggleVisibility), for: .touchUpInside)
        addSubview(visibilityButton)
        
        // Image view setup
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .black.withAlphaComponent(0.1)
        addSubview(imageView)
        
        // Delete button setup
        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.addTarget(self, action: #selector(deleteLayer), for: .touchUpInside)
        addSubview(deleteButton)
        
        // SnapKit layout
        visibilityButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }
        
        imageView.snp.makeConstraints { make in
            make.leading.equalTo(visibilityButton.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }
        
        deleteButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }
    }
    
    @objc private func toggleVisibility() {
        isVisible.toggle()
        onToggleVisibility?()
    }
    
    @objc private func deleteLayer() {
        onDelete?()
    }
    
    private func updateVisibilityButton() {
        let imageName = isVisible ? "eye.fill" : "eye.slash.fill"
        visibilityButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    func configure(with image: UIImage?) {
        imageView.image = image
        imageView.snp.remakeConstraints { make in
            make.leading.equalTo(visibilityButton.snp.trailing).offset(8)
            make.top.bottom.equalToSuperview()
            make.width.equalTo(44)
            make.height.equalTo(44.0 / max(1, image?.size.width ?? 1) * max(1, image?.size.height ?? 1) )
        }
    }
}

class LayerManagementViewController: UIViewController {
    private let tableView = UITableView()
    private let addButton = UIButton()
    
    var layers: [PixelLayer] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    private func setupView() {
        view.backgroundColor = .white
        
        // Table view setup
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LayerCell")
        view.addSubview(tableView)
        
        // Add button setup
//        addButton.setImage(UIImage(systemName: "plus"), for: .normal)
//        addButton.addTarget(self, action: #selector(addLayer), for: .touchUpInside)
//        view.addSubview(addButton)
        
        // SnapKit layout
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        
    }
    
}

extension LayerManagementViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return layers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LayerCell", for: indexPath)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let layerItem = LayerItem(frame: .zero)
        layerItem.configure(with: layers[indexPath.row].image)
        layerItem.onToggleVisibility = { [weak self] in
            print("Toggle visibility for layer \(indexPath.row)")
        }
        layerItem.onDelete = { [weak self] in
            self?.layers.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
        
        
        cell.contentView.addSubview(layerItem)
        layerItem.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
        
        return cell
    }
}
