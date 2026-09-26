// Clef Notes/Shared/PracticeTimerActivity.swift
//
// Compiled into BOTH the app and the ClefNotesWidgetsExtension target (via a membership
// exception in the project), so the Live Activity's attributes and button intents are the
// same types in both processes.

import Foundation
import ActivityKit
import AppIntents

/// Live Activity describing a running practice-session timer.
///
/// The elapsed time is never pushed every second. The state only carries timestamps, and the
/// widget renders them with `Text(_:style: .timer)`, which the system keeps ticking on its own.
nonisolated struct PracticeTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Start of the current running segment; nil while paused.
        var segmentStart: Date?
        /// Seconds accumulated before the current segment.
        var accumulated: TimeInterval

        var isPaused: Bool { segmentStart == nil }

        /// A date such that "now - referenceStart" equals the total elapsed time while running.
        var referenceStart: Date {
            (segmentStart ?? .now).addingTimeInterval(-accumulated)
        }
    }

    var sessionTitle: String
    var studentName: String
}

/// Formats seconds as HH:MM:SS. Shared by the app UI and the widget.
nonisolated enum PracticeTimerFormat {
    static func string(from seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02i:%02i:%02i", total / 3600, (total % 3600) / 60, total % 60)
    }
}

// MARK: - Live Activity buttons

enum TimerIntentAction: Sendable {
    case pause, resume, stop
}

/// `LiveActivityIntent`s run in the app's process. The app registers a handler here at launch
/// (see `SessionTimerManager`); in the widget process it stays nil and is never called.
enum TimerIntentBridge {
    @MainActor static var handler: ((TimerIntentAction) -> Void)?
}

struct PausePracticeTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause Practice Timer"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await MainActor.run { TimerIntentBridge.handler?(.pause) }
        return .result()
    }
}

struct ResumePracticeTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume Practice Timer"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await MainActor.run { TimerIntentBridge.handler?(.resume) }
        return .result()
    }
}

struct StopPracticeTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Practice Timer"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await MainActor.run { TimerIntentBridge.handler?(.stop) }
        return .result()
    }
}
