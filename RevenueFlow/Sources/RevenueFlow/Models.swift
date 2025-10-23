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

// MARK: - Purchase Data

/// Represents a purchase record to be sent to Supabase
public struct PurchaseRecord: Codable {
    let appId: String
    let userId: String?
    let productId: String
    let transactionId: String
    let purchaseDate: Date
    let environment: String

    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case userId = "user_id"
        case productId = "product_id"
        case transactionId = "transaction_id"
        case purchaseDate = "purchase_date"
        case environment
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
