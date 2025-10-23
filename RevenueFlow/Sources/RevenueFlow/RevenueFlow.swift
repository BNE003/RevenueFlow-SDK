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
    private let supabaseClient = RFSupabaseClient()
    private var isConfigured = false

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
    ///
    /// - Example:
    /// ```swift
    /// RevenueFlow.shared.configure(appId: "XYZ-123", debugMode: true)
    /// ```
    ///
    public func configure(appId: String, debugMode: Bool = false) {
        guard !isConfigured else {
            RFLogger.shared.warning("RevenueFlow is already configured. Ignoring duplicate configuration.")
            return
        }

        let config = RevenueFlowConfiguration(appId: appId, debugMode: debugMode)
        self.configuration = config

        // Configure logger
        RFLogger.shared.configure(debugMode: debugMode)
        RFLogger.shared.info("RevenueFlow configured with appId: \(appId)")

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

    /// Stop monitoring transactions
    ///
    /// Call this if you need to stop the SDK from monitoring transactions.
    /// This is typically not needed unless you're testing or need to temporarily
    /// disable the SDK.
    ///
    public func stopMonitoring() {
        transactionMonitor?.stopMonitoring()
        RFLogger.shared.info("RevenueFlow monitoring stopped")
    }

    /// Restart monitoring transactions
    ///
    /// Restart transaction monitoring after it has been stopped.
    ///
    public func startMonitoring() {
        guard isConfigured else {
            RFLogger.shared.error("Cannot start monitoring - SDK not configured")
            return
        }

        transactionMonitor?.startMonitoring()
        RFLogger.shared.info("RevenueFlow monitoring restarted")
    }
}
