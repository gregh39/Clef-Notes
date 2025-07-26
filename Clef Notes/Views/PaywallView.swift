import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @State private var offerings: Offerings? = nil
    @State private var isPurchasing = false

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    features
                    packages
                }
                .padding()
            }
            
            footer
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            Purchases.shared.getOfferings { (offerings, error) in
                self.offerings = offerings
            }
        }
        .overlay {
            if isPurchasing {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView("Processing...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding()
                    .background(.black.opacity(0.6))
                    .cornerRadius(10)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.quarternote.3")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            Text("Unlock Clef Notes Pro")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Get unlimited access to all features and take your practice to the next level.")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 15) {
            FeatureRow(icon: "person.3.fill", title: "Unlimited Students", description: "Manage as many students as you need.")
            FeatureRow(icon: "calendar.badge.plus", title: "Unlimited Sessions", description: "Log every practice session without limits.")
            FeatureRow(icon: "music.note.list", title: "Unlimited Songs", description: "Keep track of your entire repertoire.")
            FeatureRow(icon: "metronome.fill", title: "Full Tool Access", description: "Use the metronome and tuner anytime.")
        }
        .padding()
        .background(.background.secondary)
        .cornerRadius(12)
    }

    private var packages: some View {
        VStack(spacing: 12) {
            if let packages = offerings?.current?.availablePackages {
                ForEach(packages) { package in
                    Button(action: { purchase(package: package) }) {
                        PackageButton(package: package)
                    }
                }
            } else {
                ProgressView()
                    .padding()
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button("Restore Purchases") {
                restorePurchases()
            }
            .font(.caption.bold())

            Button("Dismiss") {
                dismiss()
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
    }

    private func purchase(package: Package) {
        isPurchasing = true
        Purchases.shared.purchase(package: package) { (transaction, customerInfo, error, userCancelled) in
            isPurchasing = false
            if customerInfo?.entitlements["pro"]?.isActive == true {
                subscriptionManager.updateSubscriptionStatus()
                dismiss()
            }
        }
    }
    
    private func restorePurchases() {
        isPurchasing = true
        Purchases.shared.restorePurchases { (customerInfo, error) in
            isPurchasing = false
            if customerInfo?.entitlements["pro"]?.isActive == true {
                subscriptionManager.updateSubscriptionStatus()
                dismiss()
            }
        }
    }
}

// Helper Views for the Paywall

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundColor(.secondary)
            }
        }
    }
}

private struct PackageButton: View {
    let package: Package
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(package.storeProduct.localizedTitle)
                    .font(.headline.bold())
                Text(package.storeProduct.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(package.storeProduct.localizedPriceString)
                .font(.headline.bold())
        }
        .padding()
        .background(.background.secondary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor, lineWidth: 2)
        )
    }
}
