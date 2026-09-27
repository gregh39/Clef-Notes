import SwiftUI
import CoreData

/// Presentations driven by the practice bar: the metronome/tuner sheets and the
/// "save recording" sheet. Applied once, to the whole student detail screen, so they work
/// from any tab.
struct PracticeSessionChrome: ViewModifier {
    let student: StudentCD

    @ObservedObject private var manager = PracticeSessionManager.shared
    @ObservedObject private var recorder = PracticeSessionManager.shared.recorder

    @State private var recordingURLForSheet: URL?
    @State private var newRecordingTitle = ""
    @State private var selectedSongsForRecording: Set<SongCD> = []

    func body(content: Content) -> some View {
        content
            .sheet(item: $manager.presentedTool) { tool in
                NavigationStack {
                    Group {
                        switch tool {
                        case .metronome:
                            // Keeps playing after the sheet closes; the bar shows it's on.
                            MetronomeSectionView(stopsOnDisappear: false)
                        case .tuner:
                            TunerTabView()
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { manager.presentedTool = nil }
                        }
                    }
                }
                // Half height by default so the session (plays, notes) stays usable behind it.
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .sheet(item: $recordingURLForSheet, onDismiss: {
                // "Retake" starts a new recording before the sheet finishes dismissing;
                // don't tear that new recording down.
                if !recorder.isRecording {
                    recorder.reset()
                }
                newRecordingTitle = ""
                selectedSongsForRecording = []
            }) { url in
                RecordingMetadataSheetCD(
                    fileURL: url,
                    songs: manager.recordingSession?.student?.songsArray ?? [],
                    newRecordingTitle: $newRecordingTitle,
                    selectedSongs: $selectedSongsForRecording,
                    onSave: { title, songs in
                        manager.saveRecording(url: url, title: title, songs: songs)
                    },
                    onRetake: {
                        recorder.reset()
                        manager.toggleRecording()
                    }
                )
            }
            .onChange(of: recorder.finishedRecordingURL) { _, newValue in
                guard let newURL = newValue else { return }
                DispatchQueue.main.async {
                    // Skip if the recording was auto-saved and reset in the meantime.
                    guard recorder.finishedRecordingURL == newURL else { return }
                    recordingURLForSheet = newURL
                }
            }
            .onAppear {
                manager.studentDidChange(to: student)
            }
    }
}

extension View {
    func practiceSessionChrome(for student: StudentCD) -> some View {
        modifier(PracticeSessionChrome(student: student))
    }
}
