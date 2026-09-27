import SwiftUI
import RevenueCat

struct SubscriptionView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var alertMessage: String?

    var body: some View {
        Form {
            Section(header: Text("Current Plan")) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscriptionManager.isSubscribed ? "Clef Notes Pro" : "Free Version")
                            .font(.headline)
                        Text(subscriptionManager.isSubscribed ? "You have access to all features." : "One student, with unlimited sessions, songs, and notes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if subscriptionManager.isSubscribed {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.title)
                    }
                }
            }

            Section(header: Text("Pro Features")) {
                FeatureRow(icon: "person.3.fill", title: "Unlimited Students", description: "Add as many students as you need.")
                FeatureRow(icon: "metronome.fill", title: "Tools Anytime", description: "Open the metronome and tuner from the menu, without starting a session.")
                FeatureRow(icon: "paintpalette.fill", title: "Colors & App Icons", description: "Personalize the app with more accent colors and alternate icons.")
            }

            Section {
                Button(action: {
                    manageSubscription()
                }) {
                    Label("Manage Subscription", systemImage: "creditcard.fill")
                }

                Button(action: {
                    Task {
                        await restorePurchases()
                    }
                }) {
                    if subscriptionManager.isPurchasing {
                        HStack {
                            ProgressView()
                            Spacer()
                            Text("Restoring...")
                        }
                    } else {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(subscriptionManager.isPurchasing)
            }
        }
        .navigationTitle("Subscription")
        .alert("An Error Occurred", isPresented: .constant(alertMessage != nil), actions: {
            Button("OK") {
                alertMessage = nil // Dismiss the alert
            }
        }, message: {
            Text(alertMessage ?? "Something went wrong.")
        })
    }

    private func manageSubscription() {
        // This URL opens the subscription management page in the App Store on a real device.
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    private func restorePurchases() async {
        do {
            try await subscriptionManager.restorePurchases()
        } catch {
            self.alertMessage = error.localizedDescription
        }
    }
}

// Re-using the FeatureRow from PaywallView for consistency
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

#Preview {
    NavigationView {
        SubscriptionView()
            .environmentObject(SubscriptionManager.shared)
    }
}
