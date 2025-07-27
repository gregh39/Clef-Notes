//
//  NotificationManager.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/26/25.
//

import Foundation
import UserNotifications
import CoreData

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    // Schedules a repeating daily reminder at the user-specified time.
    func schedulePracticeReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Practice Reminder"
        content.body = "Time for your daily practice session!"
        content.sound = .default

        // Use the user-defined time from SettingsManager
        let reminderTime = SettingsManager.shared.practiceReminderTime
        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        
        // Create a trigger that repeats daily at the specified time.
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "practiceReminder", content: content, trigger: trigger)
        
        // Remove any existing reminder before adding a new one to ensure the time is updated.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["practiceReminder"])
        UNUserNotificationCenter.current().add(request)
        print("Repeating practice reminder scheduled for \(dateComponents.hour ?? 0):\(String(format: "%02d", dateComponents.minute ?? 0)) daily.")
    }
    
    func cancelPracticeReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["practiceReminder"])
        print("Practice reminder canceled.")
    }
    
    func sendAwardNotification(award: Award) {
        let content = UNMutableNotificationContent()
        content.title = "Award Earned!"
        content.body = "You've earned the \(award.rawValue) award. Keep up the great work!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
