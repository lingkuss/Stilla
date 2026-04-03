import SwiftUI
import StoreKit

struct KAIPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreKitManager.shared
    @State private var statusMessage = ""
    @State private var showingStatus = false
    
    var body: some View {
        ZStack {
            Color(hue: 0.72, saturation: 0.4, brightness: 0.05)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(.blue.gradient)
                }
                
                VStack(spacing: 16) {
                    Text("Unlock Unlimited KAI")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                    
                    Text("Experience the full power of your personal AI guide with unlimited personalized meditation generation.")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Benefit List
                VStack(alignment: .leading, spacing: 16) {
                    BenefitRow(icon: "infinity", text: "Unlimited AI Meditations")
                    BenefitRow(icon: "brain.head.profile", text: "Deep Personalized Guidance")
                    BenefitRow(icon: "person.2.fill", text: "All Personas Always Available")
                    BenefitRow(icon: "books.vertical.fill", text: "Replay Your Saved Kai Library")
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Purchase Button
                Button {
                    Task {
                        let outcome = await StoreKitManager.shared.purchase(StoreKitManager.soundKAIProID)
                        if case .success = outcome {
                            dismiss()
                        } else {
                            present(outcome)
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text("Subscribe for \(kaiPriceText)")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Capsule().fill(.white))
                }
                .padding(.horizontal, 32)
                
                Button("Restore Purchases") {
                    Task {
                        do {
                            try await AppStore.sync()
                        } catch {
                            statusMessage = "Restore couldn't be completed right now. Please try again in a moment."
                            showingStatus = true
                            return
                        }
                        await store.updateCustomerProductStatus()
                        if store.isKAISubscribed {
                            dismiss()
                        } else {
                            statusMessage = "No active Kai subscription was found to restore."
                            showingStatus = true
                        }
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))

                HStack(spacing: 16) {
                    Link("Privacy Policy", destination: URL(string: "https://stilla-three.vercel.app/privacy")!)
                    Link("Terms of Use", destination: URL(string: "https://stilla-three.vercel.app/terms")!)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .alert("Purchase Status", isPresented: $showingStatus) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(statusMessage)
        }
    }

    private var kaiPriceText: String {
        store.products.first(where: { $0.id == StoreKitManager.soundKAIProID }).map { "\($0.displayPrice)/mo" } ?? "$4.99/mo"
    }

    private func present(_ outcome: StoreKitManager.PurchaseOutcome) {
        switch outcome {
        case .success:
            return
        case .cancelled:
            statusMessage = "Purchase cancelled."
        case .pending:
            statusMessage = "Your subscription purchase is pending approval."
        case .unavailable:
            statusMessage = "Kai Pro isn't available right now. Check your App Store product configuration."
        case .failed(let message):
            statusMessage = message
        }
        showingStatus = true
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}
