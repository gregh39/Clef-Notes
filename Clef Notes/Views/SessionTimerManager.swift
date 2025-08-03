import Foundation
import CoreData
import SwiftUI
import Combine
import TelemetryDeck

@MainActor
class SessionTimerManager: ObservableObject {
    @Published var activeSession: PracticeSessionCD?
    @Published var elapsedTimeString: String = "00:00:00"
    @Published var isPaused = false

    private var timer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0
    
    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    func start(session: PracticeSessionCD) {
        stop() // Ensure any previous session is stopped
        
        activeSession = session
        TelemetryDeck.signal("session_timer_started")
        accumulatedTime = TimeInterval(session.durationMinutes * 60)
        isPaused = false
        resume()
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
        
        // A paused timer doesn't need to run in the background
        endBackgroundTask()
    }
    
    func resume() {
        guard let session = activeSession, isPaused || timer == nil else { return }

        startTime = Date()
        isPaused = false
        TelemetryDeck.signal("session_timer_resumed")
        
        // Re-register background task when resuming
        registerBackgroundTask()

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
