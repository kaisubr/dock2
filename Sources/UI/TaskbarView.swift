
import AppKit

class TaskbarView: NSView {
    var onHidePressed: (() -> Void)?
    var onHoverChange: ((Int32, Bool) -> Void)?
    
    private let dockContainer = NSView()
    private let controlsStack = NSStackView()
    private let scrollView = NSScrollView()
    private let windowStack = NSStackView()
    
    private let leftButton = BarButton(icon: "chevron.left", width: 24, height: 20, iconSize: 10)
    private let rightButton = BarButton(icon: "chevron.right", width: 24, height: 20, iconSize: 10)
    private let hideButton = BarButton(icon: "chevron.down", width: 50, height: 20, iconSize: 14)
    
    private var allWindows: [WindowModel] = []
    private var displayedWindows: [WindowModel] = []
    
    private var windowActionCallback: ((WindowModel, WindowAction) -> Void)?
    
    private var layoutState: LayoutState = .expanded
    
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    private var widthConstraint: NSLayoutConstraint!
    
    
    private var pendingRemovals: [Int32: DispatchWorkItem] = [:]

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

    func updateWindows(_ windows: [WindowModel], onAction: @escaping (WindowModel, WindowAction) -> Void) {
        self.allWindows = windows
        self.windowActionCallback = onAction
        
        
        
        render(windows: windows)
    }
    
    private func render(windows: [WindowModel]) {
        if displayedWindows == windows { return }
        displayedWindows = windows
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let existingViews = self.windowStack.arrangedSubviews.compactMap { $0 as? WindowItemView }
            for view in existingViews {
                
                if !self.displayedWindows.contains(where: { $0.id == view.model.id }) {
                    self.windowStack.removeArrangedSubview(view)
                    view.removeFromSuperview()
                }
            }
            
            for (index, info) in self.displayedWindows.enumerated() {
                let currentViews = self.windowStack.arrangedSubviews.compactMap { $0 as? WindowItemView }
                if let existingView = currentViews.first(where: { $0.model.id == info.id }) {
                    if existingView.model != info {
                        let newView = self.createWindowView(for: info)
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
                    let newView = self.createWindowView(for: info)
                    if index < self.windowStack.arrangedSubviews.count {
                        self.windowStack.insertArrangedSubview(newView, at: index)
                    } else {
                        self.windowStack.addArrangedSubview(newView)
                    }
                }
            }
        }
    }
    
    private func createWindowView(for model: WindowModel) -> WindowItemView {
        return WindowItemView(
            model: model,
            onClick: { [weak self] in self?.windowActionCallback?(model, .toggle) },
            onRightClick: { [weak self] v in self?.showContextMenu(for: model, in: v) },
            onHover: { [weak self] h in self?.handleHover(pid: model.pid, hovering: h) }
        )
    }
    
    private func handleHover(pid: Int32, hovering: Bool) {
        if hovering {
            if let pending = pendingRemovals[pid] {
                pending.cancel()
                pendingRemovals.removeValue(forKey: pid)
            }
            
            onHoverChange?(pid, true)
        } else {
            
            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if self.pendingRemovals[pid] != nil { 
                    self.pendingRemovals.removeValue(forKey: pid)
                    self.onHoverChange?(pid, false)
                }
            }
            pendingRemovals[pid] = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
        }
    }
    
    private func showContextMenu(for model: WindowModel, in view: NSView) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        let reorderItem = NSMenuItem(title: "Reorder", action: nil, keyEquivalent: "")
        let subMenu = NSMenu()
        for i in 1...10 {
            let item = NSMenuItem(title: "\(i)", action: #selector(contextMenuHandler(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ["model": model, "action": WindowAction.reorder(i)]
            if model.orderPriority == i {
                item.state = .on
            }
            subMenu.addItem(item)
        }
        subMenu.addItem(NSMenuItem.separator())
        let defaultItem = NSMenuItem(title: "No order preference", action: #selector(contextMenuHandler(_:)), keyEquivalent: "")
        defaultItem.target = self
        defaultItem.representedObject = ["model": model, "action": WindowAction.reorder(nil)]
        if model.orderPriority == Int.max {
            defaultItem.state = .on
        }
        subMenu.addItem(defaultItem)
        reorderItem.submenu = subMenu
        menu.addItem(reorderItem)
        
        let actions: [(String, WindowAction)] = [("Open", .open), ("Minimize", .minimize), ("Quit \(model.ownerName)", .quit)]
        for (title, action) in actions {
            let item = NSMenuItem(title: title, action: #selector(contextMenuHandler(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ["model": model, "action": action]
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height + 8), in: view)
    }
    
    @objc private func contextMenuHandler(_ sender: NSMenuItem) {
        guard let dict = sender.representedObject as? [String: Any],
              let model = dict["model"] as? WindowModel,
              let action = dict["action"] as? WindowAction else { return }
        windowActionCallback?(model, action)
    }
}
