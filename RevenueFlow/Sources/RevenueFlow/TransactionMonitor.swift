import Foundation
import StoreKit

/// Monitors StoreKit 2 transactions and processes them
internal final class TransactionMonitor: @unchecked Sendable {

    private let appId: String
    private let supabaseClient: RFSupabaseClient
    private var transactionUpdateTask: Task<Void, Error>?
    private var processedTransactionIds = Set<UInt64>()

    init(appId: String, supabaseClient: RFSupabaseClient) {
        self.appId = appId
        self.supabaseClient = supabaseClient
    }

    /// Start monitoring for new transactions
    func startMonitoring() {
        RFLogger.shared.info("Starting transaction monitoring...")

        // Process any existing current entitlements
        Task {
            await checkCurrentEntitlements()
        }

        // Start listening for new transaction updates
        transactionUpdateTask = Task.detached { [weak self] in
            guard let self = self else { return }

            for await verificationResult in Transaction.updates {
                await self.handleTransaction(verificationResult)
            }
        }

        RFLogger.shared.info("Transaction monitoring started")
    }

    /// Stop monitoring transactions
    func stopMonitoring() {
        transactionUpdateTask?.cancel()
        transactionUpdateTask = nil
        RFLogger.shared.info("Transaction monitoring stopped")
    }

    /// Check and process current entitlements (purchases that already exist)
    private func checkCurrentEntitlements() async {
        RFLogger.shared.debug("Checking current entitlements...")

        var count = 0
        for await verificationResult in Transaction.currentEntitlements {
            await handleTransaction(verificationResult)
            count += 1
        }

        RFLogger.shared.debug("Processed \(count) existing entitlements")
    }

    /// Handle a transaction verification result
    /// - Parameter verificationResult: The transaction verification result from StoreKit
    private func handleTransaction(_ verificationResult: VerificationResult<Transaction>) async {
        do {
            let transaction = try verificationResult.payloadValue

            // Check if we've already processed this transaction
            guard !processedTransactionIds.contains(transaction.id) else {
                RFLogger.shared.debug("Transaction \(transaction.id) already processed, skipping")
                return
            }

            RFLogger.shared.debug("Processing transaction: \(transaction.id)")
            RFLogger.shared.debug("  Product: \(transaction.productID)")
            RFLogger.shared.debug("  Purchase Date: \(transaction.purchaseDate)")
            RFLogger.shared.debug("  Environment: \(transaction.environmentString)")

            // Create purchase record
            let purchaseRecord = createPurchaseRecord(from: transaction)

            // Send to Supabase (currently stub)
            try await supabaseClient.sendPurchase(purchaseRecord)

            // Mark transaction as processed
            processedTransactionIds.insert(transaction.id)

            // Finish the transaction (important!)
            await transaction.finish()

            RFLogger.shared.info("Successfully processed purchase: \(transaction.productID)")

        } catch {
            RFLogger.shared.error("Failed to handle transaction", error: error)
        }
    }

    /// Create a PurchaseRecord from a StoreKit Transaction
    /// - Parameter transaction: The StoreKit transaction
    /// - Returns: A PurchaseRecord ready to be sent to Supabase
    private func createPurchaseRecord(from transaction: Transaction) -> PurchaseRecord {
        return PurchaseRecord(
            appId: appId,
            userId: nil, // Can be set later if you have user identification
            productId: transaction.productID,
            transactionId: String(transaction.id),
            purchaseDate: transaction.purchaseDate,
            environment: transaction.environmentString
        )
    }

    /// Manually report a transaction (helper function for manual reporting)
    /// - Parameter transaction: The transaction to report
    func manuallyReportTransaction(_ transaction: Transaction) async throws {
        let purchaseRecord = createPurchaseRecord(from: transaction)
        try await supabaseClient.sendPurchase(purchaseRecord)
        processedTransactionIds.insert(transaction.id)
        RFLogger.shared.info("Manually reported transaction: \(transaction.id)")
    }

    deinit {
        stopMonitoring()
    }
}
