//
//  PracticeTimerLiveActivity.swift
//  ClefNotesWidgets
//
//  Lock Screen / Dynamic Island presentation of a running practice-session timer.
//  `PracticeTimerAttributes` and the button intents live in the app's
//  Shared/PracticeTimerActivity.swift, which is compiled into this target too.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

/// Colors for the two timer states. Running uses the app's default blue; paused uses orange
/// so the state reads at a glance, even in the tiny compact/minimal Dynamic Island views.
private enum TimerPalette {
    static let running = Color.blue
    static let paused = Color.orange

    static func tint(for state: PracticeTimerAttributes.ContentState) -> Color {
        state.isPaused ? paused : running
    }
}

struct PracticeTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PracticeTimerAttributes.self) { context in
            LockScreenTimerView(attributes: context.attributes, state: context.state)
                .padding(16)
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(TimerPalette.running)
        } dynamicIsland: { context in
            let tint = TimerPalette.tint(for: context.state)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 10) {
                        StatusBadge(state: context.state, size: 38)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.sessionTitle)
                                .font(.headline)
                                .lineLimit(1)
                            SubtitleText(attributes: context.attributes, state: context.state)
                                .font(.caption)
                        }
                    }
                    .padding(.leading, 4)
                    .dynamicIsland(verticalPlacement: .belowIfTooWide)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: context.state)
                        .font(.system(.title2, design: .rounded).monospacedDigit().weight(.semibold))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 104, alignment: .trailing)
                        .frame(maxHeight: .infinity)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WideTimerControls(state: context.state)
                        .padding(.top, 6)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "music.note")
                    .foregroundStyle(tint)
            } compactTrailing: {
                CompactElapsedText(state: context.state)
                    .foregroundStyle(tint)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "music.note")
                    .foregroundStyle(tint)
            }
            .keylineTint(tint)
        }
    }
}

/// Shows the elapsed time. While running, the system renders a live, self-updating timer.
private struct ElapsedText: View {
    let state: PracticeTimerAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Text(pausedString)
        } else {
            Text(state.referenceStart, style: .timer)
        }
    }

    /// Matches the `.timer` style (M:SS under an hour, H:MM:SS after) so the
    /// digits don't jump when pausing.
    private var pausedString: String {
        let total = max(0, Int(state.accumulated))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%i:%02i:%02i", hours, minutes, seconds)
            : String(format: "%i:%02i", minutes, seconds)
    }
}

/// Elapsed time sized to its digits. A `.timer` Text stretches to fill whatever width it's
/// offered, leaving a gap after the digits in the compact island. A hidden template string sets
/// the width instead ("00:00" under an hour, "0:00:00" after), and the timer sits trailing-aligned
/// on top. If the hour mark passes without an activity update, the text scales down rather than
/// truncating.
private struct CompactElapsedText: View {
    let state: PracticeTimerAttributes.ContentState

    var body: some View {
        let elapsed = state.accumulated + (state.segmentStart.map { Date.now.timeIntervalSince($0) } ?? 0)
        Text(elapsed >= 3600 ? "0:00:00" : "00:00")
            .hidden()
            .overlay(alignment: .trailing) {
                ElapsedText(state: state)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .monospacedDigit()
    }
}

/// Round tinted icon showing whether the session is running or paused.
private struct StatusBadge: View {
    let state: PracticeTimerAttributes.ContentState
    var size: CGFloat = 40

    var body: some View {
        let tint = TimerPalette.tint(for: state)
        Image(systemName: state.isPaused ? "pause.fill" : "music.note")
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.2), in: Circle())
    }
}

/// "Student · Practicing" / "Student · Paused", with the state in the timer's tint.
private struct SubtitleText: View {
    let attributes: PracticeTimerAttributes
    let state: PracticeTimerAttributes.ContentState

    var body: some View {
        HStack(spacing: 4) {
            if !attributes.studentName.isEmpty {
                Text(attributes.studentName)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
            }
            Text(state.isPaused ? "Paused" : "Practicing")
                .fontWeight(.semibold)
                .foregroundStyle(TimerPalette.tint(for: state))
        }
        .lineLimit(1)
    }
}

/// Compact round buttons for the Lock Screen.
private struct TimerControls: View {
    let state: PracticeTimerAttributes.ContentState

    var body: some View {
        HStack(spacing: 10) {
            if state.isPaused {
                Button(intent: ResumePracticeTimerIntent()) {
                    CircleButtonLabel(title: "Resume", systemImage: "play.fill", tint: TimerPalette.running)
                }
            } else {
                Button(intent: PausePracticeTimerIntent()) {
                    CircleButtonLabel(title: "Pause", systemImage: "pause.fill", tint: TimerPalette.paused)
                }
            }
            Button(intent: StopPracticeTimerIntent()) {
                CircleButtonLabel(title: "Stop", systemImage: "stop.fill", tint: .red)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CircleButtonLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 46, height: 46)
            .background(tint.opacity(0.2), in: Circle())
    }
}

/// Full-width capsule buttons for the expanded Dynamic Island.
private struct WideTimerControls: View {
    let state: PracticeTimerAttributes.ContentState

    var body: some View {
        HStack(spacing: 10) {
            if state.isPaused {
                Button(intent: ResumePracticeTimerIntent()) {
                    CapsuleButtonLabel(title: "Resume", systemImage: "play.fill", tint: TimerPalette.running)
                }
            } else {
                Button(intent: PausePracticeTimerIntent()) {
                    CapsuleButtonLabel(title: "Pause", systemImage: "pause.fill", tint: TimerPalette.paused)
                }
            }
            Button(intent: StopPracticeTimerIntent()) {
                CapsuleButtonLabel(title: "Stop", systemImage: "stop.fill", tint: .red)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CapsuleButtonLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(tint.opacity(0.22), in: Capsule())
    }
}

private struct LockScreenTimerView: View {
    let attributes: PracticeTimerAttributes
    let state: PracticeTimerAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                StatusBadge(state: state, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(attributes.sessionTitle)
                        .font(.headline)
                        .lineLimit(1)
                    SubtitleText(attributes: attributes, state: state)
                        .font(.caption)
                }
                Spacer(minLength: 0)
                Image(systemName: "music.quarternote.3")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .center, spacing: 12) {
                ElapsedText(state: state)
                    .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(state.isPaused ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TimerControls(state: state)
            }
        }
    }
}

#Preview("Lock Screen", as: .content, using: PracticeTimerAttributes(sessionTitle: "Practice", studentName: "Alice")) {
    PracticeTimerLiveActivity()
} contentStates: {
    PracticeTimerAttributes.ContentState(segmentStart: .now, accumulated: 754)
    PracticeTimerAttributes.ContentState(segmentStart: nil, accumulated: 1_234)
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: PracticeTimerAttributes(sessionTitle: "Practice", studentName: "Alice")) {
    PracticeTimerLiveActivity()
} contentStates: {
    PracticeTimerAttributes.ContentState(segmentStart: .now, accumulated: 754)
    PracticeTimerAttributes.ContentState(segmentStart: nil, accumulated: 1_234)
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: PracticeTimerAttributes(sessionTitle: "Practice", studentName: "Alice")) {
    PracticeTimerLiveActivity()
} contentStates: {
    PracticeTimerAttributes.ContentState(segmentStart: .now, accumulated: 754)
    PracticeTimerAttributes.ContentState(segmentStart: nil, accumulated: 1_234)
}
