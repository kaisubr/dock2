
import AppKit

struct WindowInfo: Equatable {
    let id: CGWindowID
    let pid: Int32
    let ownerName: String
    let title: String
    let icon: NSImage?
    var isMinimized: Bool
    
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
        self.title = rawTitle.isEmpty ? owner : rawTitle
        self.isMinimized = false
        
        // Fetch the application icon
        if let app = NSRunningApplication(processIdentifier: pid) {
            self.icon = app.icon
        } else {
            self.icon = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericApplicationIcon)))
        }
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        return lhs.id == rhs.id && lhs.isMinimized == rhs.isMinimized && lhs.title == rhs.title
    }
}
