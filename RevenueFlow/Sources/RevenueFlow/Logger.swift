import Foundation
import os.log

/// Internal logger for RevenueFlow SDK
internal final class RFLogger: @unchecked Sendable {

    static let shared = RFLogger()

    private let subsystem = "com.revenueflow.sdk"
    private let logger: OSLog
    private var debugMode: Bool = false

    private init() {
        self.logger = OSLog(subsystem: subsystem, category: "RevenueFlow")
    }

    func configure(debugMode: Bool) {
        self.debugMode = debugMode
    }

    /// Log debug information
    func debug(_ message: String) {
        guard debugMode else { return }
        os_log(.debug, log: logger, "%{public}@", message)
        print("[RevenueFlow Debug] \(message)")
    }

    /// Log general info
    func info(_ message: String) {
        os_log(.info, log: logger, "%{public}@", message)
        if debugMode {
            print("[RevenueFlow Info] \(message)")
        }
    }

    /// Log errors
    func error(_ message: String, error: Error? = nil) {
        let fullMessage = error != nil ? "\(message): \(error!.localizedDescription)" : message
        os_log(.error, log: logger, "%{public}@", fullMessage)
        print("[RevenueFlow Error] \(fullMessage)")
    }

    /// Log warnings
    func warning(_ message: String) {
        os_log(.default, log: logger, "[WARNING] %{public}@", message)
        if debugMode {
            print("[RevenueFlow Warning] \(message)")
        }
    }
}
