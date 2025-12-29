
import AppKit

class WindowButton: NSButton {
    var windowInfo: WindowInfo?
    
    init(info: WindowInfo, target: Any?, action: Selector) {
        super.init(frame: .zero)
        self.windowInfo = info
        self.target = target as AnyObject
        self.action = action
        
        self.bezelStyle = .recessed
        self.isBordered = true
        self.controlSize = .regular
        
        // UI Logic: 
        // - Minimized windows are gray and italic
        // - Non-minimized windows are white
        let color = info.isMinimized ? NSColor.lightGray : NSColor.white
        let font: NSFont
        if info.isMinimized {
            font = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 11), toHaveTrait: .italicFontMask)
        } else {
            font = NSFont.systemFont(ofSize: 11, weight: .medium)
        }
        
        let pStyle = NSMutableParagraphStyle()
        pStyle.alignment = .center
        pStyle.lineBreakMode = .byTruncatingTail
        
        self.attributedTitle = NSAttributedString(string: info.displayName, attributes: [
            .foregroundColor: color,
            .font: font,
            .paragraphStyle: pStyle
        ])
        
        // Visually dim minimized buttons
        self.alphaValue = info.isMinimized ? 0.5 : 1.0
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.widthAnchor.constraint(lessThanOrEqualToConstant: 250).isActive = true
        self.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }
    
    required init?(coder: NSCoder) { fatalError() }
}

class TaskbarView: NSView {
    let stackView = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor

        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.alignment = .centerY
        stackView.distribution = .gravityAreas
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateWindows(_ windows: [WindowInfo], target: Any?, action: Selector) {
        DispatchQueue.main.async {
            self.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for info in windows {
                let btn = WindowButton(info: info, target: target, action: action)
                self.stackView.addArrangedSubview(btn)
            }
        }
    }
}
