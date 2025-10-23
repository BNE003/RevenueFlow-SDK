import Foundation
import Supabase

/// Handles communication with the RevenueFlow backend (Supabase)
/// The SDK connects directly to a fixed Supabase database - no user configuration needed
internal final class RFSupabaseClient: @unchecked Sendable {

    // MARK: - Configuration
    // RevenueFlow Backend - Fixed Supabase instance
    private let supabaseURL: String = "https://rwejkegeqvullpsogqsd.supabase.co"
    private let supabaseAnonKey: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ3ZWprZWdlcXZ1bGxwc29ncXNkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyMzU3OTAsImV4cCI6MjA3NjgxMTc5MH0.Tv3ZVlbghHXWkbaVJWJ8c9py9_3h8HpUEoeDmL8s9ms"

    private var client: Supabase.SupabaseClient?

    init() {
        setupClient()
    }

    // MARK: - Setup

    /// Initialize the Supabase client with fixed credentials
    private func setupClient() {
        // Initialize Supabase client with RevenueFlow backend
        client = Supabase.SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseAnonKey
        )
        RFLogger.shared.info("✅ Supabase client initialized and connected to RevenueFlow backend")
    }

    // MARK: - API Methods

    /// Send purchase record to Supabase database
    /// - Parameter record: The purchase record to send
    func sendPurchase(_ record: PurchaseRecord) async throws {
        guard let client = client else {
            // Supabase not configured - just log locally
            logPurchaseLocally(record)
            return
        }

        RFLogger.shared.debug("Sending purchase to Supabase database: \(record.transactionId)")

        do {
            // Insert the purchase record into the 'purchases' table
            try await client
                .from("purchases")
                .insert(record)
                .execute()

            RFLogger.shared.info("✅ Purchase successfully saved to database: \(record.productId)")

        } catch {
            RFLogger.shared.error("Failed to save purchase to database", error: error)
            throw RevenueFlowError.networkError(error)
        }
    }

    // MARK: - Helper Methods

    /// Log purchase locally when Supabase is not configured
    private func logPurchaseLocally(_ record: PurchaseRecord) {
        RFLogger.shared.debug("📦 Purchase detected (local log only):")
        RFLogger.shared.debug("  Transaction ID: \(record.transactionId)")
        RFLogger.shared.debug("  Product: \(record.productId)")
        RFLogger.shared.debug("  Date: \(record.purchaseDate)")
        RFLogger.shared.debug("  Environment: \(record.environment)")
        RFLogger.shared.debug("  App ID: \(record.appId)")
        if let userId = record.userId {
            RFLogger.shared.debug("  User ID: \(userId)")
        }
    }

    /// Check if Supabase is properly configured
    var isConfigured: Bool {
        return client != nil
    }
}

