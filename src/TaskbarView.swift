
import AppKit

class HideButton: NSView {
    var onClick: (() -> Void)?
    private let imageView = NSImageView()
    private var isHovered = false { didSet { updateBackground() } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        
        imageView.image = NSImage(systemSymbolName: "chevron.down.circle.fill", accessibilityDescription: "Hide")
        imageView.contentTintColor = .white.withAlphaComponent(0.6)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24),
            widthAnchor.constraint(equalToConstant: 40),
            heightAnchor.constraint(equalToConstant: 44)
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
    private let stackView = NSStackView()
    private let hideButton = HideButton()
    private var currentWindows: [WindowInfo] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
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

        stackView.orientation = .horizontal
        stackView.spacing = 6
        stackView.alignment = .centerY
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        dockContainer.addSubview(stackView)
        
        hideButton.onClick = { [weak self] in self?.onHidePressed?() }
        stackView.addArrangedSubview(hideButton)
        
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        let widthC = separator.widthAnchor.constraint(equalToConstant: 1)
        widthC.identifier = "sep"
        widthC.isActive = true
        separator.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stackView.addArrangedSubview(separator)

        NSLayoutConstraint.activate([
            dockContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            dockContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            dockContainer.heightAnchor.constraint(equalToConstant: 52),
            dockContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            visualEffectView.topAnchor.constraint(equalTo: dockContainer.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: dockContainer.bottomAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: dockContainer.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: dockContainer.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: dockContainer.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: dockContainer.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: dockContainer.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: dockContainer.trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateWindows(_ windows: [WindowInfo], onAction: @escaping (WindowInfo, WindowAction) -> Void) {
        if currentWindows == windows { return }
        currentWindows = windows
        
        DispatchQueue.main.async {
            let existingViews = self.stackView.arrangedSubviews.compactMap { $0 as? WindowItemView }
            for view in existingViews {
                if !windows.contains(where: { $0.id == view.info.id }) {
                    self.stackView.removeArrangedSubview(view)
                    view.removeFromSuperview()
                }
            }
            
            for info in windows {
                if let existing = existingViews.first(where: { $0.info.id == info.id }) {
                    if existing.info != info {
                        let idx = self.stackView.arrangedSubviews.firstIndex(of: existing)!
                        self.stackView.removeArrangedSubview(existing)
                        existing.removeFromSuperview()
                        self.stackView.insertArrangedSubview(WindowItemView(info: info, onClick: { onAction(info, .toggle) }, onRightClick: { v in self.showContextMenu(for: info, in: v, onAction: onAction) }), at: idx)
                    }
                } else {
                    self.stackView.addArrangedSubview(WindowItemView(info: info, onClick: { onAction(info, .toggle) }, onRightClick: { v in self.showContextMenu(for: info, in: v, onAction: onAction) }))
                }
            }
        }
    }
    
    private func showContextMenu(for info: WindowInfo, in view: NSView, onAction: @escaping (WindowInfo, WindowAction) -> Void) {
        let menu = NSMenu()
        menu.autoenablesItems = false
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

enum WindowAction { case toggle, open, minimize, quit }
