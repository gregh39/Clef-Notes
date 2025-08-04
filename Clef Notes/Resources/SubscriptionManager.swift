import Foundation
import CoreData
import RevenueCat
import Combine

@MainActor
class SubscriptionManager: NSObject, ObservableObject, PurchasesDelegate {
    
    static let shared = SubscriptionManager()

    @Published var isSubscribed = false
    @Published var isPurchasing = false

    private var usageManager: UsageManager

    private override init() {
        let context = PersistenceController.shared.persistentContainer.viewContext
        self.usageManager = UsageManager(context: context)
        super.init()
        updateSubscriptionStatus()
    }

    // This delegate method will be called automatically by RevenueCat
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        // --- THIS IS THE FIX ---
        // Changed "pro" to "ClefNotes Pro" to match your RevenueCat setup.
        self.isSubscribed = customerInfo.entitlements["ClefNotes Pro"]?.isActive == true
    }

    func updateSubscriptionStatus() {
        Purchases.shared.getCustomerInfo { (customerInfo, error) in
            if let error = error {
                print("Error fetching customer info: \(error.localizedDescription)")
                return
            }
            // --- THIS IS THE FIX ---
            // Changed "pro" to "ClefNotes Pro" here as well for consistency.
            self.isSubscribed = customerInfo?.entitlements["ClefNotes Pro"]?.isActive == true
        }
    }
    
    // Encapsulated async purchase function
    func purchase(package: Package) async throws {
        isPurchasing = true
        let result = try await Purchases.shared.purchase(package: package)
        
        // This check is now more direct and happens right after the purchase result
        if result.customerInfo.entitlements["ClefNotes Pro"]?.isActive == true {
            self.isSubscribed = true
        }
        isPurchasing = false
    }

    // Encapsulated async restore function
    func restorePurchases() async throws {
        isPurchasing = true
        let customerInfo = try await Purchases.shared.restorePurchases()
        
        if customerInfo.entitlements["ClefNotes Pro"]?.isActive == true {
            self.isSubscribed = true
        }
        isPurchasing = false
    }


    func isAllowedToCreateStudent() -> Bool {
        if isSubscribed { return true }
        return usageManager.studentCreations < 2
    }

    func isAllowedToCreateSession() -> Bool {
        if isSubscribed { return true }
        return usageManager.sessionCreations < 3
    }

    func isAllowedToCreateSong() -> Bool {
        if isSubscribed { return true }
        return usageManager.songCreations < 3
    }
    
    func isAllowedToOpenMetronome() -> Bool {
        if isSubscribed { return true }
        return usageManager.metronomeOpens < 11
    }

    func isAllowedToOpenTuner() -> Bool {
        if isSubscribed { return true }
        return usageManager.tunerOpens < 11
    }

    var canAccessPaidFeatures: Bool {
        if isSubscribed { return true }
        return usageManager.studentCreations <= 2 &&
               usageManager.sessionCreations <= 3 &&
               usageManager.songCreations <= 3
    }
}

