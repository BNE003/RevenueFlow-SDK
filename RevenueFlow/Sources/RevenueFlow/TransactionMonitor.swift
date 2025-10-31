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
            let purchaseRecord = await createPurchaseRecord(from: transaction)

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
    private func createPurchaseRecord(from transaction: Transaction) async -> PurchaseRecord {
        // Extract price from StoreKit product
        let price = await extractPrice(for: transaction.productID)

        // Extract expiration date
        let expirationDate = transaction.expirationDate

        // Determine if this is a trial
        let isTrial = determineIfTrial(transaction: transaction)

        return PurchaseRecord(
            appId: appId,
            userId: nil, // Can be set later if you have user identification
            productId: transaction.productID,
            transactionId: String(transaction.id),
            purchaseDate: transaction.purchaseDate,
            environment: transaction.environmentString,
            price: price,
            expirationDate: expirationDate,
            isTrial: isTrial
        )
    }

    /// Extract price from StoreKit Product
    /// - Parameter productId: The product identifier
    /// - Returns: The price as Decimal, or 0 if unable to fetch
    private func extractPrice(for productId: String) async -> Decimal {
        do {
            let products = try await Product.products(for: [productId])
            guard let product = products.first else {
                RFLogger.shared.warning("Could not find product for ID: \(productId)")
                return 0
            }
            return product.price
        } catch {
            RFLogger.shared.error("Failed to fetch product price for \(productId)", error: error)
            return 0
        }
    }

    /// Determine if a transaction represents a trial
    /// - Parameter transaction: The StoreKit transaction
    /// - Returns: true if this is a trial, false otherwise
    private func determineIfTrial(transaction: Transaction) -> Bool {
        // Check if the transaction has an introductory offer type
        if #available(iOS 15.4, macOS 12.3, watchOS 8.5, tvOS 15.4, *) {
            if let offerType = transaction.offerType {
                switch offerType {
                case .introductory:
                    // This is an introductory offer (free trial or introductory price)
                    return true
                case .promotional:
                    // This is a promotional offer (not a trial)
                    return false
                case .code:
                    // This is an offer code redemption (not a trial)
                    return false
                default:
                    return false
                }
            }
        }

        // If offerType is not available or nil, check if offerID exists
        // If there's an offerID, it's likely a promotional offer, not a trial
        if transaction.offerID != nil {
            return false
        }

        // For iOS < 15.4, we can't reliably determine trial status
        // Default to false to be conservative
        return false
    }

    /// Manually report a transaction (helper function for manual reporting)
    /// - Parameter transaction: The transaction to report
    func manuallyReportTransaction(_ transaction: Transaction) async throws {
        let purchaseRecord = await createPurchaseRecord(from: transaction)
        try await supabaseClient.sendPurchase(purchaseRecord)
        processedTransactionIds.insert(transaction.id)
        RFLogger.shared.info("Manually reported transaction: \(transaction.id)")
    }

    deinit {
        stopMonitoring()
    }
}
