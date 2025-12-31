
import Foundation

public protocol ConfigStore {
    func load() -> DockConfig
    func save(_ config: DockConfig)
    func getOrderPriority(for bundleIdentifier: String) -> Int
    func setOrderPriority(for bundleIdentifier: String, ownerName: String, priority: Int?)
}
