
import Foundation

public struct AppConfig: Codable {
    public var realName: String
    public var orderPriority: Int?
    
    public init(realName: String, orderPriority: Int? = nil) {
        self.realName = realName
        self.orderPriority = orderPriority
    }
}

public struct DockConfig: Codable {
    public var applicationConfig: [String: AppConfig]
    public var hideGhostWindows: Bool?
    
    public init(applicationConfig: [String: AppConfig], hideGhostWindows: Bool? = nil) {
        self.applicationConfig = applicationConfig
        self.hideGhostWindows = hideGhostWindows
    }
}
