
import AppKit

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSPanel!
    var taskbarView: TaskbarView!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupWindow()
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.refreshWindows()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refreshWindows),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        
        refreshWindows()
    }

    private func setupWindow() {
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let barHeight: CGFloat = 40
        
        window = NSPanel(
            contentRect: NSRect(x: screen.origin.x, y: 0, width: screen.width, height: barHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.level = .screenSaver
        window.isFloatingPanel = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.orderFrontRegardless()
        
        taskbarView = TaskbarView(frame: window.contentView!.bounds)
        window.contentView = taskbarView
    }

    private func isWindowMinimized(pid: Int32, id: CGWindowID) -> Bool {
        let appRef = AXUIElementCreateApplication(pid)
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let list = value as? [AXUIElement] else { return false }
        
        for win in list {
            var winID: CGWindowID = 0
            _ = _AXUIElementGetWindow(win, &winID)
            if winID == id {
                var minVal: AnyObject?
                AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minVal)
                return (minVal as? Bool) == true
            }
        }
        return false
    }

    @objc private func refreshWindows() {
        // 1. Get IDs of windows actually visible on current space
        let onScreenOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let onScreenList = CGWindowListCopyWindowInfo(onScreenOptions, kCGNullWindowID) as? [[String: Any]] ?? []
        let onScreenIDs = Set(onScreenList.compactMap { $0[kCGWindowNumber as String] as? CGWindowID })
        
        // 2. Get all windows to find minimized ones
        let allOptions: CGWindowListOption = [.excludeDesktopElements, .optionAll]
        guard let allWindows = CGWindowListCopyWindowInfo(allOptions, kCGNullWindowID) as? [[String: Any]] else { return }
        
        let currentPID = ProcessInfo.processInfo.processIdentifier
        
        var windows = allWindows.compactMap { dict -> WindowInfo? in
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = dict[kCGWindowOwnerPID as String] as? Int32, pid != currentPID,
                  let id = dict[kCGWindowNumber as String] as? CGWindowID else {
                return nil
            }
            
            let title = dict[kCGWindowName as String] as? String ?? ""
            if title.isEmpty { return nil }
            
            let isOnCurrentSpace = onScreenIDs.contains(id)
            let isMinimized = isWindowMinimized(pid: pid, id: id)
            
            // Keep if it's on the current space OR if it's minimized (regardless of space)
            if isOnCurrentSpace || isMinimized {
                var info = WindowInfo(dict: dict)
                info?.isMinimized = isMinimized
                return info
            }
            
            return nil
        }
        
        windows.sort {
            if $0.ownerName.lowercased() != $1.ownerName.lowercased() {
                return $0.ownerName.lowercased() < $1.ownerName.lowercased()
            }
            return $0.title.lowercased() < $1.title.lowercased()
        }
        
        self.taskbarView.updateWindows(windows, target: self, action: #selector(self.handleAction))
    }

    @objc private func handleAction(_ sender: WindowButton) {
        guard let info = sender.windowInfo else { return }
        
        // Determine frontmost window to handle minimize toggle
        let onScreenOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let onScreenList = CGWindowListCopyWindowInfo(onScreenOptions, kCGNullWindowID) as? [[String: Any]] ?? []
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let frontmostWindow = onScreenList.first { dict in
            let pid = dict[kCGWindowOwnerPID as String] as? Int32 ?? 0
            let layer = dict[kCGWindowLayer as String] as? Int ?? -1
            return pid != currentPID && layer == 0
        }
        let isFrontmost = (frontmostWindow?[kCGWindowNumber as String] as? CGWindowID == info.id)
        
        let appRef = AXUIElementCreateApplication(info.pid)
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let list = value as? [AXUIElement] else { return }
        
        for win in list {
            var id: CGWindowID = 0
            _ = _AXUIElementGetWindow(win, &id)
            
            if id == info.id {
                if isFrontmost {
                    AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, true as CFTypeRef)
                } else {
                    // Un-minimize if needed
                    AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, false as CFTypeRef)
                    // Focus
                    AXUIElementPerformAction(win, kAXRaiseAction as CFString)
                    if let app = NSRunningApplication(processIdentifier: info.pid) {
                        app.activate(options: .activateIgnoringOtherApps)
                    }
                }
                break
            }
        }
        
        self.refreshWindows()
    }
}
