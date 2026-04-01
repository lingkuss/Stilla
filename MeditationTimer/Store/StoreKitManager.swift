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

    // Sound Library IDs
    static let soundBundleID = "premium.sounds.bundle"
    static let soundZenWoodblockID = "sound.zenwoodblock"
    static let soundBambooChimeID = "sound.bamboochime"
    static let soundTempleBellID = "sound.templebell"
    static let ambientBinauralDeltaID = "ambient.binaural.delta"
    static let ambientBinauralAlphaID = "ambient.binaural.alpha"
    static let ambientBinauralBetaID = "ambient.binaural.beta"
    
    // New Ambient IDs
    static let ambientNoiseWhiteID = "ambient.noise.white"
    static let ambientNoisePinkID = "ambient.noise.pink"
    static let ambientNoiseBrownID = "ambient.noise.brown"
    static let ambientSolfeggioNatureID = "ambient.solfeggio.nature"
    static let ambientSolfeggioLoveID = "ambient.solfeggio.love"
    
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
        // If they own the bundle, they own all sounds automatically
        if purchasedProductIDs.contains(Self.soundBundleID) {
            let soundIDs: Set<String> = [
                Self.soundZenWoodblockID, Self.soundBambooChimeID, Self.soundTempleBellID,
                Self.ambientBinauralDeltaID, Self.ambientBinauralAlphaID, Self.ambientBinauralBetaID,
                Self.ambientNoiseWhiteID, Self.ambientNoisePinkID, Self.ambientNoiseBrownID,
                Self.ambientSolfeggioNatureID, Self.ambientSolfeggioLoveID
            ]
            if soundIDs.contains(productID) {
                return true
            }
        }
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
                Self.advancedStatsID,
                Self.soundBundleID,
                Self.soundZenWoodblockID,
                Self.soundBambooChimeID,
                Self.soundTempleBellID,
                Self.ambientBinauralDeltaID,
                Self.ambientBinauralAlphaID,
                Self.ambientBinauralBetaID,
                Self.ambientNoiseWhiteID,
                Self.ambientNoisePinkID,
                Self.ambientNoiseBrownID,
                Self.ambientSolfeggioNatureID,
                Self.ambientSolfeggioLoveID,
                Self.soundKAIProID
            ])
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    func purchase(_ productID: String) async {
        print("🛒 Attempting to purchase: \(productID)")
        guard let product = products.first(where: { $0.id == productID }) else {
            print("❌ Product not found: \(productID). Loaded: \(products.map { $0.id })")
            return
        }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                print("✅ Purchase success: \(productID)")
                await handle(verification: verification)
            case .userCancelled:
                print("⚠️ Purchase cancelled by user")
            case .pending:
                print("⏳ Purchase pending")
            @unknown default:
                break
            }
        } catch {
            print("❌ Purchase failed: \(error)")
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
