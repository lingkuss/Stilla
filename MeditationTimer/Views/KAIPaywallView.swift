import SwiftUI
import StoreKit

struct KAIPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    
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
                    
                    Text("Experience the full power of your personal AI guide. One-time monthly subscription, endless clarity.")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Benefit List
                VStack(alignment: .leading, spacing: 16) {
                    BenefitRow(icon: "infinite", text: "Unlimited AI Meditations")
                    BenefitRow(icon: "brain.headset", text: "Deep Personalized Guidance")
                    BenefitRow(icon: "icloud.and.arrow.down", text: "Save Journeys to Library")
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Purchase Button
                Button {
                    Task {
                        await StoreKitManager.shared.purchase(StoreKitManager.soundKAIProID)
                        // Only dismiss if the purchase was successful
                        if StoreKitManager.shared.isKAISubscribed {
                            dismiss()
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text("Subscribe for $4.99/mo")
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
                        // In a real app, you'd call AppStore.sync()
                        dismiss()
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
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
