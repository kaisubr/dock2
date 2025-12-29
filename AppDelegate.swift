
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        refreshWindows()
    }

    private func setupWindow() {
        // Use the primary screen (index 0) to ensure we get the main display
        let screen = NSScreen.screens.first ?? NSScreen.main
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let barHeight: CGFloat = 40
        
        // y: 0 is the bottom of the screen in macOS coordinates
        let rect = NSRect(x: screenFrame.origin.x, y: screenFrame.origin.y, width: screenFrame.width, height: barHeight)
        
        window = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Use statusWindow level to stay above normal windows but below system overlays
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.statusWindow)))
        window.isFloatingPanel = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        
        taskbarView = TaskbarView(frame: window.contentView!.bounds)
        window.contentView = taskbarView
        
        window.orderFrontRegardless()
    }
    
    @objc private func handleScreenChange() {
        let screen = NSScreen.screens.first ?? NSScreen.main
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let barHeight: CGFloat = 40
        let newRect = NSRect(x: screenFrame.origin.x, y: screenFrame.origin.y, width: screenFrame.width, height: barHeight)
        window.setFrame(newRect, display: true)
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
            
            let isOnCurrentSpace = onScreenIDs.contains(id)
            let isMinimized = isWindowMinimized(pid: pid, id: id)
            
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
        
        self.taskbarView.updateWindows(windows) { [weak self] info, action in
            self?.handleWindowAction(info: info, action: action)
        }
    }

    private func handleWindowAction(info: WindowInfo, action: WindowAction) {
        if action == .quit {
            NSRunningApplication(processIdentifier: info.pid)?.terminate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.refreshWindows() }
            return
        }

        let appRef = AXUIElementCreateApplication(info.pid)
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let list = value as? [AXUIElement] else { return }
        
        for win in list {
            var id: CGWindowID = 0
            _ = _AXUIElementGetWindow(win, &id)
            
            if id == info.id {
                switch action {
                case .minimize:
                    AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, true as CFTypeRef)
                case .open:
                    AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, false as CFTypeRef)
                    AXUIElementPerformAction(win, kAXRaiseAction as CFString)
                    NSRunningApplication(processIdentifier: info.pid)?.activate(options: .activateIgnoringOtherApps)
                case .toggle:
                    let isFrontmost = checkIsFrontmost(id: info.id)
                    if isFrontmost {
                        AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, true as CFTypeRef)
                    } else {
                        AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, false as CFTypeRef)
                        AXUIElementPerformAction(win, kAXRaiseAction as CFString)
                        NSRunningApplication(processIdentifier: info.pid)?.activate(options: .activateIgnoringOtherApps)
                    }
                default: break
                }
                break
            }
        }
        self.refreshWindows()
    }

    private func checkIsFrontmost(id: CGWindowID) -> Bool {
        let onScreenOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let onScreenList = CGWindowListCopyWindowInfo(onScreenOptions, kCGNullWindowID) as? [[String: Any]] ?? []
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let frontmostWindow = onScreenList.first { dict in
            let pid = dict[kCGWindowOwnerPID as String] as? Int32 ?? 0
            let layer = dict[kCGWindowLayer as String] as? Int ?? -1
            return pid != currentPID && layer == 0
        }
        return (frontmostWindow?[kCGWindowNumber as String] as? CGWindowID == id)
    }
}
