import SwiftUI
import CoreData

/// Controls for the session you're practicing in: timer, metronome, tuner, and recorder.
///
/// On iOS 26.1+ it's the tab view's bottom accessory, so it stays reachable on every tab.
/// On earlier versions it floats at the bottom of the screen (see `floatingPracticeBarStyle()`).
struct PracticeBarView: View {
    @ObservedObject var session: PracticeSessionCD
    /// Compact layout used when the bar is shown inline next to a minimized tab bar.
    var compact: Bool = false

    @EnvironmentObject private var manager: PracticeSessionManager
    @EnvironmentObject private var sessionTimerManager: SessionTimerManager

    var body: some View {
        HStack(spacing: 2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title ?? "Practice Session")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                PracticeBarStatusLine(session: session, recorder: manager.recorder)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !compact {
                timerButton
                MetronomeBarButton(engine: manager.metronome, action: openMetronome)
                Button(action: openTuner) {
                    Image(systemName: "tuningfork")
                }
                .accessibilityLabel("Tuner")
            }

            RecordBarButton(recorder: manager.recorder, action: manager.toggleRecording)

            if !compact {
                CloseBarButton(session: session, recorder: manager.recorder)
            }
        }
        .font(.title3)
        .buttonStyle(PracticeBarButtonStyle())
        .padding(.leading, 16)
        .padding(.trailing, 8)
    }

    private var isTimingThisSession: Bool { sessionTimerManager.activeSession == session }

    @ViewBuilder
    private var timerButton: some View {
        Button {
            if !isTimingThisSession {
                sessionTimerManager.start(session: session)
            } else if sessionTimerManager.isPaused {
                sessionTimerManager.resume()
            } else {
                sessionTimerManager.pause()
            }
        } label: {
            Image(systemName: timerIcon)
                .foregroundStyle(isTimingThisSession ? Color.accentColor : Color.primary)
        }
        .accessibilityLabel(timerAccessibilityLabel)
    }

    private var timerIcon: String {
        guard isTimingThisSession else { return "timer" }
        return sessionTimerManager.isPaused ? "play.fill" : "pause.fill"
    }

    private var timerAccessibilityLabel: String {
        guard isTimingThisSession else { return "Start Timer" }
        return sessionTimerManager.isPaused ? "Resume Timer" : "Pause Timer"
    }

    // The metronome and tuner are free inside a session (Pro unlocks them outside one).
    private func openMetronome() {
        manager.presentedTool = .metronome
    }

    private func openTuner() {
        manager.presentedTool = .tuner
    }
}

/// Gives every bar icon a full 44 pt tap target (Apple's minimum), not just the glyph.
private struct PracticeBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

extension View {
    /// Styling for the bar when it isn't hosted by the iOS 26 tab view accessory.
    func floatingPracticeBarStyle() -> some View {
        self
            .padding(.vertical, 4)
            .background(.bar, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(radius: 6)
            .padding(.horizontal)
            .padding(.bottom, 6)
    }
}

/// Recording state, running timer, or the student's name.
private struct PracticeBarStatusLine: View {
    @ObservedObject var session: PracticeSessionCD
    @ObservedObject var recorder: AudioRecorderManager
    @EnvironmentObject private var sessionTimerManager: SessionTimerManager

    var body: some View {
        Group {
            if recorder.isRecording {
                Label(recorder.isPaused ? "Recording paused \(recorder.elapsedTimeString)" : "Recording \(recorder.elapsedTimeString)",
                      systemImage: "record.circle.fill")
                    .foregroundStyle(.red)
            } else if sessionTimerManager.activeSession == session {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let time = SessionTimerManager.format(sessionTimerManager.elapsed(at: context.date))
                    Text(sessionTimerManager.isPaused ? "\(time) · Paused" : time)
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
            } else {
                Text(session.student?.name ?? "Practice")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .lineLimit(1)
    }
}

private struct MetronomeBarButton: View {
    @ObservedObject var engine: MetronomeEngine
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: "metronome")
                if engine.isRunning {
                    // Shows the metronome is still going after its sheet was closed.
                    Text("\(Int(engine.bpm))")
                        .font(.caption.weight(.bold).monospacedDigit())
                }
            }
            .foregroundStyle(engine.isRunning ? Color.accentColor : Color.primary)
        }
        .accessibilityLabel(engine.isRunning ? "Metronome, playing at \(Int(engine.bpm)) BPM" : "Metronome")
    }
}

private struct RecordBarButton: View {
    @ObservedObject var recorder: AudioRecorderManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.fill")
                .foregroundStyle(.red)
        }
        .accessibilityLabel(recorder.isRecording ? "Stop Recording" : "Record Audio")
    }
}

/// Dismisses the bar. If a timer or recording is running it asks first, so the bar can
/// always be closed from any tab (the bar itself has no timer Stop button).
private struct CloseBarButton: View {
    @ObservedObject var session: PracticeSessionCD
    @ObservedObject var recorder: AudioRecorderManager
    @EnvironmentObject private var manager: PracticeSessionManager
    @EnvironmentObject private var sessionTimerManager: SessionTimerManager

    @State private var showingEndConfirmation = false

    private var isTiming: Bool { sessionTimerManager.activeSession == session }

    var body: some View {
        Button {
            if manager.hasActivityToEnd {
                showingEndConfirmation = true
            } else {
                manager.close()
            }
        } label: {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Close Practice Bar")
        .confirmationDialog("End practice?", isPresented: $showingEndConfirmation, titleVisibility: .visible) {
            Button("Stop & Close", role: .destructive) {
                manager.close(stopTimer: true)
            }
            if isTiming && !recorder.isRecording {
                Button("Close, Keep Timer Running") {
                    manager.close(stopTimer: false)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(confirmationMessage)
        }
    }

    private var confirmationMessage: String {
        switch (isTiming, recorder.isRecording) {
        case (true, true): "The timer will stop and the recording will be saved to this session."
        case (true, false): "Stopping saves the timed duration to this session."
        default: "The recording will be saved to this session."
        }
    }
}

/// iOS 26 accessory wrapper: switches to the compact layout when the accessory is inline.
@available(iOS 26.0, *)
struct PracticeBarAccessory: View {
    @ObservedObject var session: PracticeSessionCD
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        PracticeBarView(session: session, compact: placement == .inline)
    }
}

/// Hosts the practice bar as the tab view's bottom accessory where supported (iOS 26.1+).
/// On iOS 26.0 the session screen shows the floating bar instead (see SessionDetailViewCD).
struct PracticeBarAccessoryModifier: ViewModifier {
    let session: PracticeSessionCD?

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: session != nil) {
                if let session {
                    PracticeBarAccessory(session: session)
                }
            }
        } else {
            content
        }
    }
}
