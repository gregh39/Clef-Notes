import SwiftUI
import RevenueCat
import Combine
import SafariServices

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @State private var offerings: Offerings? = nil
    @State private var isPurchasing = false
    @State private var alertMessage: String?
    @State private var showingSafariView = false
    @State private var safariURL: URL? = nil

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 10) {
                    header
                    features
                    Spacer()
                }
            }
            packages
            footer
        }
        .padding()
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
        .alert("An Error Occurred", isPresented: .constant(alertMessage != nil), actions: {
            Button("OK") {
                alertMessage = nil // Dismiss the alert
            }
        }, message: {
            Text(alertMessage ?? "Something went wrong.")
        })
        .sheet(isPresented: $showingSafariView) {
            if let url = safariURL {
                SafariWebView(url: url)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image("glassicon")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.accentColor)
            Text("Unlock Clef Notes Pro")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Get unlimited access to all features and take your practice to the next level.")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text("With the free version of ClefNotes you can add 2 students, 3 songs, 3 sessions, and have 10 uses of the tuner and metronome.")
                .font(.footnote)
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
            //FeatureRow(icon: "wand.and.stars", title: "Support Indie Dev", description: "Support independent app development and continued updates to ClefNotes.")
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
        VStack{
            VStack {
                Button("Restore Purchases") {
                    restorePurchases()
                }
                .font(.footnote.bold())
                
            }
            .padding(.bottom, 10)
            HStack{
                VStack{
                    Button(action: {
                        safariURL = URL(string: "https://clefnotes.app/terms.html")
                        showingSafariView = true
                    }) {
                        Text("Terms of Use")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button("Dismiss") {
                    dismiss()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                Spacer()
                VStack{
                    Button(action: {
                        safariURL = URL(string: "https://clefnotes.app/privacy.html")
                        showingSafariView = true
                    }) {
                        Text("Privacy Policy")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.plain)
                }
            }

        }
    }

    private func purchase(package: Package) {
        isPurchasing = true
        Purchases.shared.purchase(package: package) { (transaction, customerInfo, error, userCancelled) in
            isPurchasing = false
            if let error = error, !userCancelled {
                self.alertMessage = error.localizedDescription
                return
            }
            if customerInfo?.entitlements["ClefNotes Pro"]?.isActive == true {
                subscriptionManager.updateSubscriptionStatus()
                dismiss()
            }
        }
    }
    
    private func restorePurchases() {
        isPurchasing = true
        Purchases.shared.restorePurchases { (customerInfo, error) in
            isPurchasing = false
            if let error = error {
                self.alertMessage = error.localizedDescription
                return
            }
            if customerInfo?.entitlements["ClefNotes Pro"]?.isActive == true {
                subscriptionManager.updateSubscriptionStatus()
                dismiss()
            } else {
                self.alertMessage = "No active subscription found to restore."
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

private struct SafariWebView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

#if DEBUG
import SwiftUI

private final class MockSubscriptionManager: ObservableObject {
    @Published var isSubscribed: Bool = false
    func updateSubscriptionStatus() {}
}

#Preview {
    PaywallView()
        .environmentObject(MockSubscriptionManager())
}
#endif
