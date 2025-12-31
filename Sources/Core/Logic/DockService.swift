
import Foundation
import CoreGraphics

public class DockService {
    private let windowProvider: WindowProvider
    private let configStore: ConfigStore
    private let actionHandler: ActionHandler
    private let windowFilter: WindowFilter
    
    private var pendingResizes: Set<UInt32> = []
    private let resizeLock = NSLock()
    
    public init(windowProvider: WindowProvider, configStore: ConfigStore, actionHandler: ActionHandler, windowFilter: WindowFilter) {
        self.windowProvider = windowProvider
        self.configStore = configStore
        self.actionHandler = actionHandler
        self.windowFilter = windowFilter
    }
    
    public func getVisibleWindows(hoveredPids: Set<Int32>) -> [WindowModel] {
        let windows = windowProvider.getWindows()
        let config = configStore.load()
        return windowFilter.filterAndSort(windows: windows, config: config, hoveredPids: hoveredPids)
    }
    
    public func constrainWindows(windows: [WindowModel], screenHeight: Double, screenWidth: Double, dockHeight: Double) {
        let limitY = screenHeight - dockHeight
        let dockRect = CGRect(x: 0, y: limitY, width: screenWidth, height: dockHeight)
        
        for win in windows {
            guard !win.isMinimized, let rect = win.rect else { continue }
            let winRect = CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
            
            if winRect.intersects(dockRect) && winRect.minY < limitY {
                resizeLock.lock()
                let isPending = pendingResizes.contains(win.id)
                resizeLock.unlock()
                
                if !isPending {
                    resizeLock.lock()
                    pendingResizes.insert(win.id)
                    resizeLock.unlock()
                    
                    actionHandler.constrainWindow(pid: win.pid, id: win.id, limitY: limitY)
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.resizeLock.lock()
                        self?.pendingResizes.remove(win.id)
                        self?.resizeLock.unlock()
                    }
                }
            }
        }
    }
    
    public func perform(_ action: WindowAction, on window: WindowModel) {
        actionHandler.perform(action, on: window)
    }
    
    public func loadConfig() -> DockConfig {
        return configStore.load()
    }
    
    public func updateConfig(_ modifier: (inout DockConfig) -> Void) {
        var config = configStore.load()
        modifier(&config)
        configStore.save(config)
    }
}
