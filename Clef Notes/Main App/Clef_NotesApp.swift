// Clef Notes/Main App/Clef_NotesApp.swift

import SwiftUI
import CoreData
import RevenueCat
import TipKit
import TelemetryDeck

@main
struct Clef_NotesApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var sessionTimerManager: SessionTimerManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var usageManager: UsageManager
    @StateObject private var settingsManager = SettingsManager.shared
    
    init() {
        let config = TelemetryDeck.Config(appID: Clef_NotesApp.getAPIKey(named: "TelemetryDeckAPIKey"))
        TelemetryDeck.initialize(config: config)

        let context = PersistenceController.shared.persistentContainer.viewContext
        _sessionTimerManager = StateObject(wrappedValue: SessionTimerManager(context: context))
        _usageManager = StateObject(wrappedValue: UsageManager(context: context))
        NotificationManager.shared.requestAuthorization()

        try? Tips.configure([
            .displayFrequency(.immediate), // Show tips immediately for testing
            .datastoreLocation(.applicationDefault)
        ])
        //try? Tips.resetDatastore()
        //Tips.showAllTipsForTesting()

        // Run audio duration migration once
        migrateAudioDurationsIfNeeded(context: context)
    }

    private func migrateAudioDurationsIfNeeded(context: NSManagedObjectContext) {
        let migrationKey = "AudioDurationMigrationCompleted_v1"

        if !UserDefaults.standard.bool(forKey: migrationKey) {
            AudioDurationMigrationHelper.migrateAudioDurations(context: context)
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
    }
        
    var body: some Scene {
        WindowGroup {
            ContentView()
               .environment(\.managedObjectContext, PersistenceController.shared.persistentContainer.viewContext)
               .environmentObject(AudioManager.shared)
               .environmentObject(sessionTimerManager)
               .environmentObject(subscriptionManager)
               .environmentObject(usageManager)
               .environmentObject(settingsManager)
               .preferredColorScheme(settingsManager.colorSchemeSetting.colorScheme)
               .tint(settingsManager.activeAccentColor) // <<< CHANGE THIS LINE
        }
    }
    
    private static func getAPIKey(named keyName: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: keyName) as? String else {
            fatalError("API Key '\(keyName)' not found in Info.plist. Make sure it's set in your Keys.xcconfig file.")
        }
        return value
    }

}
