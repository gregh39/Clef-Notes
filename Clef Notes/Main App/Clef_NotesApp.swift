// Clef Notes/Main App/Clef_NotesApp.swift

import SwiftUI
import CoreData
import RevenueCat
import TipKit

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
        
        try? Tips.configure([
            .displayFrequency(.immediate), // Show tips immediately for testing
            .datastoreLocation(.applicationDefault)

        ])
        try? Tips.resetDatastore()
        //Tips.showAllTipsForTesting()

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
               .tint(settingsManager.activeAccentColor) // <<< CHANGE THIS LINE
               .onAppear {
                   settingsManager.setAppIcon()
               }
        }
    }
}
