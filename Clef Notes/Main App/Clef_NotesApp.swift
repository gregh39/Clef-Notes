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
        // Shared so Live Activity button intents can reach the running timer.
        _sessionTimerManager = StateObject(wrappedValue: SessionTimerManager.shared)
        _usageManager = StateObject(wrappedValue: UsageManager(context: context))
        // Notification permission is requested lazily by NotificationManager when a feature needs it.

        try? Tips.configure([
            .displayFrequency(.daily),
            .datastoreLocation(.applicationDefault)
        ])

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
            if let loadError = PersistenceController.shared.loadError {
                StoreLoadErrorView(error: loadError)
            } else {
                mainContent
            }
        }
    }

    private var mainContent: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.shared.persistentContainer.viewContext)
            .environmentObject(AudioManager.shared)
            .environmentObject(sessionTimerManager)
            .environmentObject(subscriptionManager)
            .environmentObject(usageManager)
            .environmentObject(settingsManager)
            .preferredColorScheme(settingsManager.colorSchemeSetting.colorScheme)
            .tint(settingsManager.activeAccentColor)
    }
    
    private static func getAPIKey(named keyName: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: keyName) as? String else {
            fatalError("API Key '\(keyName)' not found in Info.plist. Make sure it's set in your Keys.xcconfig file.")
        }
        return value
    }

}
