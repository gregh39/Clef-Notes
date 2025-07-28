import SwiftUI
import CoreData
import RevenueCat
import TipKit // 1. Import TipKit

@main
struct Clef_NotesApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var sessionTimerManager: SessionTimerManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var usageManager: UsageManager
    @StateObject private var settingsManager = SettingsManager.shared
    
    init() {
        let context = PersistenceController.shared.persistentContainer.viewContext
        _sessionTimerManager = StateObject(wrappedValue: SessionTimerManager(context: context))
        _usageManager = StateObject(wrappedValue: UsageManager(context: context))
        NotificationManager.shared.requestAuthorization()
    }
        
    var body: some Scene {
        WindowGroup {
            ContentView()
               .environment(\.managedObjectContext, PersistenceController.shared.persistentContainer.viewContext)
               .environmentObject(AudioManager())
               .environmentObject(sessionTimerManager)
               .environmentObject(subscriptionManager)
               .environmentObject(usageManager)
               .environmentObject(settingsManager)
               .preferredColorScheme(settingsManager.colorSchemeSetting.colorScheme)
               .onAppear {
                   settingsManager.setAppIcon()
               }
               // 2. Add a task to configure TipKit when the app starts.
               .task {
                    try? Tips.configure([
                        // You can add options here, like displaying tips more frequently for debugging.
                        // .displayFrequency(.immediate)
                    ])
               }
        }
    }
}
