import Foundation
import StoreKit

@MainActor
@Observable
final class StoreKitManager {
    static let shared = StoreKitManager()

    // IAP Product IDs
    static let techniqueLibraryID = "technique.library"
    static let customTechniqueEditorID = "custom.editor"
    static let advancedStatsID = "advanced.stats"

    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var products: [Product] = []

    init() {
        // Start listening for transactions
        Task.detached {
            for await result in Transaction.updates {
                await self.handle(transaction: result)
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

    func loadProducts() async {
        do {
            self.products = try await Product.products(for: [
                Self.techniqueLibraryID,
                Self.customTechniqueEditorID,
                Self.advancedStatsID
            ])
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    func purchase(_ productID: String) async {
        guard let product = products.first(where: { $0.id == productID }) else { return }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(transaction: verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            print("Purchase failed: \(error)")
        }
    }

    func updateCustomerProductStatus() async {
        for await result in Transaction.currentEntitlements {
            await handle(transaction: result)
        }
    }

    private func handle(transaction verification: VerificationResult<Transaction>) async {
        switch verification {
        case .verified(let transaction):
            purchasedProductIDs.insert(transaction.productID)
            await transaction.finish()
        case .unverified(_, let error):
            print("Transaction unverified: \(error)")
        }
    }
}
