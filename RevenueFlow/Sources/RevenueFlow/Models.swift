import Foundation
import StoreKit

// MARK: - Configuration

/// Configuration for RevenueFlow SDK
public struct RevenueFlowConfiguration {
    /// Your unique app identifier
    public let appId: String

    /// Supabase configuration (to be added later)
    var supabaseURL: String?
    var supabaseAnonKey: String?

    /// Enable debug logging
    public let debugMode: Bool

    public init(appId: String, debugMode: Bool = false) {
        self.appId = appId
        self.debugMode = debugMode
    }
}

// MARK: - Device Data

/// Represents a device record to be sent to Supabase
internal struct DeviceRecord: Codable {
    let deviceId: String
    let appId: String
    let name: String
    let firstSeenAt: Date?
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case appId = "app_id"
        case name
        case firstSeenAt = "first_seen_at"
        case lastSeenAt = "last_seen_at"
    }
}

/// Response from device registration/update
internal struct DeviceResponse: Codable {
    let id: String
    let deviceId: String
    let appId: String
    let name: String
    let firstSeenAt: Date
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case appId = "app_id"
        case name
        case firstSeenAt = "first_seen_at"
        case lastSeenAt = "last_seen_at"
    }
}

// MARK: - Purchase Data

/// Represents a purchase record to be sent to Supabase
public struct PurchaseRecord: Codable {
    let appId: String
    let userId: String?
    let deviceId: String?
    let productId: String
    let transactionId: String
    let purchaseDate: Date
    let environment: String
    let price: Decimal
    let expirationDate: Date?
    let isTrial: Bool

    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case userId = "user_id"
        case deviceId = "device_id"
        case productId = "product_id"
        case transactionId = "transaction_id"
        case purchaseDate = "purchase_date"
        case environment
        case price
        case expirationDate = "expiration_date"
        case isTrial = "is_trial"
    }
}

// MARK: - Session Data

/// Represents an active session record to be sent to Supabase
internal struct SessionRecord: Codable {
    let deviceId: String
    let appId: String
    let lastHeartbeat: Date
    let countryCode: String?
    let region: String?
    let city: String?
    let sessionStartedAt: Date

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case appId = "app_id"
        case lastHeartbeat = "last_heartbeat"
        case countryCode = "country_code"
        case region
        case city
        case sessionStartedAt = "session_started_at"
    }
}

/// Response from session creation/update
internal struct SessionResponse: Codable {
    let id: String
    let deviceId: String
    let appId: String
    let lastHeartbeat: Date
    let countryCode: String?
    let region: String?
    let city: String?
    let sessionStartedAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case appId = "app_id"
        case lastHeartbeat = "last_heartbeat"
        case countryCode = "country_code"
        case region
        case city
        case sessionStartedAt = "session_started_at"
        case createdAt = "created_at"
    }
}

/// Response from Edge Function session creation
internal struct EdgeFunctionSessionRequest: Codable {
    let deviceId: String
    let appId: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case appId = "app_id"
    }
}

internal struct EdgeFunctionSessionResponse: Codable {
    let sessionId: String
    let countryCode: String?
    let region: String?
    let city: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case countryCode = "country_code"
        case region
        case city
    }
}

// MARK: - Errors

/// Errors that can occur in RevenueFlow
public enum RevenueFlowError: Error, LocalizedError {
    case notConfigured
    case transactionVerificationFailed
    case supabaseNotConfigured
    case networkError(Error)
    case invalidTransaction
    case unknownError(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "RevenueFlow is not configured. Call configure(appId:) first."
        case .transactionVerificationFailed:
            return "Failed to verify transaction signature."
        case .supabaseNotConfigured:
            return "Supabase credentials not configured."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidTransaction:
            return "Invalid or incomplete transaction data."
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Transaction Environment

extension Transaction {
    /// Helper to get environment as string
    var environmentString: String {
        if #available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *) {
            switch self.environment {
            case .production:
                return "production"
            case .sandbox:
                return "sandbox"
            case .xcode:
                return "xcode"
            default:
                return "unknown"
            }
        } else {
            // For iOS 15, we can't determine the environment
            // Default to "sandbox" for safety in older versions
            return "sandbox"
        }
    }
}
