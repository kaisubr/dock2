
import Foundation

public class FileConfigStore: ConfigStore {
    private let configPath: URL
    private var config: DockConfig
    
    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.configPath = home.appendingPathComponent(".dock2rc")
        self.config = DockConfig(applicationConfig: [:])
        self.config = load()
    }
    
    public func load() -> DockConfig {
        guard let data = try? Data(contentsOf: configPath) else { return DockConfig(applicationConfig: [:]) }
        if let decoded = try? JSONDecoder().decode(DockConfig.self, from: data) {
            return decoded
        }
        return DockConfig(applicationConfig: [:])
    }
    
    public func save(_ config: DockConfig) {
        self.config = config
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(config) {
            try? data.write(to: configPath)
        }
    }
    
    public func getOrderPriority(for bundleIdentifier: String) -> Int {
        return config.applicationConfig[bundleIdentifier]?.orderPriority ?? Int.max
    }
    
    public func setOrderPriority(for bundleIdentifier: String, ownerName: String, priority: Int?) {
        if let p = priority {
            var appCfg = config.applicationConfig[bundleIdentifier] ?? AppConfig(realName: ownerName)
            appCfg.orderPriority = p
            appCfg.realName = ownerName
            config.applicationConfig[bundleIdentifier] = appCfg
        } else {
            config.applicationConfig.removeValue(forKey: bundleIdentifier)
        }
        save(config)
    }
}
