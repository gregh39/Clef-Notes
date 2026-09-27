import Foundation
import CoreData
import AVFoundation
import Combine

/// App-level state for "the session you're practicing in".
///
/// A session becomes current as soon as it's opened (timed or not) and stays current while
/// you move between tabs, so the practice bar (`PracticeBarView`) can offer the metronome,
/// tuner, and recorder from anywhere. The metronome engine and the recorder live here rather
/// than in a screen, so they keep running when their sheet closes or you switch tabs.
@MainActor
final class PracticeSessionManager: ObservableObject {

    static let shared = PracticeSessionManager()

    enum Tool: String, Identifiable {
        case metronome, tuner
        var id: String { rawValue }
    }

    /// The session the practice bar is attached to.
    @Published private(set) var currentSession: PracticeSessionCD?
    /// Tool sheet currently presented from the practice bar.
    @Published var presentedTool: Tool?

    /// Shared so it keeps playing after its sheet is dismissed.
    let metronome = MetronomeEngine()
    let recorder: AudioRecorderManager

    /// The session an in-progress (or just finished) recording will be saved to. Captured
    /// when recording starts, in case the current session changes before it's saved.
    private(set) var recordingSession: PracticeSessionCD?

    private let viewContext: NSManagedObjectContext
    private var contextObserver: NSObjectProtocol?

    private init() {
        viewContext = PersistenceController.shared.persistentContainer.viewContext
        recorder = AudioRecorderManager(audioManager: AudioManager.shared)
        // A timer restored at launch brings its session back as the current one.
        currentSession = SessionTimerManager.shared.activeSession

        contextObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: viewContext,
            queue: .main
        ) { [weak self] note in
            let deleted = note.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
            guard !deleted.isEmpty else { return }
            MainActor.assumeIsolated { self?.handleDeleted(deleted) }
        }
    }

    // MARK: - Current session

    /// Call when a session screen is shown.
    func open(_ session: PracticeSessionCD) {
        if currentSession != session {
            currentSession = session
        }
    }

    /// True when closing the bar would affect something still running (timer or recording),
    /// so the bar asks before closing.
    var hasActivityToEnd: Bool {
        guard let session = currentSession else { return false }
        return recorder.isRecording || SessionTimerManager.shared.activeSession == session
    }

    /// Dismisses the bar. An in-progress recording is always saved first; the timer is
    /// stopped (saving its duration) only if `stopTimer` is true, otherwise it keeps running
    /// (the Live Activity still shows it, and reopening the session brings the bar back).
    func close(stopTimer: Bool = true) {
        if recorder.isRecording {
            autoSaveRecording()
        }
        if stopTimer, let session = currentSession, SessionTimerManager.shared.activeSession == session {
            SessionTimerManager.shared.stop()
        }
        stopMetronome()
        presentedTool = nil
        currentSession = nil
    }

    /// Called when the student detail screen appears. A session from another student is put
    /// away: its recording is saved, and the metronome stops.
    func studentDidChange(to student: StudentCD) {
        if let session = currentSession, session.student != student {
            if recorder.isRecording {
                autoSaveRecording()
            }
            stopMetronome()
            presentedTool = nil
            currentSession = nil
        }
        // A running timer for this student keeps its session attached.
        if currentSession == nil,
           let timed = SessionTimerManager.shared.activeSession,
           timed.student == student {
            currentSession = timed
        }
    }

    private func handleDeleted(_ deleted: Set<NSManagedObject>) {
        if let recordingSession, deleted.contains(recordingSession) {
            recorder.discardRecording()
            self.recordingSession = nil
        }
        if let session = currentSession, deleted.contains(session) {
            stopMetronome()
            presentedTool = nil
            currentSession = nil
        }
    }

    // MARK: - Metronome

    func stopMetronome() {
        guard metronome.isRunning else { return }
        metronome.stop()
        AudioManager.shared.releaseSession(for: .metronome)
    }

    // MARK: - Recording

    func toggleRecording() {
        if recorder.isRecording {
            // Publishes finishedRecordingURL; PracticeSessionChrome presents the save sheet.
            recorder.stopRecording()
        } else {
            guard let session = currentSession else { return }
            recordingSession = session
            recorder.startRecording()
        }
    }

    func saveRecording(url: URL, title: String, songs: Set<SongCD>) {
        guard let session = recordingSession, !session.isDeleted else { return }
        do {
            let audioData = try Data(contentsOf: url)
            let duration = (try? AVAudioPlayer(data: audioData))?.duration ?? 0

            let recording = AudioRecordingCD(context: viewContext)
            recording.id = UUID()
            recording.data = audioData
            recording.dateRecorded = .now
            recording.title = title.isEmpty ? "Recording" : title
            recording.duration = duration
            recording.session = session
            recording.addToSongs(songs as NSSet)
            recording.student = session.student

            try viewContext.save()
        } catch {
            print("Error saving recorded file data: \(error)")
        }
    }

    /// Stops the current recording and saves it with a default title and no linked songs.
    func autoSaveRecording() {
        recorder.stopRecording()
        if let url = recorder.finishedRecordingURL {
            saveRecording(url: url, title: "Recording", songs: [])
        }
        recorder.reset()
    }
}
