import Foundation
import CoreData
import SwiftUI
import Combine
import TelemetryDeck
import ActivityKit
import UserNotifications

/// Tracks the single running practice-session timer.
///
/// Time is derived from timestamps (`accumulated` + time since `segmentStart`) rather than
/// counted by a background timer, so it stays correct while the app is suspended or even
/// terminated and needs no background execution. Views that show the clock redraw themselves
/// with `TimelineView` (see `elapsed(at:)`), and a Live Activity shows it on the Lock Screen
/// and Dynamic Island.
@MainActor
final class SessionTimerManager: ObservableObject {

    static let shared = SessionTimerManager(context: PersistenceController.shared.persistentContainer.viewContext)

    @Published private(set) var activeSession: PracticeSessionCD?
    @Published private(set) var isPaused = false

    /// Start of the current running segment; nil while paused or stopped.
    private var segmentStart: Date?
    /// Seconds accumulated before the current segment (including the session's prior duration).
    private var accumulated: TimeInterval = 0

    private let viewContext: NSManagedObjectContext
    private var activity: Activity<PracticeTimerAttributes>?
    private var lifecycleObservers: [NSObjectProtocol] = []

    /// If the app was terminated while running and wasn't opened again for this long,
    /// the timer is restored paused at the moment the app was last active instead of
    /// counting the whole gap as practice.
    private static let staleRestoreThreshold: TimeInterval = 6 * 60 * 60

    private enum Keys {
        static let sessionURI = "sessionTimer.sessionURI"
        static let accumulated = "sessionTimer.accumulated"
        static let segmentStart = "sessionTimer.segmentStart"
        static let lastActiveAt = "sessionTimer.lastActiveAt"
    }

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        removeLegacyState()
        restoreState()
        setupLifecycleObservers()

