# 🚀 RevenueFlow - Getting Started

Ein kompletter Guide, um RevenueFlow in 5 Minuten zum Laufen zu bringen.

## 📋 Übersicht

RevenueFlow ist wie RevenueCat, nur viel einfacher:
- ✅ **1 Zeile Code** - Mehr brauchst du nicht in deiner App
- ✅ **Automatische Erkennung** - Alle StoreKit-Käufe werden erfasst
- ✅ **Fixed Backend** - Keine Backend-Konfiguration nötig
- ✅ **Real-time** - Käufe landen sofort in deiner Datenbank

## 🗓️ Setup-Schritte (5 Minuten)

### Schritt 1: Datenbank einrichten (2 Minuten)

1. Öffne [Supabase Dashboard](https://app.supabase.com)
2. Wähle dein Projekt: `rwejkegeqvullpsogqsd`
3. Gehe zu **SQL Editor**
4. Öffne `database_setup.sql` aus diesem Repo
5. Kopiere alles und führe es aus
6. ✅ Fertig!

👉 Detaillierte Anleitung: [DATABASE_SETUP.md](DATABASE_SETUP.md)

### Schritt 2: SDK in dein Xcode-Projekt einbinden (2 Minuten)

1. Öffne dein Xcode-Projekt
2. Gehe zu **File → Add Package Dependencies**
3. Füge die RevenueFlow-URL ein
4. Wähle "Up to Next Major Version"
5. Klicke **Add Package**

### Schritt 3: SDK konfigurieren (1 Minute)

**SwiftUI:**
```swift
import SwiftUI
import RevenueFlow

@main
struct YourApp: App {
    init() {
        // Das ist alles! 🎉
        RevenueFlow.shared.configure(
            appId: "com.yourcompany.yourapp", // Deine Bundle ID
            debugMode: true // Für Development
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**UIKit:**
```swift
import UIKit
import RevenueFlow

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        RevenueFlow.shared.configure(
            appId: "com.yourcompany.yourapp",
            debugMode: true
        )

        return true
    }
}
```

### Schritt 4: Testen! (1 Minute)

1. Erstelle eine StoreKit Configuration in Xcode
2. Füge Test-Produkte hinzu
3. Starte deine App im Simulator
4. Mache einen Test-Kauf
5. Schaue in die Xcode Console:

```
[RevenueFlow Info] RevenueFlow configured with appId: com.yourcompany.yourapp
[RevenueFlow Info] Transaction monitoring started
[RevenueFlow Debug] Processing transaction: 12345
[RevenueFlow Debug]   Product: com.yourapp.premium
✅ Purchase successfully saved to database: com.yourapp.premium
```

6. Prüfe in Supabase:
```sql
SELECT * FROM purchases WHERE app_id = 'com.yourcompany.yourapp';
```

## ✅ Das war's!

Du musst **NICHTS** in deinem bestehenden StoreKit-Code ändern!

Das SDK erkennt automatisch:
- ✅ Alle neuen Käufe
- ✅ Alle bestehenden Käufe (beim ersten Start)
- ✅ Subscription-Käufe
- ✅ Non-Consumables
- ✅ Consumables
- ✅ Auto-renewable Subscriptions

## 📊 Deine Daten anschauen

### Im Supabase Dashboard

1. Gehe zu **Table Editor**
2. Wähle die `purchases` Tabelle
3. Sieh alle Käufe in Real-time

### Mit SQL

```sql
-- Alle Käufe der letzten 7 Tage
SELECT * FROM purchases
WHERE app_id = 'deine-app-id'
  AND purchase_date >= NOW() - INTERVAL '7 days'
ORDER BY purchase_date DESC;

-- Statistiken für deine App
SELECT * FROM get_app_stats('deine-app-id');

-- Käufe pro Produkt
SELECT
    product_id,
    COUNT(*) as total_purchases,
    COUNT(DISTINCT user_id) as unique_users
FROM purchases
WHERE app_id = 'deine-app-id'
  AND environment = 'production'
GROUP BY product_id;
```

### Mit einer API

```typescript
// Beispiel: Next.js API Route
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://rwejkegeqvullpsogqsd.supabase.co',
  'dein-service-role-key' // NICHT der anon key!
)

export async function GET(request: Request) {
  const { data, error } = await supabase
    .from('purchases')
    .select('*')
    .eq('app_id', 'deine-app-id')
    .order('purchase_date', { ascending: false })
    .limit(100)

  return Response.json({ data, error })
}
```

## 🎯 Best Practices

### 1. App ID wählen

Nutze eine eindeutige ID pro App:
```swift
// ✅ Gut - Bundle Identifier
RevenueFlow.shared.configure(appId: "com.yourcompany.yourapp")

// ✅ Gut - Custom ID
RevenueFlow.shared.configure(appId: "myapp-ios-prod")

