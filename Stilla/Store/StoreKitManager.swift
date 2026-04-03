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
        Task {
            for await result in Transaction.updates {
                await self.handleTransactionUpdate(result)
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

    func displayPrice(for productID: String, fallback: String) -> String {
        products.first(where: { $0.id == productID })?.displayPrice ?? fallback
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
                await handleTransactionUpdate(verification)
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
        var refreshedIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                guard transaction.revocationDate == nil else { continue }
                if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                    continue
                }
                refreshedIDs.insert(transaction.productID)
            case .unverified(_, let error):
                print("Transaction unverified: \(error)")
            }
        }

        purchasedProductIDs = refreshedIDs
    }

    private func handleTransactionUpdate(_ verification: VerificationResult<Transaction>) async {
        switch verification {
        case .verified(let transaction):
            await transaction.finish()
            await updateCustomerProductStatus()
        case .unverified(_, let error):
            print("Transaction unverified: \(error)")
        }
    }
}
