
import Foundation

struct AppConfig: Codable {
    var realName: String 
    var orderPriority: Int?
}

struct DockConfig: Codable {
    var applicationConfig: [String: AppConfig] 
    var hideGhostWindows: Bool?
}

class ConfigManager {
    static let shared = ConfigManager()
    private let configPath: URL
    private var config: DockConfig
    
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.configPath = home.appendingPathComponent(".dock2rc")
        self.config = DockConfig(applicationConfig: [:])
        load()
    }
    
    func load() {
        guard let data = try? Data(contentsOf: configPath) else { return }
        if let decoded = try? JSONDecoder().decode(DockConfig.self, from: data) {
            self.config = decoded
        }
    }
    
    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(config) {
            try? data.write(to: configPath)
        }
    }
    
    func getOrderPriority(for info: WindowInfo) -> Int {
        return config.applicationConfig[info.configKey]?.orderPriority ?? Int.max
    }
    
    func setOrderPriority(for info: WindowInfo, orderPriority: Int?) {
        if let p = orderPriority {
            var appCfg = config.applicationConfig[info.configKey] ?? AppConfig(realName: info.ownerName)
            appCfg.orderPriority = p
            appCfg.realName = info.ownerName 
            config.applicationConfig[info.configKey] = appCfg
        } else {
            config.applicationConfig.removeValue(forKey: info.configKey)
        }
        save()
    }
    
    func getHideGhostWindows() -> Bool {
        return config.hideGhostWindows ?? true
    }
    
    func setHideGhostWindows(_ value: Bool) {
        config.hideGhostWindows = value
        save()
    }
}
