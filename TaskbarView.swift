
import AppKit

class WindowItemView: NSView {
    let info: WindowInfo
    private let onClick: () -> Void
    private let onRightClick: (NSView) -> Void
    
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
        layer?.cornerRadius = 5
        
        // Owner name (e.g. Firefox) - Bright White
        ownerLabel.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        ownerLabel.textColor = info.isMinimized ? NSColor.white.withAlphaComponent(0.4) : .white
        ownerLabel.lineBreakMode = .byTruncatingTail
        ownerLabel.stringValue = info.ownerName
        
        // Window title - Silver/Light Gray
        titleLabel.font = NSFont.systemFont(ofSize: 9, weight: .regular)
        titleLabel.textColor = info.isMinimized ? NSColor.white.withAlphaComponent(0.2) : NSColor(white: 0.9, alpha: 0.8)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.stringValue = info.title
        
        let stack = NSStackView(views: [ownerLabel, titleLabel])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(lessThanOrEqualToConstant: 220),
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
                NSColor.white.withAlphaComponent(0.05).cgColor
        }
    }
    
    private func setupTrackingArea() {
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    
    override func mouseDown(with event: NSEvent) {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
    }
    
    override func mouseUp(with event: NSEvent) {
        updateBackground()
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) {
            onClick()
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        onRightClick(self)
    }
}

class TaskbarView: NSView {
    private let visualEffectView = NSVisualEffectView()
    private let darkOverlay = NSView()
    private let stackView = NSStackView()
    private var currentWindows: [WindowInfo] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        // 1. Setup Blur
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.material = .underWindowBackground
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(visualEffectView)

        // 2. Setup Dark Tint (to make white text stand out)
        darkOverlay.wantsLayer = true
        darkOverlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        darkOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(darkOverlay)

        // 3. Setup Stack
        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.alignment = .centerY
        stackView.distribution = .gravityAreas
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            darkOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            darkOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            darkOverlay.topAnchor.constraint(equalTo: topAnchor),
            darkOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateWindows(_ windows: [WindowInfo], onAction: @escaping (WindowInfo, WindowAction) -> Void) {
        if currentWindows == windows { return }
        currentWindows = windows
        
        DispatchQueue.main.async {
            self.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for info in windows {
                let itemView = WindowItemView(info: info, onClick: {
                    onAction(info, .toggle)
                }, onRightClick: { sourceView in
                    self.showContextMenu(for: info, in: sourceView, onAction: onAction)
                })
                self.stackView.addArrangedSubview(itemView)
            }
        }
    }
    
    private func showContextMenu(for info: WindowInfo, in view: NSView, onAction: @escaping (WindowInfo, WindowAction) -> Void) {
        let menu = NSMenu()
        menu.autoenablesItems = false // Ensure manual control over enabling
        
        let openItem = NSMenuItem(title: "Open", action: #selector(contextMenuHandler(_:)), keyEquivalent: "")
        openItem.target = self
        openItem.representedObject = ["info": info, "action": WindowAction.open, "callback": onAction]
        menu.addItem(openItem)
        
        let minItem = NSMenuItem(title: "Minimize", action: #selector(contextMenuHandler(_:)), keyEquivalent: "")
        minItem.target = self
        minItem.representedObject = ["info": info, "action": WindowAction.minimize, "callback": onAction]
        menu.addItem(minItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit \(info.ownerName)", action: #selector(contextMenuHandler(_:)), keyEquivalent: "")
        quitItem.target = self
        quitItem.representedObject = ["info": info, "action": WindowAction.quit, "callback": onAction]
        menu.addItem(quitItem)
        
        // Pop up the menu above the item
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
