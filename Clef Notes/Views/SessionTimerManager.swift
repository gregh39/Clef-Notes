import Foundation
import CoreData
import SwiftUI
import Combine
import TelemetryDeck
import AVFoundation
import UserNotifications

@MainActor
class SessionTimerManager: ObservableObject {
    @Published var activeSession: PracticeSessionCD?
    @Published var elapsedTimeString: String = "00:00:00"
    @Published var isPaused = false

    private var timer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundEntryTime: Date?
    private let notificationIdentifier = "practice_session_background_reminder"
    private var secondsSinceLastSave: Int = 0

    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0

    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        setupLifecycleObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        // Timer will continue running in background thanks to audio playback
        // Save current state in case app is terminated
        saveTimerState()

        // Track when we entered background
        if activeSession != nil && !isPaused {
            backgroundEntryTime = Date()
            scheduleBackgroundReminder()
        }
    }

    @objc private func appWillEnterForeground() {
        // Restore state if needed
        restoreTimerState()

        // Cancel any pending notifications
        cancelBackgroundReminder()
        backgroundEntryTime = nil
    }

    private func saveTimerState() {
        guard let activeSession = activeSession else { return }

        UserDefaults.standard.set(activeSession.objectID.uriRepresentation().absoluteString, forKey: "activeSessionID")
        UserDefaults.standard.set(startTime, forKey: "timerStartTime")
        UserDefaults.standard.set(accumulatedTime, forKey: "timerAccumulatedTime")
        UserDefaults.standard.set(isPaused, forKey: "timerIsPaused")
    }

    private func restoreTimerState() {
        // Only restore if we don't have an active session
        // (session might have been manually stopped)
        guard activeSession != nil else { return }

        // Recalculate elapsed time based on saved start time
        if let savedStartTime = UserDefaults.standard.object(forKey: "timerStartTime") as? Date,
           !isPaused {
            let savedAccumulated = UserDefaults.standard.double(forKey: "timerAccumulatedTime")
            let elapsedSinceStart = Date().timeIntervalSince(savedStartTime)
            let totalDuration = savedAccumulated + elapsedSinceStart

            // Update the display
            Task { @MainActor in
                self.elapsedTimeString = self.formatTime(seconds: totalDuration)
            }
        }
    }

    private func scheduleBackgroundReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Practice Session Active"
        content.body = "Your practice timer is still running in the background."
        content.sound = .default

        // Trigger after 5 minutes
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    private func cancelBackgroundReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier]
        )
    }

    func start(session: PracticeSessionCD) {
        stop() // Ensure any previous session is stopped

        activeSession = session
        TelemetryDeck.signal("session_timer_started")
        accumulatedTime = TimeInterval(session.durationMinutes * 60)
        isPaused = false
        secondsSinceLastSave = 0
        resume()

        // Start silent audio through AudioManager to keep app alive in background
        Task { @MainActor in
            AudioManager.shared.startTimerAudio()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil

        if let session = activeSession {
            // Perform one final save
            let finalDuration = isPaused ? accumulatedTime : accumulatedTime + Date().timeIntervalSince(startTime ?? Date())
            session.durationMinutes = Int64(finalDuration / 60)
            saveContext()
            TelemetryDeck.signal("session_timer_stopped", parameters: ["duration_minutes": "\(session.durationMinutes)"])
        }

        activeSession = nil
        isPaused = false
        accumulatedTime = 0
        elapsedTimeString = "00:00:00"
        backgroundEntryTime = nil
        secondsSinceLastSave = 0

        // Stop silent audio through AudioManager
        Task { @MainActor in
            AudioManager.shared.stopTimerAudio()
        }

        // Cancel any pending notifications
        cancelBackgroundReminder()

        // Clear saved state
        UserDefaults.standard.removeObject(forKey: "activeSessionID")
        UserDefaults.standard.removeObject(forKey: "timerStartTime")
        UserDefaults.standard.removeObject(forKey: "timerAccumulatedTime")
        UserDefaults.standard.removeObject(forKey: "timerIsPaused")

        endBackgroundTask()
    }

    func pause() {
        guard !isPaused, let startTime = self.startTime else { return }

        timer?.invalidate()
        timer = nil

        let elapsed = Date().timeIntervalSince(startTime)
        accumulatedTime += elapsed
        isPaused = true
        TelemetryDeck.signal("session_timer_paused")

        // Update the display to the exact paused time
        self.elapsedTimeString = self.formatTime(seconds: accumulatedTime)

        // Pause silent audio through AudioManager
        Task { @MainActor in
            AudioManager.shared.pauseTimerAudio()
        }

        // Cancel any pending notifications since timer is paused
        cancelBackgroundReminder()
        backgroundEntryTime = nil

        // A paused timer doesn't need to run in the background
        endBackgroundTask()
    }
    
    func resume() {
        //guard let session = activeSession, isPaused || timer == nil else { return }

        startTime = Date()
        isPaused = false
        TelemetryDeck.signal("session_timer_resumed")

        // Re-register background task when resuming
        registerBackgroundTask()

        // Resume silent audio through AudioManager to keep app alive in background
        Task { @MainActor in
            AudioManager.shared.resumeTimerAudio()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let activeSession = self.activeSession, let startTime = self.startTime else {
                self?.stop()
                return
            }

            let elapsedSinceResume = Date().timeIntervalSince(startTime)
            let totalDuration = self.accumulatedTime + elapsedSinceResume

            // Always update the display every second
            self.elapsedTimeString = self.formatTime(seconds: totalDuration)

            // Update the session duration in memory (no save yet)
            let totalMinutes = Int64(totalDuration / 60)
            activeSession.durationMinutes = totalMinutes

            // Only save to Core Data every 60 seconds to reduce I/O
            self.secondsSinceLastSave += 1
            if self.secondsSinceLastSave >= 60 {
                self.saveContext()
                self.secondsSinceLastSave = 0
            }
        }
    }

    private func formatTime(seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
    
    private func saveContext() {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            print("Failed to save session duration: \(error)")
        }
    }
    
    private func registerBackgroundTask() {
        if backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                // Background task is expiring, but don't stop the timer
                // The audio playback will keep the app alive
                // Just save current state and end the background task gracefully
                guard let self = self else { return }
                self.saveTimerState()
                if let session = self.activeSession, let startTime = self.startTime {
                    let totalDuration = self.accumulatedTime + Date().timeIntervalSince(startTime)
                    session.durationMinutes = Int64(totalDuration / 60)
                    self.saveContext()
                }
                self.endBackgroundTask()
            }
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}
