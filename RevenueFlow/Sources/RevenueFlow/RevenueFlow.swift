import Foundation
import StoreKit

/// # RevenueFlow SDK
///
/// A lightweight Swift SDK for automatically detecting and tracking StoreKit purchases.
///
/// ## Usage
///
/// Configure the SDK in your app's initialization (e.g., in `AppDelegate` or your main `App` struct):
///
/// ```swift
/// RevenueFlow.shared.configure(appId: "your-app-id-here")
/// ```
///
/// The SDK will automatically:
/// - Monitor all StoreKit 2 transactions
/// - Detect purchases made anywhere in your app
/// - Send purchase data to the RevenueFlow backend
///
/// ## Example
///
/// ```swift
/// import RevenueFlow
///
/// @main
/// struct MyApp: App {
///     init() {
///         // Initialize RevenueFlow
///         RevenueFlow.shared.configure(
///             appId: "XYZ-123",
///             debugMode: true
///         )
///     }
///
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///         }
///     }
/// }
/// ```
///
public final class RevenueFlow: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared instance of RevenueFlow
    public static let shared = RevenueFlow()

    // MARK: - Properties

    private var configuration: RevenueFlowConfiguration?
    private var transactionMonitor: TransactionMonitor?
    private var sessionManager: SessionManager?
    private let supabaseClient = RFSupabaseClient()
    private var isConfigured = false
    private var deviceUUID: String?
    private var sessionTrackingEnabled = true

    // MARK: - Initialization

    private init() {
        RFLogger.shared.debug("RevenueFlow SDK initialized")
    }

    // MARK: - Configuration

    /// Configure the RevenueFlow SDK
    ///
    /// Call this method once during your app's initialization, typically in your
    /// `AppDelegate` or main `App` struct.
    ///
    /// - Parameters:
    ///   - appId: Your unique application identifier
    ///   - debugMode: Enable debug logging (default: false)
    ///   - enableSessionTracking: Enable live session tracking (default: true)
    ///
    /// - Example:
    /// ```swift
    /// RevenueFlow.shared.configure(appId: "XYZ-123", debugMode: true)
    /// ```
    ///
    public func configure(appId: String, debugMode: Bool = false, enableSessionTracking: Bool = true) {
        guard !isConfigured else {
            RFLogger.shared.warning("RevenueFlow is already configured. Ignoring duplicate configuration.")
            return
        }

        let config = RevenueFlowConfiguration(appId: appId, debugMode: debugMode)
        self.configuration = config
        self.sessionTrackingEnabled = enableSessionTracking

        // Configure logger
        RFLogger.shared.configure(debugMode: debugMode)
        RFLogger.shared.info("RevenueFlow configured with appId: \(appId)")

        // Initialize session manager
        if enableSessionTracking {
            self.sessionManager = SessionManager(
                appId: appId,
                supabaseClient: supabaseClient
            )
            RFLogger.shared.info("✅ Session tracking enabled")
        } else {
            RFLogger.shared.info("⏭️ Session tracking disabled")
        }

        // Register device asynchronously
        Task {
            await registerDevice(appId: appId)
        }

        // Initialize transaction monitor
        self.transactionMonitor = TransactionMonitor(
            appId: appId,
            supabaseClient: supabaseClient
        )

        // Start monitoring transactions
        transactionMonitor?.startMonitoring()

        isConfigured = true
        RFLogger.shared.info("RevenueFlow is ready")
    }

    // MARK: - Device Registration

    /// Register or update the device in Supabase
    private func registerDevice(appId: String) async {
        RFLogger.shared.debug("Starting device registration...")

        do {
            // Get device info from DeviceManager (on MainActor)
            let deviceId = await MainActor.run { DeviceManager.shared.id }
            let deviceName = await MainActor.run { DeviceManager.shared.name }

            RFLogger.shared.debug("Device info - ID: \(deviceId), Name: \(deviceName)")

            let uuid = try await supabaseClient.registerOrUpdateDevice(
                deviceId: deviceId,
                appId: appId,
                name: deviceName
            )

            self.deviceUUID = uuid
            RFLogger.shared.info("✅ Device registered successfully with UUID: \(uuid)")

            // Update transaction monitor with device UUID
            transactionMonitor?.setDeviceUUID(uuid)

            // Update session manager with device UUID and start session
            if let sessionManager = self.sessionManager {
                sessionManager.setDeviceUUID(uuid)
                sessionManager.startSession()
            }

        } catch {
            RFLogger.shared.error("❌ Failed to register device", error: error)
            // Continue without device UUID - purchases will still work
        }
    }

    /// Get the current device UUID (from database)
    public var currentDeviceUUID: String? {
        return deviceUUID
    }

    /// Get the current device ID (local identifier)
    public var currentDeviceID: String {
        get async {
            await MainActor.run {
                DeviceManager.shared.id
            }
        }
    }

    /// Get the current device name
    public var currentDeviceName: String {
        get async {
            await MainActor.run {
                DeviceManager.shared.name
            }
        }
    }

    // MARK: - Public Helper Methods

    /// Manually report a transaction
    ///
    /// Use this if you need to manually report a specific transaction.
    /// In most cases, the SDK will automatically detect and report all transactions.
    ///
    /// - Parameter transaction: The StoreKit Transaction to report
    /// - Throws: RevenueFlowError if the SDK is not configured or the transaction cannot be processed
    ///
    public func manuallyReportTransaction(_ transaction: Transaction) async throws {
        guard isConfigured else {
            throw RevenueFlowError.notConfigured
        }

        guard let monitor = transactionMonitor else {
            throw RevenueFlowError.notConfigured
        }

        try await monitor.manuallyReportTransaction(transaction)
    }

    /// Check if the SDK is properly configured
    ///
    /// - Returns: `true` if the SDK has been configured with an app ID
    ///
    public var configured: Bool {
        return isConfigured
    }


    // MARK: - Lifecycle

    /// Stop monitoring transactions and session tracking
    ///
    /// Call this if you need to stop the SDK from monitoring transactions.
    /// This is typically not needed unless you're testing or need to temporarily
    /// disable the SDK.
    ///
    public func stopMonitoring() {
        transactionMonitor?.stopMonitoring()
        sessionManager?.stopSession()
        RFLogger.shared.info("RevenueFlow monitoring stopped")
    }

    /// Restart monitoring transactions and session tracking
    ///
    /// Restart transaction monitoring after it has been stopped.
    ///
    public func startMonitoring() {
        guard isConfigured else {
            RFLogger.shared.error("Cannot start monitoring - SDK not configured")
            return
        }

        transactionMonitor?.startMonitoring()
        if sessionTrackingEnabled {
            sessionManager?.startSession()
        }
        RFLogger.shared.info("RevenueFlow monitoring restarted")
    }

    // MARK: - Session Info

    /// Get the current session ID
    ///
    /// - Returns: The current session UUID, or nil if no active session
    ///
    public var currentSessionId: String? {
        return sessionManager?.currentSessionId
    }

    /// Check if session tracking is currently active
    ///
    /// - Returns: `true` if session tracking is active
    ///
    public var isSessionActive: Bool {
        return sessionManager?.isSessionActive ?? false
    }
}
