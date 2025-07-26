import Foundation
import CoreData
import RevenueCat
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var isSubscribed = false

    private var usageManager: UsageManager

    init(context: NSManagedObjectContext) {
        self.usageManager = UsageManager(context: context)
        updateSubscriptionStatus()
    }

    func updateSubscriptionStatus() {
        Purchases.shared.getCustomerInfo { (customerInfo, error) in
            self.isSubscribed = customerInfo?.entitlements["pro"]?.isActive == true
        }
    }

    func isAllowedToCreateStudent() -> Bool {
        if isSubscribed { return true }
        return usageManager.studentCreations < 2
    }

    func isAllowedToCreateSession() -> Bool { // No longer needs a student
        if isSubscribed { return true }
        return usageManager.sessionCreations < 3
    }

    func isAllowedToCreateSong() -> Bool { // No longer needs a student
        if isSubscribed { return true }
        return usageManager.songCreations < 3
    }

    var canAccessPaidFeatures: Bool {
        if isSubscribed { return true }
        return usageManager.studentCreations <= 2 &&
               usageManager.sessionCreations <= 3 &&
               usageManager.songCreations <= 3
    }
}
