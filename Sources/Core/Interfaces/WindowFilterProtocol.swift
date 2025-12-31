
import Foundation

public protocol WindowFilter {
    func filterAndSort(windows: [WindowModel], config: DockConfig, hoveredPids: Set<Int32>) -> [WindowModel]
}
