
import AppKit

class BarButton: NSView {
    var onClick: (() -> Void)?
    private let imageView = NSImageView()
    private var isHovered = false { didSet { updateBackground() } }

    init(icon: String, width: CGFloat, height: CGFloat, iconSize: CGFloat = 14) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 4
        
        imageView.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        imageView.contentTintColor = .white.withAlphaComponent(0.7)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: iconSize),
            imageView.heightAnchor.constraint(equalToConstant: iconSize),
            self.widthAnchor.constraint(equalToConstant: width),
            self.heightAnchor.constraint(equalToConstant: height)
        ])
        
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        updateBackground()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func updateBackground() {
        layer?.backgroundColor = isHovered ? NSColor.white.withAlphaComponent(0.2).cgColor : NSColor.clear.cgColor
    }
    
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func mouseDown(with event: NSEvent) { layer?.backgroundColor = NSColor.white.withAlphaComponent(0.3).cgColor }
    override func mouseUp(with event: NSEvent) {
        updateBackground()
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }
}

class WindowItemView: NSView {
    let info: WindowInfo
    private let onClick: () -> Void
    private let onRightClick: (NSView) -> Void
    private let iconView = NSImageView()
    private let ownerLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private var isHovered = false { didSet { updateBackground() } }

    init(info: WindowInfo, onClick: @escaping () -> Void, onRightClick: @escaping (NSView) -> Void) {
        self.info = info
        self.onClick = onClick
        self.onRightClick = onRightClick
        super.init(frame: .zero)
        setupUI()
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 6
        iconView.image = info.icon
        iconView.alphaValue = info.isMinimized ? 0.4 : 1.0
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        ownerLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        ownerLabel.textColor = info.isMinimized ? .white.withAlphaComponent(0.4) : .white
        ownerLabel.lineBreakMode = .byTruncatingTail
        ownerLabel.stringValue = info.ownerName
        
        titleLabel.font = NSFont.systemFont(ofSize: 9, weight: .regular)
        titleLabel.textColor = info.isMinimized ? .white.withAlphaComponent(0.25) : NSColor(white: 0.9, alpha: 0.7)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.stringValue = info.title
        
        let textStack = NSStackView(views: [ownerLabel, titleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 0
        
        let mainStack = NSStackView(views: [iconView, textStack])
        mainStack.spacing = 10
        mainStack.alignment = .centerY
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            mainStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            heightAnchor.constraint(equalToConstant: 44)
        ])
        updateBackground()
    }
    
    private func updateBackground() {
        layer?.backgroundColor = isHovered ? NSColor.white.withAlphaComponent(0.15).cgColor : (info.isMinimized ? NSColor.clear.cgColor : NSColor.white.withAlphaComponent(0.08).cgColor)
    }
    
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func mouseUp(with event: NSEvent) { if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick() } }
    override func rightMouseDown(with event: NSEvent) { onRightClick(self) }
}

class TaskbarView: NSView {
    var onHidePressed: (() -> Void)?
    private let dockContainer = NSView()
    private let controlsStack = NSStackView()
    private let scrollView = NSScrollView()
    private let windowStack = NSStackView()
    
    private let leftButton = BarButton(icon: "chevron.left", width: 24, height: 20, iconSize: 10)
    private let rightButton = BarButton(icon: "chevron.right", width: 24, height: 20, iconSize: 10)
    private let hideButton = BarButton(icon: "chevron.down", width: 50, height: 20, iconSize: 14)
    
    private var currentWindows: [WindowInfo] = []
    private var layoutState: LayoutState = .expanded
    
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    private var widthConstraint: NSLayoutConstraint!

