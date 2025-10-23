# RevenueFlow SDK - Integration Example

This document shows how to integrate the RevenueFlow SDK into your iOS app.

## Important Note

RevenueFlow connects to a **fixed backend** - you don't need to set up any database or backend infrastructure! The SDK automatically sends all purchase data to RevenueFlow's Supabase instance.

## Installation

Add RevenueFlow as a Swift Package dependency to your project:

1. In Xcode, go to File → Add Package Dependencies
2. Enter the repository URL
3. Select the version you want to use

## Basic Setup

### SwiftUI App

```swift
import SwiftUI
import RevenueFlow

@main
struct MyApp: App {
    init() {
        // Initialize RevenueFlow - this is all you need!
        RevenueFlow.shared.configure(
            appId: "your-app-id-here",
            debugMode: true // Set to false in production
        )
        // That's it! Purchases are now automatically tracked and sent to RevenueFlow's backend
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### UIKit App (AppDelegate)

```swift
import UIKit
import RevenueFlow

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Initialize RevenueFlow
        RevenueFlow.shared.configure(
            appId: "your-app-id-here",
            debugMode: true
        )

        return true
    }
}
```

## That's It!

Once configured, RevenueFlow will **automatically**:
- ✅ Monitor all StoreKit 2 transactions
- ✅ Detect purchases made anywhere in your app
- ✅ Process existing entitlements on first launch
- ✅ Send purchase data to RevenueFlow's backend in real-time

**You don't need to add any code to your purchase flow!**
**You don't need to set up any backend infrastructure!**

## Example Purchase Flow (Your Existing Code)

The SDK works with your existing StoreKit code without any changes:

```swift
import StoreKit
import RevenueFlow

class StoreManager: ObservableObject {
    @Published var products: [Product] = []

    func loadProducts() async {
        do {
            let productIds = ["com.yourapp.premium", "com.yourapp.coins100"]
            products = try await Product.products(for: productIds)
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    func purchase(_ product: Product) async throws {
        // Just use normal StoreKit 2 code
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue

            // RevenueFlow automatically detects this purchase!
            // No need to manually report it.

            await transaction.finish()
            print("Purchase successful!")

        case .userCancelled:
            print("User cancelled")

        case .pending:
            print("Purchase pending")

        @unknown default:
            break
        }
    }
}
```

## Advanced Usage

### Manual Transaction Reporting

In rare cases, you might want to manually report a transaction:

```swift
import StoreKit
import RevenueFlow

func manuallyReportPurchase() async {
    // Get a transaction somehow
    for await result in Transaction.currentEntitlements {
        if case .verified(let transaction) = result {
            do {
                try await RevenueFlow.shared.manuallyReportTransaction(transaction)
                print("Transaction manually reported!")
            } catch {
                print("Failed to report: \(error)")
            }
            break
        }
    }
}
```

### Check Configuration Status

```swift
if RevenueFlow.shared.configured {
    print("RevenueFlow is configured and running ✅")
}
```

### Stop/Start Monitoring

```swift
// Stop monitoring (rarely needed)
RevenueFlow.shared.stopMonitoring()

// Restart monitoring
RevenueFlow.shared.startMonitoring()
```

## Testing with StoreKit Configuration

1. Create a StoreKit Configuration file in Xcode:
   - File → New → File → StoreKit Configuration File

2. Add test products with IDs matching your app

3. Run your app in the simulator

4. Make test purchases

5. Check the console logs for RevenueFlow debug messages:
   ```
   [RevenueFlow Info] RevenueFlow configured with appId: XYZ-123
   [RevenueFlow Info] Transaction monitoring started
   [RevenueFlow Debug] Processing transaction: 12345
   [RevenueFlow Debug]   Product: com.yourapp.premium
   [RevenueFlow Info] Successfully processed purchase: com.yourapp.premium
   ```

## What Gets Tracked?

The SDK automatically tracks:
- Product ID
- Transaction ID
- Purchase date
- App ID (that you configured)
- Environment (production/sandbox/xcode)
- User ID (optional, can be added later)

## Requirements

- iOS 15.0+ (for StoreKit 2)
- Swift 5.5+
- Xcode 13.0+

## Support

For issues or questions, please refer to the main README or open an issue on GitHub.
