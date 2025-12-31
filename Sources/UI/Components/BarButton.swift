
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
