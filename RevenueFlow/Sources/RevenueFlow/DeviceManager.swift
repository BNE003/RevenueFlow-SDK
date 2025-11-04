import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Manages device identification and name generation
@MainActor
internal final class DeviceManager {

    // MARK: - Constants

    private static let deviceIDKey = "com.revenueflow.device_id"
    private static let deviceNameKey = "com.revenueflow.device_name"

    // Name generation lists
    private static let adjectives = [
        "Schneller", "Kluger", "Mutiger", "Freundlicher", "Starker",
        "Weiser", "Fröhlicher", "Ruhiger", "Bunter", "Magischer",
        "Glänzender", "Wilder", "Sanfter", "Tapferer", "Stolzer",
        "Neugieriger", "Flotter", "Cooler", "Süßer", "Cleverer"
    ]

    private static let animals = [
        "Panda", "Fuchs", "Bär", "Löwe", "Tiger",
        "Adler", "Delfin", "Wolf", "Eule", "Falke",
        "Elefant", "Pinguin", "Leopard", "Drache", "Einhorn",
        "Phönix", "Koala", "Otter", "Luchs", "Gepard"
    ]

    // MARK: - Properties

    private let deviceID: String
    private let deviceName: String

    // MARK: - Singleton

    static let shared = DeviceManager()

    // MARK: - Initialization

    private init() {
        // Get or create device ID
        if let existingID = UserDefaults.standard.string(forKey: Self.deviceIDKey) {
            self.deviceID = existingID
            RFLogger.shared.debug("Loaded existing device ID: \(existingID)")
        } else {
            // Try to get IDFV (iOS only)
            if let idfv = Self.getIDFV() {
                self.deviceID = idfv
                RFLogger.shared.debug("Using IDFV as device ID: \(idfv)")
            } else {
                // Fallback to generated UUID
                self.deviceID = UUID().uuidString
                RFLogger.shared.debug("Generated new UUID as device ID: \(self.deviceID)")
            }

            // Save to UserDefaults
            UserDefaults.standard.set(self.deviceID, forKey: Self.deviceIDKey)
        }

        // Get or create device name
        if let existingName = UserDefaults.standard.string(forKey: Self.deviceNameKey) {
            self.deviceName = existingName
            RFLogger.shared.debug("Loaded existing device name: \(existingName)")
        } else {
            self.deviceName = Self.generateDeviceName()
            UserDefaults.standard.set(self.deviceName, forKey: Self.deviceNameKey)
            RFLogger.shared.info("Generated new device name: \(self.deviceName)")
        }

        RFLogger.shared.info("DeviceManager initialized - ID: \(deviceID), Name: \(deviceName)")
    }

    // MARK: - Public Methods

    /// Get the unique device ID
    var id: String {
        return deviceID
    }

    /// Get the friendly device name
    var name: String {
        return deviceName
    }

    // MARK: - Private Methods

    /// Get IDFV on iOS devices (already on Main Actor)
    private static func getIDFV() -> String? {
        #if canImport(UIKit) && !os(watchOS)
        return UIDevice.current.identifierForVendor?.uuidString
        #else
        return nil
        #endif
    }

    /// Generate a random friendly device name from two lists
    private static func generateDeviceName() -> String {
        let adjective = adjectives.randomElement() ?? "Besonderer"
        let animal = animals.randomElement() ?? "Bär"
        return "\(adjective) \(animal)"
    }

    /// Reset device ID and name (for testing purposes)
    func resetDevice() {
        UserDefaults.standard.removeObject(forKey: Self.deviceIDKey)
        UserDefaults.standard.removeObject(forKey: Self.deviceNameKey)
        RFLogger.shared.warning("Device ID and name have been reset")
    }
}
