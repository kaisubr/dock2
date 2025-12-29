
import AppKit

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSPanel!
    var taskbarView: TaskbarView!
    var statusItem: NSStatusItem?
    var isManuallyHidden = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupWindow()
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
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

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "menubar.dock.rectangle", accessibilityDescription: "dock2")
        }
        updateMenu()
    }
    
    private func updateMenu() {
        let menu = NSMenu()
        let toggleTitle = isManuallyHidden ? "Show dock2" : "Hide dock2"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleVisibility), keyEquivalent: "h")
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit dock2", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc private func toggleVisibility() {
        isManuallyHidden.toggle()
        if isManuallyHidden {
            window.orderOut(nil)
        } else {
            window.orderFrontRegardless()
        }
        updateMenu()
    }

    private func setupWindow() {
        
        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        
        let barHeight: CGFloat = 64 
        let bottomMargin: CGFloat = 12
        
        let rect = NSRect(x: screenFrame.origin.x, y: screenFrame.origin.y + bottomMargin, width: screenFrame.width, height: barHeight)
        
        window = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.dockWindow)))
        window.isFloatingPanel = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.appearance = NSAppearance(named: .vibrantDark)
        
        taskbarView = TaskbarView(frame: window.contentView!.bounds)
        taskbarView.onHidePressed = { [weak self] in self?.toggleVisibility() }
        taskbarView.autoresizingMask = [.width, .height]
        window.contentView = taskbarView
        
        window.orderFrontRegardless()
    }

    @objc private func refreshWindows() {
        if isManuallyHidden { return }
        
        let onScreenOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let onScreenList = CGWindowListCopyWindowInfo(onScreenOptions, kCGNullWindowID) as? [[String: Any]] ?? []
        
        let onScreenIDs = Set(onScreenList.compactMap { $0[kCGWindowNumber as String] as? CGWindowID })
        let allOptions: CGWindowListOption = [.excludeDesktopElements, .optionAll]
        guard let allWindows = CGWindowListCopyWindowInfo(allOptions, kCGNullWindowID) as? [[String: Any]] else { return }
        
        let currentPID = ProcessInfo.processInfo.processIdentifier
        var windows = allWindows.compactMap { dict -> WindowInfo? in
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = dict[kCGWindowOwnerPID as String] as? Int32, pid != currentPID,
                  let id = dict[kCGWindowNumber as String] as? CGWindowID else { return nil }
            
            let isOnCurrentSpace = onScreenIDs.contains(id)
            if isOnCurrentSpace || isWindowMinimized(pid: pid, id: id) {
                var info = WindowInfo(dict: dict)
                info?.isMinimized = !isOnCurrentSpace
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

    private func activateApp(_ app: NSRunningApplication?) {
        guard let app = app else { return }
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }

    private func handleWindowAction(info: WindowInfo, action: WindowAction) {
        if action == .quit {
            NSRunningApplication(processIdentifier: info.pid)?.terminate()
            return
        }
        
        let appRef = AXUIElementCreateApplication(info.pid)
        let app = NSRunningApplication(processIdentifier: info.pid)
        
        var value: AnyObject?
        AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
        guard let list = value as? [AXUIElement] else { return }
        
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
                        if isAppActive && focusedID == info.id {
                            AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, true as CFTypeRef)
                        } else {
                            AXUIElementPerformAction(win, kAXRaiseAction as CFString)
                            activateApp(app)
                        }
                    }
                case .quit:
                    break
                }
                break
            }
        }
    }
}