    enum LayoutState { case expanded, collapsedLeft, collapsedRight }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError() }
    
    private func setupLayout() {
        dockContainer.translatesAutoresizingMaskIntoConstraints = false
        dockContainer.wantsLayer = true
        dockContainer.layer?.cornerRadius = 20
        dockContainer.layer?.masksToBounds = true
        dockContainer.layer?.borderWidth = 0.5
        dockContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        addSubview(dockContainer)

        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        dockContainer.addSubview(visualEffectView)
        
        let navStack = NSStackView(views: [leftButton, rightButton])
        navStack.orientation = .horizontal
        navStack.spacing = 2
        navStack.distribution = .fillEqually
        
        controlsStack.orientation = .vertical
        controlsStack.spacing = 2
        controlsStack.alignment = .centerX
        controlsStack.addArrangedSubview(navStack)
        controlsStack.addArrangedSubview(hideButton)
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        dockContainer.addSubview(controlsStack)
        
        leftButton.onClick = { [weak self] in self?.toggleCollapse(to: .collapsedLeft) }
        rightButton.onClick = { [weak self] in self?.toggleCollapse(to: .collapsedRight) }
        hideButton.onClick = { [weak self] in self?.onHidePressed?() }
        
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        dockContainer.addSubview(separator)
        
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        dockContainer.addSubview(scrollView)
        
        windowStack.orientation = .horizontal
        windowStack.spacing = 6
        windowStack.alignment = .centerY
        windowStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = windowStack
        
        NSLayoutConstraint.activate([
            dockContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            dockContainer.heightAnchor.constraint(equalToConstant: 58),
            
            visualEffectView.topAnchor.constraint(equalTo: dockContainer.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: dockContainer.bottomAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: dockContainer.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: dockContainer.trailingAnchor),
            
            
            scrollView.leadingAnchor.constraint(equalTo: dockContainer.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: separator.leadingAnchor, constant: -6),
            scrollView.topAnchor.constraint(equalTo: dockContainer.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: dockContainer.bottomAnchor),

            
            separator.trailingAnchor.constraint(equalTo: controlsStack.leadingAnchor, constant: -8),
            separator.centerYAnchor.constraint(equalTo: dockContainer.centerYAnchor),
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: 24),
            
            
            controlsStack.trailingAnchor.constraint(equalTo: dockContainer.trailingAnchor, constant: -8),
            controlsStack.centerYAnchor.constraint(equalTo: dockContainer.centerYAnchor),
            
            windowStack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            windowStack.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            windowStack.heightAnchor.constraint(equalTo: scrollView.contentView.heightAnchor)
        ])
        
        leadingConstraint = dockContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12)
        trailingConstraint = dockContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        
        widthConstraint = dockContainer.widthAnchor.constraint(equalToConstant: 84) 
        
        leadingConstraint.priority = .required
        trailingConstraint.priority = .required
        widthConstraint.priority = .defaultLow
        
        leadingConstraint.isActive = true
        trailingConstraint.isActive = true
        widthConstraint.isActive = true
    }
    
    private func toggleCollapse(to target: LayoutState) {
        var newState = target
        
        if layoutState == target { 
            return 
        } else if layoutState == .collapsedLeft && target == .collapsedRight {
             newState = .expanded
        } else if layoutState == .collapsedRight && target == .collapsedLeft {
             newState = .expanded
        }
        
        layoutState = newState
        animateLayout()
    }
    
    private func animateLayout() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            switch layoutState {
            case .expanded:
                leadingConstraint.animator().constant = 12
                trailingConstraint.animator().constant = -12
                leadingConstraint.animator().priority = .required
                trailingConstraint.animator().priority = .required
                widthConstraint.animator().priority = .defaultLow
                scrollView.animator().alphaValue = 1
                
            case .collapsedLeft:
                leadingConstraint.animator().constant = 12
                leadingConstraint.animator().priority = .required
                trailingConstraint.animator().priority = .defaultLow
                widthConstraint.animator().priority = .required
                scrollView.animator().alphaValue = 0
                
            case .collapsedRight:
                trailingConstraint.animator().constant = -12
                trailingConstraint.animator().priority = .required
                leadingConstraint.animator().priority = .defaultLow
                widthConstraint.animator().priority = .required
                scrollView.animator().alphaValue = 0
            }
        }
    }

    func updateWindows(_ windows: [WindowInfo], onAction: @escaping (WindowInfo, WindowAction) -> Void) {
        if currentWindows == windows { return }
        currentWindows = windows
        
        DispatchQueue.main.async {
            let existingViews = self.windowStack.arrangedSubviews.compactMap { $0 as? WindowItemView }
            for view in existingViews {
                if !windows.contains(where: { $0.id == view.info.id }) {
                    self.windowStack.removeArrangedSubview(view)
                    view.removeFromSuperview()
                }
            }
            
            for (index, info) in windows.enumerated() {
                let currentViews = self.windowStack.arrangedSubviews.compactMap { $0 as? WindowItemView }
                if let existingView = currentViews.first(where: { $0.info.id == info.id }) {
                    if existingView.info != info {
                        let newView = WindowItemView(info: info, onClick: { onAction(info, .toggle) }, onRightClick: { v in self.showContextMenu(for: info, in: v, onAction: onAction) })
                        self.windowStack.removeArrangedSubview(existingView)
                        existingView.removeFromSuperview()
                        if index < self.windowStack.arrangedSubviews.count {
                             self.windowStack.insertArrangedSubview(newView, at: index)
                        } else {
                             self.windowStack.addArrangedSubview(newView)
                        }
                    } else {
                        let currentIndex = self.windowStack.arrangedSubviews.firstIndex(of: existingView)
                        if currentIndex != index {
                            self.windowStack.insertArrangedSubview(existingView, at: index)
                        }
                    }
                } else {
                    let newView = WindowItemView(info: info, onClick: { onAction(info, .toggle) }, onRightClick: { v in self.showContextMenu(for: info, in: v, onAction: onAction) })
                    if index < self.windowStack.arrangedSubviews.count {
                        self.windowStack.insertArrangedSubview(newView, at: index)
                    } else {
                        self.windowStack.addArrangedSubview(newView)
                    }
                }
            }
        }
    }
    
    private func showContextMenu(for info: WindowInfo, in view: NSView, onAction: @escaping (WindowInfo, WindowAction) -> Void) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        let reorderItem = NSMenuItem(title: "Reorder", action: nil, keyEquivalent: "")
        let subMenu = NSMenu()
        for i in 1...10 {
            let item = NSMenuItem(title: "\(i)", action: #selector(contextMenuHandler(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ["info": info, "action": WindowAction.reorder(i), "callback": onAction]
            if info.orderPriority == i {
                item.state = .on
            }
            subMenu.addItem(item)
        }
        subMenu.addItem(NSMenuItem.separator())
        let defaultItem = NSMenuItem(title: "No order preference", action: #selector(contextMenuHandler(_:)), keyEquivalent: "")
        defaultItem.target = self
        defaultItem.representedObject = ["info": info, "action": WindowAction.reorder(nil), "callback": onAction]
        if info.orderPriority == Int.max {
            defaultItem.state = .on
        }
        subMenu.addItem(defaultItem)
        reorderItem.submenu = subMenu
        menu.addItem(reorderItem)
        
        let actions: [(String, WindowAction)] = [("Open", .open), ("Minimize", .minimize), ("Quit \(info.ownerName)", .quit)]
        for (title, action) in actions {
            let item = NSMenuItem(title: title, action: #selector(contextMenuHandler(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ["info": info, "action": action, "callback": onAction]
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height + 8), in: view)
    }
    
    @objc private func contextMenuHandler(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let info = dict["info"] as? WindowInfo,
              let action = dict["action"] as? WindowAction,
              let callback = dict["callback"] as? (WindowInfo, WindowAction) -> Void else { return }
        callback(info, action)
    }
}

enum WindowAction: Equatable {
    case toggle, open, minimize, quit, reorder(Int?)
    
    static func == (lhs: WindowAction, rhs: WindowAction) -> Bool {
        switch (lhs, rhs) {
        case (.toggle, .toggle), (.open, .open), (.minimize, .minimize), (.quit, .quit): return true
        case (.reorder(let a), .reorder(let b)): return a == b
        default: return false
        }
    }
}
