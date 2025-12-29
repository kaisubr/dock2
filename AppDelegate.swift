
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

    private func checkMinimizedState(pid: Int32, id: CGWindowID) -> Bool {
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
        let onScreenOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let onScreenList = CGWindowListCopyWindowInfo(onScreenOptions, kCGNullWindowID) as? [[String: Any]] ?? []
        let onScreenIDs = Set(onScreenList.compactMap { $0[kCGWindowNumber as String] as? CGWindowID })
        
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
            var info = WindowInfo(dict: dict)
            
            if !isOnCurrentSpace {
                info?.isMinimized = checkMinimizedState(pid: pid, id: id)
            } else {
                info?.isMinimized = false
            }
            
            return info
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
        
        // 1. Determine which window is currently frontmost (top-most in Z-order)
        let onScreenOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let onScreenList = CGWindowListCopyWindowInfo(onScreenOptions, kCGNullWindowID) as? [[String: Any]] ?? []
        let currentPID = ProcessInfo.processInfo.processIdentifier
        
        // Find the first window that belongs to another app and is on layer 0 (normal windows)
        let frontmostWindow = onScreenList.first { dict in
            let pid = dict[kCGWindowOwnerPID as String] as? Int32 ?? 0
            let layer = dict[kCGWindowLayer as String] as? Int ?? -1
            return pid != currentPID && layer == 0
        }
        let frontmostID = frontmostWindow?[kCGWindowNumber as String] as? CGWindowID
        
        // Check if the clicked window is the one currently being used
        let isFrontmost = (frontmostID == info.id)
        
        // 2. Perform accessibility actions
        let appRef = AXUIElementCreateApplication(info.pid)
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let list = value as? [AXUIElement] else { return }
        
        for win in list {
            var id: CGWindowID = 0
            _ = _AXUIElementGetWindow(win, &id)
            
            if id == info.id {
                if isFrontmost {
                    // Window is already active -> Minimize it
                    AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, true as CFTypeRef)
                } else {
                    // Window is not active (minimized or behind) -> Bring to front
                    // Un-minimize if it was minimized
                    AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, false as CFTypeRef)
                    // Raise it to the top of its app's window stack
                    AXUIElementPerformAction(win, kAXRaiseAction as CFString)
                    // Activate the application
                    NSRunningApplication(processIdentifier: info.pid)?.activate(options: .activateIgnoringOtherApps)
                }
                break
            }
        }
        
        // Force a refresh so UI updates immediately after click
        self.refreshWindows()
    }
}
