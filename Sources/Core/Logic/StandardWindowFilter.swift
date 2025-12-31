
import Foundation

public class StandardWindowFilter: WindowFilter {
    
    public init() {}

    public func filterAndSort(windows: [WindowModel], config: DockConfig, hoveredPids: Set<Int32>) -> [WindowModel] {
        let hideGhost = config.hideGhostWindows ?? true
        
        
        let grouped = Dictionary(grouping: windows, by: { $0.pid })
        var visibleIDs = Set<UInt32>()
        
        for (pid, appWindows) in grouped {
            let isHovered = hoveredPids.contains(pid)
            let hasTitledWindow = appWindows.contains { $0.hasTitle }
            
            for win in appWindows {
                if isHovered {
                    
                    visibleIDs.insert(win.id)
                } else {
                    if hideGhost {
                        if win.hasTitle {
                            visibleIDs.insert(win.id)
                        } else {
                            
                            
                            if !hasTitledWindow {
                                visibleIDs.insert(win.id)
                            }
                        }
                    } else {
                        visibleIDs.insert(win.id)
                    }
                }
            }
        }
        
        var filtered = windows.filter { visibleIDs.contains($0.id) }
        
        
        filtered.sort {
            if $0.orderPriority != $1.orderPriority {
                return $0.orderPriority < $1.orderPriority
            }
            if $0.ownerName.lowercased() != $1.ownerName.lowercased() {
                return $0.ownerName.lowercased() < $1.ownerName.lowercased()
            }
            return $0.title.lowercased() < $1.title.lowercased()
        }
        
        return filtered
    }
}
