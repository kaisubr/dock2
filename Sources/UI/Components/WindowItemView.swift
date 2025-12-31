
import AppKit

class WindowItemView: NSView {
    let model: WindowModel
    private let onClick: () -> Void
    private let onRightClick: (NSView) -> Void
    private let onHover: (Bool) -> Void
    private let iconView = NSImageView()
    private let ownerLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private var isHovered = false { didSet { updateBackground() } }

    init(model: WindowModel, onClick: @escaping () -> Void, onRightClick: @escaping (NSView) -> Void, onHover: @escaping (Bool) -> Void) {
        self.model = model
        self.onClick = onClick
        self.onRightClick = onRightClick
        self.onHover = onHover
        super.init(frame: .zero)
        setupUI()
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 6
        
        
        if let app = NSRunningApplication(processIdentifier: model.pid) {
            iconView.image = app.icon
        } else {
            iconView.image = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericApplicationIcon)))
        }
        
        iconView.alphaValue = model.isMinimized ? 0.4 : 1.0
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        ownerLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        ownerLabel.textColor = model.isMinimized ? .white.withAlphaComponent(0.4) : .white
        ownerLabel.lineBreakMode = .byTruncatingTail
        ownerLabel.stringValue = model.ownerName
        
        titleLabel.font = NSFont.systemFont(ofSize: 9, weight: .regular)
        titleLabel.textColor = model.isMinimized ? .white.withAlphaComponent(0.25) : NSColor(white: 0.9, alpha: 0.7)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.stringValue = model.title
        
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
        layer?.backgroundColor = isHovered ? NSColor.white.withAlphaComponent(0.15).cgColor : (model.isMinimized ? NSColor.clear.cgColor : NSColor.white.withAlphaComponent(0.08).cgColor)
    }
    
    override func mouseEntered(with event: NSEvent) { 
        isHovered = true 
        onHover(true)
    }
    override func mouseExited(with event: NSEvent) { 
        isHovered = false 
        onHover(false)
    }
    override func mouseUp(with event: NSEvent) { if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick() } }
    override func rightMouseDown(with event: NSEvent) { onRightClick(self) }
}
