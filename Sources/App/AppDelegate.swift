
import AppKit
import CoreGraphics

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSPanel!
    var taskbarView: TaskbarView!
    var statusItem: NSStatusItem?
    var isManuallyHidden = false
    
    var dockService: DockService!
    private let dockVisibleHeight: CGFloat = 64
    private var hoveredPids: Set<Int32> = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let configStore = FileConfigStore()
        let windowProvider = SystemWindowProvider(configStore: configStore, dockVisibleHeight: dockVisibleHeight)
        let actionHandler = AXActionHandler(configStore: configStore)
        let windowFilter = StandardWindowFilter()
        
        self.dockService = DockService(
            windowProvider: windowProvider,
            configStore: configStore,
            actionHandler: actionHandler,
            windowFilter: windowFilter
        )
        
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
            button.image = NSImage(systemSymbolName: "menubar.dock.rectangle", accessibilityDescription: "Dock2")
        }
        updateMenu()
    }
    
    private func updateMenu() {
        let menu = NSMenu()
        let toggleTitle = isManuallyHidden ? "Show Dock2" : "Hide Dock2"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleVisibility), keyEquivalent: "h")
        menu.addItem(toggleItem)
        
        let cfg = dockService.loadConfig()
        let hideGhost = cfg.hideGhostWindows ?? true
        let spaceAware = cfg.spaceAwareMinimizedWindows ?? true
        
        let hideItem = NSMenuItem(title: "Hide ghost windows", action: #selector(toggleHideGhostWindows), keyEquivalent: "")
        hideItem.state = hideGhost ? .on : .off
        menu.addItem(hideItem)

        let spaceAwareItem = NSMenuItem(title: "Space-aware minimized windows", action: #selector(toggleSpaceAwareMinimizedWindows), keyEquivalent: "")
        spaceAwareItem.state = spaceAware ? .on : .off
        menu.addItem(spaceAwareItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Dock2", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc private func toggleVisibility() {
        isManuallyHidden.toggle()
        updateMenu()
        
        if !isManuallyHidden {
            refreshWindows()
            window.orderFront(nil)
        }
        
        animateWindowPosition()
    }
    
    @objc private func toggleHideGhostWindows() {
        dockService.updateConfig { config in
            config.hideGhostWindows = !(config.hideGhostWindows ?? true)
        }
        updateMenu()
        refreshWindows()
    }

    @objc private func toggleSpaceAwareMinimizedWindows() {
        dockService.updateConfig { config in
            config.spaceAwareMinimizedWindows = !(config.spaceAwareMinimizedWindows ?? true)
        }
        updateMenu()
        refreshWindows()
    }
    
    private func animateWindowPosition() {
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let currentScreen = screen else { return }
        
        let screenFrame = currentScreen.frame
        let barHeight: CGFloat = 64
        let bottomMargin: CGFloat = 0
        
        let targetY = isManuallyHidden ? (screenFrame.minY - barHeight) : (screenFrame.minY + bottomMargin)
        let newFrame = NSRect(x: screenFrame.minX, y: targetY, width: screenFrame.width, height: barHeight)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
    }

    private func setupWindow() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        
        let rect = NSRect(x: screenFrame.origin.x, y: screenFrame.origin.y, width: screenFrame.width, height: dockVisibleHeight)
        
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
        
        taskbarView.onHoverChange = { [weak self] pid, isHovering in
            guard let self = self else { return }
            if isHovering {
                self.hoveredPids.insert(pid)
            } else {
                self.hoveredPids.remove(pid)
            }
            self.refreshWindows()
        }
        
        taskbarView.autoresizingMask = [.width, .height]
        window.contentView = taskbarView
        
        window.orderFrontRegardless()
    }

    @objc private func refreshWindows() {
        if isManuallyHidden { return }
        
        let filteredWindows = dockService.getVisibleWindows(hoveredPids: hoveredPids)
        
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenHeight = screen.frame.height
        let screenWidth = screen.frame.width
        
        dockService.constrainWindows(
            windows: filteredWindows,
            screenHeight: Double(screenHeight),
            screenWidth: Double(screenWidth),
            dockHeight: Double(dockVisibleHeight)
        )
        
        taskbarView.updateWindows(filteredWindows) { [weak self] model, action in
            self?.dockService.perform(action, on: model)
            
            if case .reorder = action {
                self?.refreshWindows()
            }
        }
    }
}
