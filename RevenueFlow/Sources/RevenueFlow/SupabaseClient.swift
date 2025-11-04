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

    /// Register or update device in Supabase
    /// - Parameters:
    ///   - deviceId: The unique device identifier
    ///   - appId: The app identifier
    ///   - name: The friendly device name
    /// - Returns: The UUID from the database
    func registerOrUpdateDevice(deviceId: String, appId: String, name: String) async throws -> String {
        guard let client = client else {
            RFLogger.shared.warning("⚠️ Supabase not configured - device not registered")
            throw RevenueFlowError.supabaseNotConfigured
        }

        RFLogger.shared.debug("📱 Attempting to register/update device:")
        RFLogger.shared.debug("   Device ID: \(deviceId)")
        RFLogger.shared.debug("   App ID: \(appId)")
        RFLogger.shared.debug("   Name: \(name)")

        do {
            let now = Date()

            // Try to insert or update (upsert) the device
            let deviceRecord = DeviceRecord(
                deviceId: deviceId,
                appId: appId,
                name: name,
                firstSeenAt: nil, // Will be set by DB default on first insert
                lastSeenAt: now
            )

            RFLogger.shared.debug("🔄 Sending upsert request to Supabase...")

            // Use upsert to insert or update based on device_id uniqueness
            let response: [DeviceResponse] = try await client
                .from("devices")
                .upsert(deviceRecord, onConflict: "device_id")
                .select()
                .execute()
                .value

            RFLogger.shared.debug("📥 Received response from Supabase, parsing...")

            guard let device = response.first else {
                RFLogger.shared.error("❌ No device returned from upsert")
                throw RevenueFlowError.unknownError("No device returned from upsert")
            }

            RFLogger.shared.info("✅ Device registered/updated successfully!")
            RFLogger.shared.info("   Name: \(device.name)")
            RFLogger.shared.info("   UUID: \(device.id)")
            return device.id

        } catch {
            RFLogger.shared.error("❌ Failed to register/update device", error: error)
            RFLogger.shared.error("   Error details: \(error.localizedDescription)")
            throw RevenueFlowError.networkError(error)
        }
    }

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

    // MARK: - Session Management

    /// Start a new active session or update existing one
    /// - Parameters:
    ///   - deviceId: The device UUID from database
    ///   - appId: The app identifier
    /// - Returns: The session UUID from the database
    func startSession(deviceId: String, appId: String) async throws -> String {
        guard let client = client else {
            RFLogger.shared.warning("⚠️ Supabase not configured - session not started")
            throw RevenueFlowError.supabaseNotConfigured
        }

        RFLogger.shared.debug("🚀 Starting session for device: \(deviceId)")

        do {
            let edgePayload = EdgeFunctionSessionRequest(deviceId: deviceId, appId: appId)

            do {
                let response: EdgeFunctionSessionResponse = try await client.functions.invoke(
                    "start-session-with-geo",
                    options: FunctionInvokeOptions(method: .post, body: edgePayload)
                )

                RFLogger.shared.info("🌍 Session geo resolved via Edge Function")
                if let countryCode = response.countryCode {
                    RFLogger.shared.debug("   Country: \(countryCode)")
                }
                if let region = response.region {
                    RFLogger.shared.debug("   Region: \(region)")
                }

                RFLogger.shared.info("✅ Session started via Edge Function with ID: \(response.sessionId)")
                return response.sessionId
            } catch {
                RFLogger.shared.warning("⚠️ Edge Function start-session-with-geo failed, falling back to direct session upsert: \(error.localizedDescription)")
            }

            let now = Date()

            let sessionRecord = SessionRecord(
                deviceId: deviceId,
                appId: appId,
                lastHeartbeat: now,
                countryCode: nil, // Edge function unavailable, no geo data
                region: nil,
                sessionStartedAt: now
            )

            // Upsert based on unique constraint (device_id, app_id)
            let response: [SessionResponse] = try await client
                .from("active_sessions")
                .upsert(sessionRecord, onConflict: "device_id,app_id")
                .select()
                .execute()
                .value

            guard let session = response.first else {
                RFLogger.shared.error("❌ No session returned from upsert")
                throw RevenueFlowError.unknownError("No session returned from upsert")
            }

            RFLogger.shared.info("✅ Session started successfully!")
            RFLogger.shared.info("   Session UUID: \(session.id)")
            return session.id

        } catch {
            RFLogger.shared.error("❌ Failed to start session", error: error)
            throw RevenueFlowError.networkError(error)
        }
    }

    /// Send heartbeat to update session activity
    /// - Parameter sessionId: The session UUID
    func sendHeartbeat(sessionId: String) async throws {
        guard let client = client else {
            RFLogger.shared.debug("⚠️ Supabase not configured - heartbeat not sent")
            return
        }

        RFLogger.shared.debug("💓 Sending heartbeat for session: \(sessionId)")

        do {
            try await client
                .from("active_sessions")
                .update(["last_heartbeat": Date()])
                .eq("id", value: sessionId)
                .execute()

            RFLogger.shared.debug("✅ Heartbeat sent successfully")

        } catch {
            RFLogger.shared.error("❌ Failed to send heartbeat", error: error)
            throw RevenueFlowError.networkError(error)
        }
    }

    /// End an active session
    /// - Parameter sessionId: The session UUID
    func endSession(sessionId: String) async throws {
        guard let client = client else {
            RFLogger.shared.debug("⚠️ Supabase not configured - session not ended")
            return
        }

        RFLogger.shared.debug("🛑 Ending session: \(sessionId)")

        do {
            try await client
                .from("active_sessions")
                .delete()
                .eq("id", value: sessionId)
                .execute()

            RFLogger.shared.info("✅ Session ended successfully")

        } catch {
            RFLogger.shared.error("❌ Failed to end session", error: error)
            throw RevenueFlowError.networkError(error)
        }
    }
}
