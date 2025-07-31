// Clef Notes/Resources/SettingsManager.swift

import Foundation
import SwiftUI
import Combine

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

    /// A computed property that returns the currently active accent color.
    var activeAccentColor: Color {
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
    @AppStorage("a4Frequency") var a4Frequency: Double = 440.0
    @AppStorage("tunerTransposition") var tunerTransposition: Int = 0 // In semitones

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
    
    func setAppIcon() {
        UIApplication.shared.setAlternateIconName(appIcon.iconName) { error in
            if let error = error {
                print("Error setting alternate app icon: \(error.localizedDescription)")
            }
        }
    }
}
