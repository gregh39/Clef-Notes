import Foundation
import CoreData
import RevenueCat
import Combine

@MainActor
class SubscriptionManager: NSObject, ObservableObject, PurchasesDelegate {
    
    static let shared = SubscriptionManager()

    /// The real entitlement state from RevenueCat. Only set from confirmed RevenueCat results,
    /// so Pro-only appearance is applied/reverted once the status is actually known.
    @Published private var hasProEntitlement = false {
        didSet { applyProAppearance() }
    }
    @Published var isPurchasing = false

    /// What the app gates on. In DEBUG builds it can be forced to the free tier from
    /// Settings (see `debugSimulateFreeTier`) to test free-user behavior on a Pro account.
    var isSubscribed: Bool {
        #if DEBUG
        if debugSimulateFreeTier { return false }
        #endif
        return hasProEntitlement
    }

    #if DEBUG
    private static let debugSimulateFreeTierKey = "debugSimulateFreeTier"

    /// DEBUG only: treat this device as a free user regardless of the real subscription.
    @Published var debugSimulateFreeTier = UserDefaults.standard.bool(forKey: SubscriptionManager.debugSimulateFreeTierKey) {
        didSet {
            UserDefaults.standard.set(debugSimulateFreeTier, forKey: Self.debugSimulateFreeTierKey)
            applyProAppearance()
        }
    }

    /// DEBUG only: the real RevenueCat entitlement, shown next to the switch.
    var debugHasRealProEntitlement: Bool { hasProEntitlement }
    #endif

    private override init() {
        super.init()
        updateSubscriptionStatus()
    }

    // This delegate method will be called automatically by RevenueCat
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        // --- THIS IS THE FIX ---
        // Changed "pro" to "ClefNotes Pro" to match your RevenueCat setup.
        self.hasProEntitlement = customerInfo.entitlements["ClefNotes Pro"]?.isActive == true
    }

    func updateSubscriptionStatus() {
        Purchases.shared.getCustomerInfo { (customerInfo, error) in
            if let error = error {
                print("Error fetching customer info: \(error.localizedDescription)")
                return
            }
            // --- THIS IS THE FIX ---
            // Changed "pro" to "ClefNotes Pro" here as well for consistency.
            self.hasProEntitlement = customerInfo?.entitlements["ClefNotes Pro"]?.isActive == true
        }
    }
    
    // Encapsulated async purchase function
    func purchase(package: Package) async throws {
        isPurchasing = true
        // Reset even when the purchase throws (including user cancellation).
        defer { isPurchasing = false }
        let result = try await Purchases.shared.purchase(package: package)

        // This check is now more direct and happens right after the purchase result
        if result.customerInfo.entitlements["ClefNotes Pro"]?.isActive == true {
            self.hasProEntitlement = true
        }
    }

    // Encapsulated async restore function
    func restorePurchases() async throws {
        isPurchasing = true
        defer { isPurchasing = false }
        let customerInfo = try await Purchases.shared.restorePurchases()

        if customerInfo.entitlements["ClefNotes Pro"]?.isActive == true {
            self.hasProEntitlement = true
        }
    }


    /// Pro unlocks accent colors beyond the default and the alternate app icons.
    private func applyProAppearance() {
        SettingsManager.shared.setProAppearanceUnlocked(isSubscribed)
    }

    // MARK: - Free tier
    //
    // Free: one student, with sessions, songs, notes, and everything else unlimited. The
    // metronome and tuner are available inside a practice session (the practice bar).
    // Pro: unlimited students, the metronome/tuner anywhere without opening a session, and
    // extra accent colors and app icons.

    /// Whether another student can be added. Counts the students the user currently owns
    /// (private store), so students shared with them don't count, and deleting a student
    /// frees the slot. Existing students are never locked, only adding new ones.
    func canAddStudent() -> Bool {
        isSubscribed || ownedStudentCount() == 0
    }

    /// Metronome and tuner outside a session (side menu). Inside a session they're always free.
    var canUseToolsOutsideSession: Bool { isSubscribed }

    private func ownedStudentCount() -> Int {
        let persistence = PersistenceController.shared
        let request = StudentCD.fetchRequest()
        if let privateStore = persistence.privatePersistentStore {
            request.affectedStores = [privateStore]
        }
        do {
            return try persistence.persistentContainer.viewContext.count(for: request)
        } catch {
            print("Failed to count students: \(error)")
            return 0
        }
    }
}