        TimerIntentBridge.handler = { [weak self] action in
            guard let self else { return }
            switch action {
            case .pause: self.pause()
            case .resume: self.resume()
            case .stop: self.stop()
            }
        }
    }

    // MARK: - Elapsed time

    /// Total elapsed seconds for the active session at `date`.
    func elapsed(at date: Date = .now) -> TimeInterval {
        accumulated + (segmentStart.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    static func format(_ seconds: TimeInterval) -> String {
        PracticeTimerFormat.string(from: seconds)
    }

    // MARK: - Controls

    func start(session: PracticeSessionCD) {
        stop() // Ensure any previous session is stopped

        if session.objectID.isTemporaryID {
            try? viewContext.obtainPermanentIDs(for: [session])
        }

        activeSession = session
        accumulated = TimeInterval(session.totalSeconds)
        segmentStart = .now
        isPaused = false

        persistState()
        startActivity(for: session)
        TelemetryDeck.signal("session_timer_started")
    }

    func pause() {
        guard activeSession != nil, let start = segmentStart else { return }

        accumulated += max(0, Date().timeIntervalSince(start))
        segmentStart = nil
        isPaused = true

        writeDurationToSession()
        persistState()
        updateActivity()
        TelemetryDeck.signal("session_timer_paused")
    }

    func resume() {
        guard activeSession != nil, segmentStart == nil else { return }

        segmentStart = .now
        isPaused = false

        persistState()
        updateActivity()
        TelemetryDeck.signal("session_timer_resumed")
    }

    func stop() {
        guard let session = activeSession else { return }

        writeDurationToSession()
        TelemetryDeck.signal("session_timer_stopped", parameters: ["duration_minutes": "\(session.durationMinutes)"])

        activeSession = nil
        segmentStart = nil
        accumulated = 0
        isPaused = false

        clearPersistedState()
        endActivity()
    }

    /// Call after the session's duration was edited by hand while its timer is active,
    /// so the timer continues from the edited value instead of overwriting it.
    func durationWasEdited(for session: PracticeSessionCD) {
        guard session == activeSession else { return }
        accumulated = TimeInterval(session.totalSeconds)
        if segmentStart != nil {
            segmentStart = .now
        }
        persistState()
        updateActivity()
    }

    // MARK: - Core Data

    private func writeDurationToSession() {
        guard let session = activeSession, !session.isDeleted else { return }
        session.setDuration(seconds: Int64(elapsed()))
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            print("Failed to save session duration: \(error)")
        }
    }

    // MARK: - Lifecycle

    private func setupLifecycleObservers() {
        let center = NotificationCenter.default
        lifecycleObservers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkpoint() }
        })
    }

    /// Saves the current duration so other devices and the stats see up-to-date time,
    /// and records when the app was last active (used by `restoreState()`).
    private func checkpoint() {
        guard activeSession != nil else { return }
        writeDurationToSession()
        persistState()
    }

    // MARK: - Persistence (survives termination)

    private func persistState() {
        guard let session = activeSession else { return }
        let defaults = UserDefaults.standard
        defaults.set(session.objectID.uriRepresentation().absoluteString, forKey: Keys.sessionURI)
        defaults.set(accumulated, forKey: Keys.accumulated)
        defaults.set(segmentStart, forKey: Keys.segmentStart)
        defaults.set(Date(), forKey: Keys.lastActiveAt)
    }

    private func clearPersistedState() {
        let defaults = UserDefaults.standard
        [Keys.sessionURI, Keys.accumulated, Keys.segmentStart, Keys.lastActiveAt].forEach(defaults.removeObject)
    }

    private func restoreState() {
        let defaults = UserDefaults.standard
        guard let uriString = defaults.string(forKey: Keys.sessionURI),
              let uri = URL(string: uriString),
              let coordinator = viewContext.persistentStoreCoordinator,
              let objectID = coordinator.managedObjectID(forURIRepresentation: uri),
              let session = try? viewContext.existingObject(with: objectID) as? PracticeSessionCD,
              !session.isDeleted else {
            clearPersistedState()
            endAllActivities()
            return
        }

        accumulated = defaults.double(forKey: Keys.accumulated)
        segmentStart = defaults.object(forKey: Keys.segmentStart) as? Date

        if let start = segmentStart,
           let lastActive = defaults.object(forKey: Keys.lastActiveAt) as? Date,
           Date().timeIntervalSince(lastActive) > Self.staleRestoreThreshold {
            accumulated += max(0, lastActive.timeIntervalSince(start))
            segmentStart = nil
        }

        activeSession = session
        isPaused = segmentStart == nil
        persistState()

        if let existing = Activity<PracticeTimerAttributes>.activities.first {
            activity = existing
            updateActivity()
        } else {
            startActivity(for: session)
        }
    }

    /// Clears state written by the previous (silent-audio) timer implementation.
    private func removeLegacyState() {
        let defaults = UserDefaults.standard
        ["activeSessionID", "timerStartTime", "timerAccumulatedTime", "timerIsPaused"].forEach(defaults.removeObject)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["practice_session_background_reminder"])
    }

    // MARK: - Live Activity

    private var activityState: PracticeTimerAttributes.ContentState {
        .init(segmentStart: segmentStart, accumulated: accumulated)
    }

    private func startActivity(for session: PracticeSessionCD) {
        endAllActivities()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = PracticeTimerAttributes(
            sessionTitle: session.title ?? "Practice Session",
            studentName: session.student?.name ?? ""
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: activityState, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Failed to start practice timer Live Activity: \(error)")
        }
    }

    private func updateActivity() {
        guard let activity else { return }
        let content = ActivityContent(state: activityState, staleDate: nil)
        Task { await activity.update(content) }
    }

    private func endActivity() {
        guard let activity else { return }
        self.activity = nil
        let content = ActivityContent(state: activityState, staleDate: nil)
        Task { await activity.end(content, dismissalPolicy: .immediate) }
    }

    private func endAllActivities() {
        activity = nil
        for existing in Activity<PracticeTimerAttributes>.activities {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