// ❌ Schlecht - Zu generisch
RevenueFlow.shared.configure(appId: "app1")
```

### 2. Debug Mode

```swift
#if DEBUG
RevenueFlow.shared.configure(appId: "...", debugMode: true)
#else
RevenueFlow.shared.configure(appId: "...", debugMode: false)
#endif
```

### 3. User-IDs tracken (Optional)

Wenn du User-IDs erfassen willst, erweitere das SDK:

```swift
// In Models.swift - PurchaseRecord
public struct PurchaseRecord: Codable {
    let id: String
    let appId: String
    let userId: String?  // ← Schon vorhanden!
    // ...
}

// In TransactionMonitor.swift - createPurchaseRecord()
private func createPurchaseRecord(from transaction: Transaction) -> PurchaseRecord {
    return PurchaseRecord(
        id: UUID().uuidString,
        appId: appId,
        userId: getCurrentUserId(), // ← Deine Funktion
        productId: transaction.productID,
        transactionId: String(transaction.id),
        purchaseDate: transaction.purchaseDate,
        environment: transaction.environmentString
    )
}

// Irgendwo in deiner App
func getCurrentUserId() -> String? {
    // Deine User-ID Logic
    return UserDefaults.standard.string(forKey: "userId")
}
```

### 4. Production vs. Sandbox

Das SDK erkennt automatisch die Environment:
- **production** - Echte Käufe im App Store
- **sandbox** - TestFlight / Sandbox-Käufe
- **xcode** - StoreKit Configuration in Xcode

Filter in Queries:
```sql
-- Nur Production-Käufe
SELECT * FROM purchases
WHERE environment = 'production';
```

## 🔥 Beispiel: Komplett funktionierender Code

```swift
import SwiftUI
import StoreKit
import RevenueFlow

@main
struct MyApp: App {
    init() {
        RevenueFlow.shared.configure(
            appId: "com.example.myapp",
            debugMode: true
        )
    }

    var body: some Scene {
        WindowGroup {
            StoreView()
        }
    }
}

struct StoreView: View {
    @StateObject private var store = StoreManager()

    var body: some View {
        List(store.products, id: \.id) { product in
            Button {
                Task {
                    await store.purchase(product)
                }
            } label: {
                VStack(alignment: .leading) {
                    Text(product.displayName)
                    Text(product.displayPrice)
                        .font(.caption)
                }
            }
        }
        .task {
            await store.loadProducts()
        }
    }
}

class StoreManager: ObservableObject {
    @Published var products: [Product] = []

    func loadProducts() async {
        do {
            products = try await Product.products(
                for: ["com.example.premium", "com.example.pro"]
            )
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try verification.payloadValue

                // RevenueFlow erfasst diesen Kauf automatisch!
                // Du musst nichts machen! 🎉

                await transaction.finish()
                print("Purchase successful!")

            case .userCancelled:
                print("User cancelled")

            case .pending:
                print("Purchase pending")

            @unknown default:
                break
            }
        } catch {
            print("Purchase failed: \(error)")
        }
    }
}
```

**Das war's!** Jeder Kauf wird automatisch in deiner Supabase-Datenbank gespeichert. 🚀

## 📚 Weitere Ressourcen

- [INTEGRATION_EXAMPLE.md](INTEGRATION_EXAMPLE.md) - Detaillierte Integrations-Beispiele
- [DATABASE_SETUP.md](DATABASE_SETUP.md) - Datenbank-Dokumentation
- [README.md](README.md) - SDK-Dokumentation

## 🆘 Troubleshooting

### Problem: Keine Käufe in der Datenbank

1. **Console-Logs prüfen:**
   ```
   ✅ Supabase client initialized and connected to RevenueFlow backend
   ✅ Transaction monitoring started
   ```

2. **Test in Supabase SQL Editor:**
   ```sql
   INSERT INTO purchases (app_id, product_id, transaction_id, purchase_date, environment)
   VALUES ('test', 'test-product', 'test-123', NOW(), 'sandbox');
   ```

3. **RLS Policies prüfen:**
   ```sql
   SELECT * FROM pg_policies WHERE tablename = 'purchases';
   ```

### Problem: Build-Fehler

1. **Xcode Version:** Mind. Xcode 13.0
2. **iOS Deployment Target:** Mind. iOS 15.0
3. **Swift Package aufräumen:**
   ```
   File → Packages → Reset Package Caches
   ```

### Problem: Duplikate in der Datenbank

Das SDK verhindert automatisch Duplikate:
- Tracked bereits verarbeitete Transaction IDs
- `transaction_id` ist UNIQUE in der Datenbank

Wenn trotzdem Duplikate auftreten:
```sql
-- Duplikate finden
SELECT transaction_id, COUNT(*)
FROM purchases
GROUP BY transaction_id
HAVING COUNT(*) > 1;

-- Duplikate löschen (behalte neueste)
DELETE FROM purchases
WHERE id NOT IN (
    SELECT DISTINCT ON (transaction_id) id
    FROM purchases
    ORDER BY transaction_id, created_at DESC
);
```

## 🎉 Fertig!

Du hast jetzt ein production-ready Purchase-Tracking-System mit:
- ✅ Automatischer Erkennung aller Käufe
- ✅ Real-time Datenbank-Synchronisation
- ✅ Detaillierte Statistiken und Reports
- ✅ Saubere, wartbare Code-Basis

**Happy Coding! 🚀**
