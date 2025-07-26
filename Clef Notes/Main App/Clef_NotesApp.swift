import SwiftUI
import CoreData
import RevenueCat

@main
struct Clef_NotesApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var sessionTimerManager: SessionTimerManager
    @StateObject private var subscriptionManager: SubscriptionManager // Add this
    @StateObject private var usageManager: UsageManager
    
    init() {
        let context = PersistenceController.shared.persistentContainer.viewContext
        _sessionTimerManager = StateObject(wrappedValue: SessionTimerManager(context: context))
        _subscriptionManager = StateObject(wrappedValue: SubscriptionManager(context: context)) // And this
        _usageManager = StateObject(wrappedValue: UsageManager(context: context)) // And this

        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: rc_key)
    }
        
    var body: some Scene {
        WindowGroup {
            ContentView()
               .environment(\.managedObjectContext, PersistenceController.shared.persistentContainer.viewContext)
               .environmentObject(AudioManager())
               .environmentObject(sessionTimerManager)
               .environmentObject(subscriptionManager) // Inject the manager
               .environmentObject(usageManager) // Inject the manager

        }
    }
}
