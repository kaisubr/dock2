
import Foundation

public struct WindowModel: Equatable, Identifiable {
    public let id: UInt32
    public let pid: Int32
    public let ownerName: String
    public let title: String
    public let bundleIdentifier: String
    public var isMinimized: Bool
    public let hasTitle: Bool
    public var orderPriority: Int
    public let rect: WindowRect?
    
    public init(id: UInt32, pid: Int32, ownerName: String, title: String, bundleIdentifier: String, isMinimized: Bool, hasTitle: Bool, orderPriority: Int = Int.max, rect: WindowRect? = nil) {
        self.id = id
        self.pid = pid
        self.ownerName = ownerName
        self.title = title
        self.bundleIdentifier = bundleIdentifier
        self.isMinimized = isMinimized
        self.hasTitle = hasTitle
        self.orderPriority = orderPriority
        self.rect = rect
    }
    
    public static func == (lhs: WindowModel, rhs: WindowModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.isMinimized == rhs.isMinimized &&
               lhs.title == rhs.title &&
               lhs.orderPriority == rhs.orderPriority &&
               lhs.rect == rhs.rect
    }
}
