
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

    @objc private func refreshWindows() {
        let onScreenOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let onScreenList = CGWindowListCopyWindowInfo(onScreenOptions, kCGNullWindowID) as? [[String: Any]] ?? []
        let onScreenIDs = Set(onScreenList.compactMap { $0[kCGWindowNumber as String] as? CGWindowID })
        
        let allOptions: CGWindowListOption = [.excludeDesktopElements, .optionAll]
        guard let allWindows = CGWindowListCopyWindowInfo(allOptions, kCGNullWindowID) as? [[String: Any]] else { return }
        
        let currentPID = ProcessInfo.processInfo.processIdentifier
        
        var windows = allWindows.compactMap { dict -> WindowInfo? in
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = dict[kCGWindowOwnerPID as String] as? Int32, pid != currentPID else {
                return nil
            }
            
            let id = dict[kCGWindowNumber as String] as? CGWindowID ?? 0
            let isOnThisSpace = onScreenIDs.contains(id)
            let isMinimized = !(dict[kCGWindowIsOnscreen as String] as? Bool ?? true)
            
            // Show only windows on this space OR minimized windows
            if !isOnThisSpace && !isMinimized { return nil }
            return WindowInfo(dict: dict)
        }
        
        // Sorting: Program Name -> Window Title
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
        let appRef = AXUIElementCreateApplication(info.pid)
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let list = value as? [AXUIElement] else { return }
        
        for win in list {
            var id: CGWindowID = 0
            _ = _AXUIElementGetWindow(win, &id)
            if id == info.id {
                var minVal: AnyObject?
                AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minVal)
                if (minVal as? Bool) == true {
                    AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, false as CFTypeRef)
                    AXUIElementPerformAction(win, kAXRaiseAction as CFString)
                    NSRunningApplication(processIdentifier: info.pid)?.activate()
                } else {
                    AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, true as CFTypeRef)
                }
                break
            }
        }
    }
}
