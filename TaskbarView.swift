
import AppKit

class WindowItemView: NSView {
    let info: WindowInfo
    private let onClick: () -> Void
    private let onRightClick: (NSView) -> Void
    
    private let iconView = NSImageView()
    private let ownerLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private var isHovered = false {
        didSet { updateBackground() }
    }

    init(info: WindowInfo, onClick: @escaping () -> Void, onRightClick: @escaping (NSView) -> Void) {
        self.info = info
        self.onClick = onClick
        self.onRightClick = onRightClick
        super.init(frame: .zero)
        setupUI()
        setupTrackingArea()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 6
        
        iconView.image = info.icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.alphaValue = info.isMinimized ? 0.6 : 1.0
        
        ownerLabel.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        ownerLabel.textColor = info.isMinimized ? NSColor.white.withAlphaComponent(0.4) : .white
        ownerLabel.lineBreakMode = .byTruncatingTail
        ownerLabel.stringValue = info.ownerName
        
        titleLabel.font = NSFont.systemFont(ofSize: 9, weight: .regular)
        titleLabel.textColor = info.isMinimized ? NSColor.white.withAlphaComponent(0.2) : NSColor(white: 0.9, alpha: 0.8)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.stringValue = info.title
        
        let textStack = NSStackView(views: [ownerLabel, titleLabel])
        textStack.orientation = .vertical
        textStack.spacing = -1
        textStack.alignment = .leading
        
        let mainStack = NSStackView(views: [iconView, textStack])
        mainStack.orientation = .horizontal
        mainStack.spacing = 8
        mainStack.alignment = .centerY
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            mainStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            heightAnchor.constraint(equalToConstant: 34)
        ])
        
        updateBackground()
    }
    
    private func updateBackground() {
        if isHovered {
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
        } else {
            layer?.backgroundColor = info.isMinimized ? 
                NSColor.clear.cgColor : 
                NSColor.white.withAlphaComponent(0.08).cgColor
        }
    }
    
    private func setupTrackingArea() {
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func mouseDown(with event: NSEvent) { layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor }
    override func mouseUp(with event: NSEvent) {
        updateBackground()
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) { onClick() }
    }
    override func rightMouseDown(with event: NSEvent) { onRightClick(self) }
}

class TaskbarView: NSView {
    private let visualEffectView = NSVisualEffectView()
    private let darkOverlay = NSView()
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private var currentWindows: [WindowInfo] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.material = .underWindowBackground
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(visualEffectView)

        darkOverlay.wantsLayer = true
        darkOverlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        darkOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(darkOverlay)

        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        
        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.alignment = .centerY
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.documentView = stackView
        
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            darkOverlay.topAnchor.constraint(equalTo: topAnchor),
            darkOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            darkOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            darkOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            // Allow stackView to be as wide as it needs to be inside the scrollView
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateWindows(_ windows: [WindowInfo], onAction: @escaping (WindowInfo, WindowAction) -> Void) {
        if currentWindows == windows { return }
        currentWindows = windows
        
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.allowsImplicitAnimation = true
                
                // Remove views not in new list
                for subview in self.stackView.arrangedSubviews {
                    if let itemView = subview as? WindowItemView, !windows.contains(where: { $0.id == itemView.info.id }) {
                        itemView.animator().alphaValue = 0
                        self.stackView.removeArrangedSubview(itemView)
                        itemView.removeFromSuperview()
                    }
                }
                
                // Add or reposition
                for (index, info) in windows.enumerated() {
                    if let existing = self.stackView.arrangedSubviews.compactMap({ $0 as? WindowItemView }).first(where: { $0.info.id == info.id }) {
                        if existing.info != info {
                            // Simple way to refresh: replace if info changed
                            let newView = WindowItemView(info: info, onClick: { onAction(info, .toggle) }, onRightClick: { v in self.showContextMenu(for: info, in: v, onAction: onAction) })
                            let oldIdx = self.stackView.arrangedSubviews.firstIndex(of: existing)!
                            self.stackView.removeArrangedSubview(existing)
                            existing.removeFromSuperview()
                            self.stackView.insertArrangedSubview(newView, at: oldIdx)
                        }
                    } else {
                        let itemView = WindowItemView(info: info, onClick: { onAction(info, .toggle) }, onRightClick: { v in self.showContextMenu(for: info, in: v, onAction: onAction) })
                        itemView.alphaValue = 0
                        self.stackView.insertArrangedSubview(itemView, at: min(index, self.stackView.arrangedSubviews.count))
                        itemView.animator().alphaValue = 1.0
                    }
                }
            }
        }
    }
    
    private func showContextMenu(for info: WindowInfo, in view: NSView, onAction: @escaping (WindowInfo, WindowAction) -> Void) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        let actions: [(String, WindowAction)] = [("Open", .open), ("Minimize", .minimize)]
        for (title, action) in actions {
            let item = NSMenuItem(title: title, action: #selector(contextMenuHandler(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ["info": info, "action": action, "callback": onAction]
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit \(info.ownerName)", action: #selector(contextMenuHandler(_:)), keyEquivalent: "")
        quitItem.target = self
        quitItem.representedObject = ["info": info, "action": WindowAction.quit, "callback": onAction]
        menu.addItem(quitItem)
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height + 5), in: view)
    }
    
    @objc private func contextMenuHandler(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let info = dict["info"] as? WindowInfo,
              let action = dict["action"] as? WindowAction,
              let callback = dict["callback"] as? (WindowInfo, WindowAction) -> Void else { return }
        callback(info, action)
    }
}

enum WindowAction {
    case toggle, open, minimize, quit
}
