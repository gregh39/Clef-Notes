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

struct PracticeTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PracticeTimerAttributes.self) { context in
            LockScreenTimerView(attributes: context.attributes, state: context.state)
                .padding()
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.sessionTitle)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "music.note")
                    }
                    .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: context.state)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if !context.attributes.studentName.isEmpty {
                            Text(context.attributes.studentName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        TimerControls(state: context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
            } compactTrailing: {
                ElapsedText(state: context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
            }
        }
    }
}

/// Shows the elapsed time. While running, the system renders a live, self-updating timer.
private struct ElapsedText: View {
    let state: PracticeTimerAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Text(PracticeTimerFormat.string(from: state.accumulated))
        } else {
            Text(state.referenceStart, style: .timer)
        }
    }
}

private struct TimerControls: View {
    let state: PracticeTimerAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            if state.isPaused {
                Button(intent: ResumePracticeTimerIntent()) {
                    Label("Resume", systemImage: "play.fill")
                }
            } else {
                Button(intent: PausePracticeTimerIntent()) {
                    Label("Pause", systemImage: "pause.fill")
                }
            }
            Button(intent: StopPracticeTimerIntent()) {
                Label("Stop", systemImage: "stop.fill")
            }
            .tint(.red)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .font(.title3)
    }
}

private struct LockScreenTimerView: View {
    let attributes: PracticeTimerAttributes
    let state: PracticeTimerAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(attributes.sessionTitle)
                    .font(.headline)
                    .lineLimit(1)
                if !attributes.studentName.isEmpty {
                    Text(attributes.studentName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    ElapsedText(state: state)
                        .font(.title.monospacedDigit().weight(.semibold))
                    if state.isPaused {
                        Text("Paused")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            TimerControls(state: state)
        }
    }
}

#Preview("Lock Screen", as: .content, using: PracticeTimerAttributes(sessionTitle: "Practice", studentName: "Alice")) {
    PracticeTimerLiveActivity()
} contentStates: {
    PracticeTimerAttributes.ContentState(segmentStart: .now, accumulated: 754)
    PracticeTimerAttributes.ContentState(segmentStart: nil, accumulated: 1_234)
}
