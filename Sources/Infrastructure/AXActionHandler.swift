
import AppKit
import ApplicationServices

public class AXActionHandler: ActionHandler {
    @_silgen_name("_AXUIElementGetWindow")
    private func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError
    
    private let configStore: ConfigStore
    
    public init(configStore: ConfigStore) {
        self.configStore = configStore
    }
    
    public func perform(_ action: WindowAction, on window: WindowModel) {
        if case .reorder(let orderPriority) = action {
            configStore.setOrderPriority(for: window.bundleIdentifier, ownerName: window.ownerName, priority: orderPriority)
            return
        }

        if action == .quit {
            NSRunningApplication(processIdentifier: window.pid)?.terminate()
            return
        }
        
        let appRef = AXUIElementCreateApplication(window.pid)
        let app = NSRunningApplication(processIdentifier: window.pid)
        
        var value: AnyObject?
        AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
        guard let list = value as? [AXUIElement] else { return }
        
        for win in list {
            var id: CGWindowID = 0
            _ = _AXUIElementGetWindow(win, &id)
            if id == window.id {
                switch action {
                case .minimize:
                    AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, true as CFTypeRef)
                case .open:
                    AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, false as CFTypeRef)
                    AXUIElementPerformAction(win, kAXRaiseAction as CFString)
                    activateApp(app)
                case .toggle:
                    var minVal: AnyObject?
                    AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minVal)
                    let isMinimized = (minVal as? Bool) == true
                    
                    if isMinimized {
                        AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, false as CFTypeRef)
                        AXUIElementPerformAction(win, kAXRaiseAction as CFString)
                        activateApp(app)
                    } else {
                        var focusedWindow: AnyObject?
                        var focusedID: CGWindowID = 0
                        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWindow)
                        
                        if result == .success, let focusedWin = focusedWindow {
                            _ = _AXUIElementGetWindow(focusedWin as! AXUIElement, &focusedID)
                        }
                        
                        let isAppActive = app?.isActive ?? false
                        if isAppActive && focusedID == window.id {
                            AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, true as CFTypeRef)
                        } else {
                            AXUIElementPerformAction(win, kAXRaiseAction as CFString)
                            activateApp(app)
                        }
                    }
                case .quit, .reorder:
                    break
                }
                break
            }
        }
    }
    
    public func constrainWindow(pid: Int32, id: UInt32, limitY: Double) {
        DispatchQueue.global(qos: .userInteractive).async {
            let appRef = AXUIElementCreateApplication(pid)
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
            guard result == .success, let list = value as? [AXUIElement] else { return }
            
            for win in list {
                var winID: CGWindowID = 0
                self._AXUIElementGetWindow(win, &winID)
                if winID == id {
                    var posValue: AnyObject?
                    var sizeValue: AnyObject?
                    AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posValue)
                    AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeValue)
                    
                    var pos = CGPoint.zero
                    var size = CGSize.zero
                    
                    if let pVal = posValue as! AXValue? { AXValueGetValue(pVal, .cgPoint, &pos) }
                    if let sVal = sizeValue as! AXValue? { AXValueGetValue(sVal, .cgSize, &size) }
                    
                    let currentFrame = CGRect(origin: pos, size: size)
                    
                    if currentFrame.maxY > limitY && currentFrame.minY < limitY {
                        let newHeight = limitY - currentFrame.minY
                        if newHeight < 50 { return }
                        
                        var newSize = CGSize(width: currentFrame.width, height: newHeight)
                        if let val = AXValueCreate(.cgSize, &newSize) {
                            AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, val)
                        }
                    }
                    return
                }
            }
        }
    }
    
    private func activateApp(_ app: NSRunningApplication?) {
        guard let app = app else { return }
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }
}
