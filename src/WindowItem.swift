
import AppKit

struct WindowInfo: Equatable {
    let id: CGWindowID
    let pid: Int32
    let ownerName: String
    let title: String
    let icon: NSImage?
    let configKey: String 
    var isMinimized: Bool
    var orderPriority: Int = Int.max
    let hasTitle: Bool
    
    init?(dict: [String: Any]) {
        guard let id = dict[kCGWindowNumber as String] as? CGWindowID,
              let pid = dict[kCGWindowOwnerPID as String] as? Int32,
              let owner = dict[kCGWindowOwnerName as String] as? String else {
            return nil
        }
        
        self.id = id
        self.pid = pid
        self.ownerName = owner
        
        let rawTitle = dict[kCGWindowName as String] as? String ?? ""
        self.hasTitle = !rawTitle.isEmpty
        self.title = self.hasTitle ? rawTitle : owner
        self.isMinimized = false
        
        if let app = NSRunningApplication(processIdentifier: pid) {
            self.icon = app.icon
            
            self.configKey = app.bundleIdentifier ?? owner
        } else {
            self.icon = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericApplicationIcon)))
            self.configKey = owner
        }
        
        self.orderPriority = ConfigManager.shared.getOrderPriority(for: self)
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        return lhs.id == rhs.id && 
               lhs.isMinimized == rhs.isMinimized && 
               lhs.title == rhs.title && 
               lhs.orderPriority == rhs.orderPriority &&
               lhs.hasTitle == rhs.hasTitle
    }
}
