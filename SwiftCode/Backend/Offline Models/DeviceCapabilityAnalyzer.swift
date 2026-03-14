import Foundation

struct DeviceCapabilities {
    let ramGB: Double
    let availableStorageGB: Double
    let processorName: String
}

final class DeviceCapabilityAnalyzer {
    static let shared = DeviceCapabilityAnalyzer()
    private init() {}

    func getCapabilities() -> DeviceCapabilities {
        let ram = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let storage = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemFreeSize] as? Int64
        let storageGB = Double(storage ?? 0) / 1_073_741_824

        return DeviceCapabilities(
            ramGB: ram,
            availableStorageGB: storageGB,
            processorName: "Apple Silicon" // Simplified
        )
    }

    func recommendModelSize() -> String {
        let caps = getCapabilities()
        if caps.ramGB <= 8 {
            return "1B-3B"
        } else if caps.ramGB <= 16 {
            return "3B-7B"
        } else {
            return "7B-14B+"
        }
    }
}
