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
                    Text(String(localized: "paywall.title"))
                        .font(.system(size: 28, weight: .bold, design: .serif))
                    
                    Text(String(localized: "paywall.subtitle"))
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Benefit List
                VStack(alignment: .leading, spacing: 16) {
                    BenefitRow(icon: "infinity", text: String(localized: "paywall.benefit.unlimited"))
                    BenefitRow(icon: "brain.head.profile", text: String(localized: "paywall.benefit.guidance"))
                    BenefitRow(icon: "person.2.fill", text: String(localized: "paywall.benefit.personas"))
                    BenefitRow(icon: "books.vertical.fill", text: String(localized: "paywall.benefit.library"))
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Purchase Button
                Button {
                    Task {
                        let outcome = await StoreKitManager.shared.purchase(StoreKitManager.vindlaProID)
                        if case .success = outcome {
                            dismiss()
                        } else {
                            present(outcome)
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(String(format: String(localized: "paywall.subscribe.format"), kaiPriceText))
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Capsule().fill(.white))
                }
                .padding(.horizontal, 32)
                
                Button(String(localized: "paywall.restore")) {
                    Task {
                        do {
                            try await AppStore.sync()
                        } catch {
                            statusMessage = String(localized: "paywall.restore.error")
                            showingStatus = true
                            return
                        }
                        await store.updateCustomerProductStatus()
                        if store.isVindlaProSubscribed {
                            dismiss()
                        } else {
                            statusMessage = String(localized: "paywall.restore.none")
                            showingStatus = true
                        }
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))

                HStack(spacing: 16) {
                    Link(String(localized: "paywall.privacy"), destination: URL(string: "https://vindla-three.vercel.app/privacy")!)
                    Link(String(localized: "paywall.terms"), destination: URL(string: "https://vindla-three.vercel.app/terms")!)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .alert(String(localized: "paywall.alert.title"), isPresented: $showingStatus) {
            Button(String(localized: "common.ok"), role: .cancel) { }
        } message: {
            Text(statusMessage)
        }
    }

    private var kaiPriceText: String {
        store.products.first(where: { $0.id == StoreKitManager.vindlaProID }).map { "\($0.displayPrice)/mo" } ?? "$4.99/mo"
    }

    private func present(_ outcome: StoreKitManager.PurchaseOutcome) {
        switch outcome {
        case .success:
            return
        case .cancelled:
            statusMessage = String(localized: "purchase.cancelled")
        case .pending:
            statusMessage = String(localized: "purchase.pending")
        case .unavailable:
            statusMessage = String(localized: "purchase.unavailable")
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
