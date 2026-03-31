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
                Self.ambientSolfeggioLoveID
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
