
import AppKit

struct WindowInfo: Equatable {
    let id: CGWindowID
    let pid: Int32
    let ownerName: String
    let title: String
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
        // If title is empty, use owner name as title and "System" or similar as owner
        self.title = rawTitle.isEmpty ? owner : rawTitle
        self.isMinimized = false
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        return lhs.id == rhs.id && lhs.isMinimized == rhs.isMinimized && lhs.title == rhs.title
    }
}
