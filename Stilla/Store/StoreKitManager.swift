import Foundation
import StoreKit

@MainActor
@Observable
final class StoreKitManager {
    static let shared = StoreKitManager()

    enum PurchaseOutcome {
        case success
        case cancelled
        case pending
        case unavailable
        case failed(String)
    }

    // IAP Product IDs
    static let techniqueLibraryID = "technique.library"
    static let customTechniqueEditorID = "custom.editor"

    // Sound Library IDs
    static let soundBundleID = "premium.sounds.bundle"

    // KAI Subscription
    static let soundKAIProID = "sub.kai.monthly"

    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var products: [Product] = []

    init() {
        // Start listening for transactions
        Task.detached {
            for await result in Transaction.updates {
                await self.handle(verification: result)
            }
        }
        
        Task {
            await loadProducts()
            await updateCustomerProductStatus()
        }
    }

    func isPurchased(_ productID: String) -> Bool {
        return purchasedProductIDs.contains(productID)
    }

    var isKAISubscribed: Bool {
        purchasedProductIDs.contains(Self.soundKAIProID)
    }

    func loadProducts() async {
        do {
            self.products = try await Product.products(for: [
                Self.techniqueLibraryID,
                Self.customTechniqueEditorID,
                Self.soundBundleID,
                Self.soundKAIProID
            ])
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    func purchase(_ productID: String) async -> PurchaseOutcome {
        print("🛒 Attempting to purchase: \(productID)")
        guard let product = products.first(where: { $0.id == productID }) else {
            print("❌ Product not found: \(productID). Loaded: \(products.map { $0.id })")
            return .unavailable
        }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                print("✅ Purchase success: \(productID)")
                await handle(verification: verification)
                return .success
            case .userCancelled:
                print("⚠️ Purchase cancelled by user")
                return .cancelled
            case .pending:
                print("⏳ Purchase pending")
                return .pending
            @unknown default:
                return .failed("The App Store returned an unknown purchase state.")
            }
        } catch {
            print("❌ Purchase failed: \(error)")
            return .failed(error.localizedDescription)
        }
    }

    func updateCustomerProductStatus() async {
        for await result in Transaction.currentEntitlements {
            await handle(verification: result)
        }
    }

    private func handle(verification: VerificationResult<Transaction>) async {
        switch verification {
        case .verified(let transaction):
            purchasedProductIDs.insert(transaction.productID)
            await transaction.finish()
        case .unverified(_, let error):
            print("Transaction unverified: \(error)")
        }
    }
}
