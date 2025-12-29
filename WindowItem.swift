
import AppKit

struct WindowInfo {
    let id: CGWindowID
    let pid: Int32
    let ownerName: String
    let title: String
    let firstLetter: String
    let isMinimized: Bool
    
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
        // Use window title if available, otherwise use program name
        self.title = rawTitle.isEmpty ? owner : rawTitle
        self.firstLetter = String(owner.prefix(1)).uppercased()
        
        let isOnScreen = dict[kCGWindowIsOnscreen as String] as? Bool ?? false
        self.isMinimized = !isOnScreen
    }
    
    var displayName: String {
        return "[\(firstLetter)] \(title)"
    }
}
