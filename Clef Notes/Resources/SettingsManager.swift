// Clef Notes/Resources/SettingsManager.swift

import Foundation
import SwiftUI
import Combine
import TelemetryDeck

enum ColorSchemeSetting: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { self.rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}


@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - Appearance
    @AppStorage("colorSchemeSetting") var colorSchemeSetting: ColorSchemeSetting = .system {
        willSet { objectWillChange.send() }
    }
    @AppStorage("selectedAccentColor") var accentColor: AccentColor = .blue {
        willSet { objectWillChange.send() }
    }
    @AppStorage("appIcon") var appIcon: AppIcon = .bassClef {
        willSet { objectWillChange.send() }
    }
    @AppStorage("customAccentColor") var customAccentColor: Color = .blue {
        willSet { objectWillChange.send() }
    }

    /// Accent colors other than the default and alternate app icons are Pro features.
    /// `SubscriptionManager` sets this once the subscription status is known. While locked,
    /// the defaults are shown but the user's choice is kept, so it returns if they resubscribe.
    /// Starts unlocked so Pro users don't flash back to the defaults at launch.
    @Published private(set) var proAppearanceUnlocked = true

    static let freeAccentColor: AccentColor = .blue
    static let freeAppIcon: AppIcon = .bassClef

    func setProAppearanceUnlocked(_ unlocked: Bool) {
        guard unlocked != proAppearanceUnlocked else { return }
        proAppearanceUnlocked = unlocked
        setAppIcon()
    }

    /// The accent color actually in use (the default while Pro appearance is locked).
    var effectiveAccentColor: AccentColor {
        proAppearanceUnlocked ? accentColor : Self.freeAccentColor
    }

    /// The app icon actually in use (the default while Pro appearance is locked).
    var effectiveAppIcon: AppIcon {
        proAppearanceUnlocked ? appIcon : Self.freeAppIcon
    }

    /// A computed property that returns the currently active accent color.
    var activeAccentColor: Color {
        guard proAppearanceUnlocked else { return Self.freeAccentColor.color ?? .blue }
        if accentColor == .custom {
            return customAccentColor
        }
        return accentColor.color ?? .blue // Fallback to blue
    }

    // MARK: - Practice & Session
    @AppStorage("defaultSessionTitle") var defaultSessionTitle: String = "Practice"
    @AppStorage("defaultSessionDuration") var defaultSessionDuration: Int = 0
    
    @Published var practiceRemindersEnabled: Bool
    @Published var practiceReminderTime: Date

    // MARK: - Tools
    @AppStorage("a4Frequency") var a4Frequency: Double = 440.0 {
        willSet {
            TelemetryDeck.signal("settings_changed", parameters: ["setting": "A4_frequency", "new_value": "\(newValue)"])
        }
    }
    @AppStorage("tunerTransposition") var tunerTransposition: Int = 0 { // In semitones
        willSet {
            TelemetryDeck.signal("settings_changed", parameters: ["setting": "transposition", "new_value": "\(newValue)"])
        }
    }

    // MARK: - Awards & Notifications
    @AppStorage("awardNotificationsEnabled") var awardNotificationsEnabled: Bool = true
    @AppStorage("weeklyGoalEnabled") var weeklyGoalEnabled: Bool = false
    @AppStorage("weeklyGoalMinutes") var weeklyGoalMinutes: Int = 120
    
    private var cancellables = Set<AnyCancellable>()
    private let practiceRemindersEnabledKey = "practiceRemindersEnabled"
    private let practiceReminderTimeKey = "practiceReminderTime"
    
    private init() {
        // Load initial values from UserDefaults
        practiceRemindersEnabled = UserDefaults.standard.bool(forKey: practiceRemindersEnabledKey)
        if let timeInterval = UserDefaults.standard.object(forKey: practiceReminderTimeKey) as? TimeInterval {
            practiceReminderTime = Date(timeIntervalSinceReferenceDate: timeInterval)
        } else {
            // Default to 7 PM if no time is set
            practiceReminderTime = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!
        }
        
        let settingsChangedPublisher = Publishers.CombineLatest($practiceRemindersEnabled, $practiceReminderTime)
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)

        settingsChangedPublisher
            .sink { [weak self] enabled, time in
                guard let self = self else { return }

                UserDefaults.standard.set(enabled, forKey: self.practiceRemindersEnabledKey)
                UserDefaults.standard.set(time.timeIntervalSinceReferenceDate, forKey: self.practiceReminderTimeKey)

                if enabled {
                    NotificationManager.shared.schedulePracticeReminder()
                } else {
                    NotificationManager.shared.cancelPracticeReminder()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Applies `effectiveAppIcon` to the home screen (no-op if it's already set).
    func setAppIcon() {
        let iconName = effectiveAppIcon.iconName
        guard UIApplication.shared.alternateIconName != iconName else { return }
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("Error setting alternate app icon: \(error.localizedDescription)")
            }
        }
    }
}
