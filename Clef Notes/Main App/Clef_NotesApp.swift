import SwiftUI
import CoreData
import RevenueCat

@main
struct Clef_NotesApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var sessionTimerManager: SessionTimerManager
    // Use the shared instance of SubscriptionManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var usageManager: UsageManager
    
    init() {
        let context = PersistenceController.shared.persistentContainer.viewContext
        _sessionTimerManager = StateObject(wrappedValue: SessionTimerManager(context: context))
        _usageManager = StateObject(wrappedValue: UsageManager(context: context))
    }
        
    var body: some Scene {
        WindowGroup {
            ContentView()
               .environment(\.managedObjectContext, PersistenceController.shared.persistentContainer.viewContext)
               .environmentObject(AudioManager())
               .environmentObject(sessionTimerManager)
               .environmentObject(subscriptionManager)
               .environmentObject(usageManager)

        }
    }
}
