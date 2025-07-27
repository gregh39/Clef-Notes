//
//  SettingsManager.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/26/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - Appearance
    @AppStorage("colorSchemeSetting") var colorSchemeSetting: ColorSchemeSetting = .system
    @AppStorage("selectedAccentColor") var accentColor: AccentColor = .blue
    @AppStorage("appIcon") var appIcon: AppIcon = .defaultIcon

    // MARK: - Practice & Session
    @AppStorage("defaultSessionTitle") var defaultSessionTitle: String = "Practice"
    @AppStorage("defaultSessionDuration") var defaultSessionDuration: Int = 30
    
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
        
        // This publisher reacts to changes in either the toggle or the time picker.
        let settingsChangedPublisher = Publishers.CombineLatest($practiceRemindersEnabled, $practiceReminderTime)
            .dropFirst() // Ignore the initial values on app launch
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main) // Wait for changes to settle

        settingsChangedPublisher
            .sink { [weak self] enabled, time in
                guard let self = self else { return }

                // Save the latest values to UserDefaults
                UserDefaults.standard.set(enabled, forKey: self.practiceRemindersEnabledKey)
                UserDefaults.standard.set(time.timeIntervalSinceReferenceDate, forKey: self.practiceReminderTimeKey)

                // Directly schedule or cancel the repeating notification.
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

enum AppIcon: String, CaseIterable, Identifiable {
    case defaultIcon = "Default"
    case trebleClef = "TrebleClefIcon"
    case altoClef = "AltoClefIcon"
    
    var id: String { self.rawValue }
    
    var iconName: String? {
        switch self {
        case .defaultIcon:
            return nil
        default:
            return self.rawValue
        }
    }
    
    var preview: String {
        switch self {
        case .defaultIcon:
            return "AppIcon"
        case .trebleClef:
            return "TrebleClefIconPreview"
        case .altoClef:
            return "AltoClefIconPreview"
        }
    }
}
