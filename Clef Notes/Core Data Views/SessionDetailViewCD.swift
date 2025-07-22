import SwiftUI
import CoreData
import AVFoundation

struct SessionDetailViewCD: View {
    @ObservedObject var session: PracticeSessionCD
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var sessionTimerManager: SessionTimerManager
    @AppStorage("selectedAccentColor") private var accentColor: AccentColor = .blue

    @State private var showingAddPlaySheet = false
    @State private var showingAddSongSheet = false
    @State private var showingEditSessionSheet = false
    @State private var showingRandomSongPicker = false
    @State private var showingAddNoteSheet = false
    @State private var showingRecordingMetadataSheet = false

    @State private var editingNote: NoteCD?
    @State private var playToEdit: PlayCD?

    @StateObject private var audioRecorderManager: AudioRecorderManager
    @StateObject private var audioPlayerManager: AudioPlayerManager
    
    @State private var newRecordingTitle = ""
    @State private var selectedSongsForRecording: Set<SongCD> = []

    init(session: PracticeSessionCD, audioManager: AudioManager) {
        self.session = session
        _audioRecorderManager = StateObject(wrappedValue: AudioRecorderManager(audioManager: audioManager))
        _audioPlayerManager = StateObject(wrappedValue: AudioPlayerManager(audioManager: audioManager))
    }
    
    private var durationString: String {
        let totalMinutes = session.durationMinutes
        let hours = Int(totalMinutes) / 60
        let minutes = Int(totalMinutes) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        TabView {
            sessionTab
                .tabItem { Label("Session", systemImage: "calendar") }
            
            if let student = session.student {
                StudentSongsTabViewCD(student: student) {
                    showingAddSongSheet = true
                }
                .tabItem { Label("Songs", systemImage: "music.note.list") }
            }
            
            MetronomeSectionView()
                .tabItem { Label("Metronome", systemImage: "metronome") }
            
            TunerTabView()
                .tabItem { Label("Tuner", systemImage: "tuningfork") }
        }
        .navigationTitle(session.title ?? "Practice Session")
        .toolbar {
            // --- THIS IS THE FIX: The toolbar now includes the recording button ---
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    if audioRecorderManager.isRecording {
                        audioRecorderManager.stopRecording()
                    } else {
                        audioRecorderManager.startRecording()
                    }
                }) {
                    Image(systemName: audioRecorderManager.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.title2)
                        .foregroundColor(audioRecorderManager.isRecording ? .red : .accentColor)
                }
                .animation(.spring(), value: audioRecorderManager.isRecording)

                Button(action: { showingRandomSongPicker = true }) {
                    Image(systemName: "die.face.5")
                }
                .accessibilityLabel("Pick Random Song")
                
                Button { showingEditSessionSheet = true } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingAddPlaySheet) {
            AddPlaySheetViewCD(session: session, showingAddPlaySheet: $showingAddPlaySheet, showingAddSongSheet: $showingAddSongSheet)
        }
        .sheet(isPresented: $showingAddSongSheet) {
            if let student = session.student {
                AddSongSheetCD(student: student)
            }
        }
        .sheet(item: $editingNote) { note in
            AddNoteSheetCD(note: note)
        }
        .sheet(item: $playToEdit) { play in
            PlayEditSheetCD(play: play)
        }
        .sheet(isPresented: $showingEditSessionSheet) {
            EditSessionSheetCD(session: session)
        }
        .sheet(isPresented: $showingRandomSongPicker) {
            if let songs = session.student?.songsArray {
                RandomSongPickerViewCD(songs: songs)
            }
        }
        .sheet(isPresented: $showingRecordingMetadataSheet, onDismiss: clearRecordingMetadataFields) {
            if let url = audioRecorderManager.finishedRecordingURL, let songs = session.student?.songsArray {
                RecordingMetadataSheetCD(
                    fileURL: url,
                    songs: songs,
                    newRecordingTitle: $newRecordingTitle,
                    selectedSongs: $selectedSongsForRecording,
                    onSave: saveRecording
                )
            }
        }
        .onChange(of: audioRecorderManager.finishedRecordingURL) {
            if audioRecorderManager.finishedRecordingURL != nil {
                showingRecordingMetadataSheet = true
            }
        }
    }

    private var sessionTab: some View {
        Form {
            Section("Duration") {
                ZStack {
                    activeTimerControls
                        .opacity(sessionTimerManager.activeSession == session ? 1 : 0)
                    
                    staticDurationDisplay
                        .opacity(sessionTimerManager.activeSession == session ? 0 : 1)
                }
                .animation(.default, value: sessionTimerManager.activeSession == session)
            }
            
            PlaysSectionViewCD(session: session, showingAddPlaySheet: $showingAddPlaySheet, playToEdit: $playToEdit, context: viewContext)
            NotesSectionViewCD(session: session, editingNote: $editingNote, showingAddNoteSheet: $showingAddNoteSheet)
            
            Section("Recordings") {
                ForEach(session.recordingsArray) { recording in
                    AudioPlaybackCellCD(
                        title: recording.title ?? "Recording",
                        subtitle: (recording.dateRecorded ?? .now).formatted(date: .abbreviated, time: .shortened),
                        data: recording.data,
                        duration: recording.duration,
                        id: recording.objectID,
                        audioPlayerManager: audioPlayerManager
                    )
                }
                .onDelete(perform: deleteRecordings)
            }
        }
    }
    
    private var staticDurationDisplay: some View {
        HStack {
            Label(durationString, systemImage: "clock")
            
            Spacer()
            
            if sessionTimerManager.activeSession == nil {
                Button {
                    sessionTimerManager.start(session: session)
                } label: {
                    Label("Start Timer", systemImage: "play.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var activeTimerControls: some View {
        HStack(spacing: 12) {
            Label(sessionTimerManager.elapsedTimeString, systemImage: "timer")
                .font(.body.monospacedDigit())
                .foregroundColor(.primary)

            Spacer()

            Button {
                if sessionTimerManager.isPaused {
                    sessionTimerManager.resume()
                } else {
                    sessionTimerManager.pause()
                }
            } label: {
                Image(systemName: sessionTimerManager.isPaused ? "play.fill" : "pause.fill")
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .background(accentColor.color.opacity(0.2))
                    .foregroundColor(accentColor.color)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Button {
                sessionTimerManager.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = session.recordingsArray[index]
            viewContext.delete(recording)
        }
        try? viewContext.save()
    }
    
    private func saveRecording(title: String, songs: Set<SongCD>) {
        guard let url = audioRecorderManager.finishedRecordingURL else { return }
        do {
            let audioData = try Data(contentsOf: url)
            var duration: TimeInterval?
            if let player = try? AVAudioPlayer(data: audioData) {
                duration = player.duration
            }
            
            let recording = AudioRecordingCD(context: viewContext)
            recording.data = audioData
            recording.dateRecorded = .now
            recording.title = title.isEmpty ? "Recording" : title
            recording.duration = duration ?? 0.0
            recording.session = session
            recording.addToSongs(songs as NSSet)
            recording.student = session.student
            
            try viewContext.save()
            
        } catch {
            print("Error saving recorded file data: \(error)")
        }
        clearRecordingMetadataFields()
    }
    
    private func clearRecordingMetadataFields() {
        audioRecorderManager.finishedRecordingURL = nil
        newRecordingTitle = ""
        selectedSongsForRecording = []
    }
}
