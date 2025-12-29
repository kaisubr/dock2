
import AppKit

struct WindowInfo {
    let id: CGWindowID
    let pid: Int32
    let ownerName: String
    let title: String
    let firstLetter: String
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
        self.firstLetter = String(owner.prefix(1)).uppercased()
        self.isMinimized = false
    }
    
    var displayName: String {
        return "[\(firstLetter)] \(title)"
    }
}
