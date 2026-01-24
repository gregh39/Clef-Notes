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
    private var audioPlayer: AVAudioPlayer?
    private var backgroundEntryTime: Date?
    private let notificationIdentifier = "practice_session_background_reminder"

    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0

    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        setupBackgroundAudio()
        setupLifecycleObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupBackgroundAudio() {
        // Configure audio session for background playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }

        // Create a silent audio file in memory
        // This plays a 1-second silent audio file in a loop to keep the app alive in background
        let silenceURL = createSilentAudioFile()

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: silenceURL)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.0 // Silent
            audioPlayer?.prepareToPlay()
        } catch {
            print("Failed to create audio player: \(error)")
        }
    }

    private func createSilentAudioFile() -> URL {
        // Create a silent audio file (1 second of silence)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let frameCount = AVAudioFrameCount(44100) // 1 second
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        // Write to a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("silence.m4a")

        // If file already exists, return it
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        // Create a simple silent audio file
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 64000
        ]

        do {
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
            try audioFile.write(from: buffer)
        } catch {
            print("Failed to create silent audio file: \(error)")
        }

        return fileURL
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

        // Handle audio interruptions (like when YouTube starts playing)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
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

    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Another app (like YouTube) started playing audio
            // Our silent audio will be paused, but that's okay
            // The timer will keep running in memory
            print("Audio interrupted - timer continues in memory")

        case .ended:
            // The other app stopped, we can resume our silent audio if timer is still running
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

            if options.contains(.shouldResume) && activeSession != nil && !isPaused {
                // Resume our silent audio to maintain background execution
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    audioPlayer?.play()
                } catch {
                    print("Failed to resume audio session: \(error)")
                }
            }

        @unknown default:
            break
        }
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
        resume()

        // Start silent audio to keep app alive in background
        audioPlayer?.play()
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

        // Stop silent audio
        audioPlayer?.stop()

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

        // Stop silent audio when paused
        audioPlayer?.pause()

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

        // Resume silent audio to keep app alive in background
        audioPlayer?.play()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let activeSession = self.activeSession, let startTime = self.startTime else {
                self?.stop()
                return
            }

            let elapsedSinceResume = Date().timeIntervalSince(startTime)
            let totalDuration = self.accumulatedTime + elapsedSinceResume

            self.elapsedTimeString = self.formatTime(seconds: totalDuration)

            let totalMinutes = Int64(totalDuration / 60)
            if activeSession.durationMinutes != totalMinutes {
                activeSession.durationMinutes = totalMinutes
                self.saveContext()
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
                self?.stop()
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
