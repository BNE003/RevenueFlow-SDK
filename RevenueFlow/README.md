# RevenueFlow SDK

A lightweight Swift SDK for automatically detecting and tracking StoreKit purchases in real-time, similar to RevenueCat but much simpler.

## Features

✅ **Automatic Purchase Detection** - Monitors all StoreKit 2 transactions app-wide
✅ **Zero Integration Overhead** - Just one line to configure, no changes to purchase flow
✅ **Fixed Backend** - Connects directly to RevenueFlow's Supabase (no user setup needed)
✅ **StoreKit 2 Native** - Built on modern StoreKit 2 APIs
✅ **Real-time Tracking** - Detects purchases immediately via `Transaction.updates`
✅ **Existing Purchases** - Processes current entitlements on first launch
✅ **Clean Error Handling** - Comprehensive error types and logging
✅ **Debug Mode** - Built-in logging for easy debugging
✅ **Production Ready** - Clean, well-documented Swift code

## Requirements

- iOS 15.0+ / macOS 12.0+ / watchOS 8.0+ / tvOS 15.0+
- Swift 5.5+
- Xcode 13.0+

## Quick Start

### 1. Installation

Add RevenueFlow as a Swift Package dependency in Xcode:

```
File → Add Package Dependencies → Enter repository URL
```

### 2. Configuration

Add **one line** to your app initialization:

#### SwiftUI App

```swift
import SwiftUI
import RevenueFlow

@main
struct MyApp: App {
    init() {
        // That's it! 🎉
        RevenueFlow.shared.configure(appId: "your-app-id-here")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### UIKit App

```swift
import UIKit
import RevenueFlow

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        RevenueFlow.shared.configure(appId: "your-app-id-here")
        return true
    }
}
```

### 3. Done!

RevenueFlow will now automatically:
- Monitor all purchases made in your app
- Process existing entitlements
- Track transaction details
- Send data to RevenueFlow's backend (Supabase)

**You don't need to change any of your existing StoreKit code!**
**No backend setup needed - everything connects to RevenueFlow's fixed backend!**

## How It Works

RevenueFlow uses StoreKit 2's powerful APIs to automatically detect purchases:

- **`Transaction.updates`** - Listens for new purchases in real-time
- **`Transaction.currentEntitlements`** - Processes existing purchases on launch
- **Automatic Verification** - Validates transaction signatures
- **Transaction Finishing** - Properly finishes transactions after processing

## Configuration Options

### Basic Configuration

```swift
RevenueFlow.shared.configure(appId: "XYZ-123")
```

### With Debug Logging

```swift
RevenueFlow.shared.configure(
    appId: "XYZ-123",
    debugMode: true  // Enable detailed console logs
)
```


## What Gets Tracked

For each purchase, RevenueFlow tracks:

- **Product ID** - e.g., "com.yourapp.premium"
- **Transaction ID** - Unique identifier from StoreKit
- **Purchase Date** - When the purchase occurred
- **App ID** - Your configured app identifier
- **Environment** - production, sandbox, or xcode
- **User ID** - (Optional, to be added)

## Advanced Usage

### Manual Transaction Reporting

In rare cases, you can manually report a transaction:

```swift
try await RevenueFlow.shared.manuallyReportTransaction(transaction)
```

### Check SDK Status

```swift
if RevenueFlow.shared.configured {
    print("SDK is configured and monitoring purchases!")
}
```

### Control Monitoring

```swift
// Stop monitoring (rarely needed)
RevenueFlow.shared.stopMonitoring()

// Restart monitoring
RevenueFlow.shared.startMonitoring()
```

## Testing

### With StoreKit Configuration

1. Create a StoreKit Configuration file in Xcode
2. Add test products
3. Run your app in simulator
4. Make test purchases
5. Check console logs for RevenueFlow activity

### Example Console Output

```
[RevenueFlow Info] RevenueFlow configured with appId: XYZ-123
[RevenueFlow Info] Transaction monitoring started
[RevenueFlow Debug] Processing transaction: 12345
[RevenueFlow Debug]   Product: com.yourapp.premium
[RevenueFlow Info] Successfully processed purchase: com.yourapp.premium
```

## Architecture

RevenueFlow is built with clean, modular architecture:

```
RevenueFlow/
├── RevenueFlow.swift       # Main SDK singleton
├── TransactionMonitor.swift # StoreKit transaction monitoring
├── Models.swift            # Data models and types
├── Logger.swift            # Debug logging system
└── SupabaseClient.swift    # Direct Supabase database integration
```

## Architecture

The SDK connects directly to a **fixed RevenueFlow Supabase database** - no configuration needed!

- **No backend setup required** - Everything is handled automatically
- **Direct database access** - Uses Supabase Swift SDK for real-time inserts
- **Secure connection** - Built-in credentials for RevenueFlow's Supabase instance
- **Privacy-first** - Only essential purchase data is transmitted
- **Offline resilient** - Graceful handling of network issues

## Roadmap

- [x] Automatic StoreKit 2 transaction monitoring
- [x] Real-time purchase detection
- [x] Current entitlements processing
- [x] Clean error handling and logging
- [x] Fixed Supabase backend integration
- [ ] User identification support
- [ ] Subscription status tracking
- [ ] Receipt validation
- [ ] Analytics dashboard
- [ ] Retry logic for failed uploads

## Documentation

For detailed integration examples, see [INTEGRATION_EXAMPLE.md](INTEGRATION_EXAMPLE.md)

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

[Add your license here]

## Support

For questions or issues, please open an issue on GitHub.

---

Built with ❤️ using Swift and StoreKit 2
