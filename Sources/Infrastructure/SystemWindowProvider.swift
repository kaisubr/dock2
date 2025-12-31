
import AppKit
import CoreGraphics

public class SystemWindowProvider: WindowProvider {
    private let configStore: ConfigStore
    private let dockVisibleHeight: CGFloat
    
    public init(configStore: ConfigStore, dockVisibleHeight: CGFloat) {
        self.configStore = configStore
        self.dockVisibleHeight = dockVisibleHeight
    }
    
    public func getWindows() -> [WindowModel] {
        let onScreenOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let onScreenList = CGWindowListCopyWindowInfo(onScreenOptions, kCGNullWindowID) as? [[String: Any]] ?? []
        
        let onScreenIDs = Set(onScreenList.compactMap { $0[kCGWindowNumber as String] as? UInt32 })
        
        let allOptions: CGWindowListOption = [.excludeDesktopElements, .optionAll]
        guard let allWindows = CGWindowListCopyWindowInfo(allOptions, kCGNullWindowID) as? [[String: Any]] else { return [] }
        
        let currentPID = ProcessInfo.processInfo.processIdentifier
        
        return allWindows.compactMap { dict -> WindowModel? in
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = dict[kCGWindowOwnerPID as String] as? Int32, pid != currentPID,
                  let id = dict[kCGWindowNumber as String] as? UInt32,
                  let ownerName = dict[kCGWindowOwnerName as String] as? String
            else { return nil }
            
            let isOnCurrentSpace = onScreenIDs.contains(id)
            let isMinimized = !isOnCurrentSpace && isWindowMinimized(pid: pid, id: id)
            
            
            if !isOnCurrentSpace && !isMinimized {
                return nil
            }
            
            let rawTitle = dict[kCGWindowName as String] as? String ?? ""
            let hasTitle = !rawTitle.isEmpty
            let title = hasTitle ? rawTitle : ownerName
            
            
            var rect: WindowRect? = nil
            if let boundsDict = dict[kCGWindowBounds as String] as? [String: Any],
               let cgRect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                rect = WindowRect(x: Double(cgRect.origin.x), y: Double(cgRect.origin.y), width: Double(cgRect.width), height: Double(cgRect.height))
            }
            
            
            let bundleID: String
            if let app = NSRunningApplication(processIdentifier: pid) {
                bundleID = app.bundleIdentifier ?? ownerName
            } else {
                bundleID = ownerName
            }
            
            let priority = configStore.getOrderPriority(for: bundleID)
            
            return WindowModel(
                id: id,
                pid: pid,
                ownerName: ownerName,
                title: title,
                bundleIdentifier: bundleID,
                isMinimized: isMinimized,
                hasTitle: hasTitle,
                orderPriority: priority,
                rect: rect
            )
        }
    }
    
    
    @_silgen_name("_AXUIElementGetWindow")
    private func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

    private func isWindowMinimized(pid: Int32, id: UInt32) -> Bool {
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
}
