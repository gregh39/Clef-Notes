import SwiftUI
import SwiftData
import AVFoundation
import PhotosUI

struct SessionDetailView: View {
    @Bindable var session: PracticeSession
    @Environment(\.modelContext) private var context
    @Query(sort: \Song.title) private var songs: [Song]
    
    @EnvironmentObject var audioManager: AudioManager

    // MARK: - State & View Models
    
    @StateObject private var audioRecorderManager: AudioRecorderManager
    @StateObject private var audioPlayerManager: AudioPlayerManager

    // State for controlling sheets
    @State private var showingAddPlaySheet = false
    @State private var showingAddSongSheet = false
    @State private var showingEditSessionSheet = false
    @State private var showingRecordingMetadataSheet = false
    @State private var showingRandomSongPicker = false
    @State private var showingAddNoteSheet = false

    // State for editing specific items
    @State private var editingNote: Note?
    @State private var playToEdit: Play?

    // State for the "Add Song" sheet
    @State private var newTitle = ""
    @State private var newGoalPlays = ""
    @State private var newSongStatus: PlayType? = nil
    @State private var newPieceType: PieceType? = nil
    
    // State for the "Recording Metadata" sheet
    @State private var newRecordingTitle = ""
    @State private var selectedSongs: Set<PersistentIdentifier> = []
    
    @State private var studentSongsViewModel: StudentDetailViewModel
    @State private var selectedSort: SongSortOption = .title
    
    @State private var audioSamples: [CGFloat] = []

    // MARK: - Initializer
    
    init(session: PracticeSession, audioManager: AudioManager) {
        self._session = Bindable(wrappedValue: session)
        self._audioRecorderManager = StateObject(wrappedValue: AudioRecorderManager(audioManager: audioManager))
        self._audioPlayerManager = StateObject(wrappedValue: AudioPlayerManager(audioManager: audioManager))
        
        if let student = session.student, let context = session.modelContext {
            _studentSongsViewModel = State(initialValue: StudentDetailViewModel(student: student, context: context))
        } else {
            let dummyContext = { () -> ModelContext in
                let container = try! ModelContainer(for: Student.self)
                return ModelContext(container)
            }()
            let dummyStudent = Student(name: "Unknown", instrument: "")
            _studentSongsViewModel = State(initialValue: StudentDetailViewModel(student: dummyStudent, context: dummyContext))
        }
    }

    // MARK: - Body
    
    var body: some View {
        TabView {
            sessionTab
                .tabItem { Label("Session", systemImage: "calendar") }
            
            // --- THIS IS THE FIX ---
            // The required onAddSong closure is now provided.
            StudentSongsTabView(viewModel: $studentSongsViewModel, selectedSort: $selectedSort) {
                // This is the action for the "Add First Song" button.
                studentSongsViewModel.pieceType = .song
                showingAddSongSheet = true
            }
            .tabItem { Label("Songs", systemImage: "music.note.list") }
            
            metronomeTab
                .tabItem { Label("Metronome", systemImage: "metronome") }
            
            tunerTab
                .tabItem { Label("Tuner", systemImage: "tuningfork") }
        }
        .navigationTitle(session.title ?? "Practice Session")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingRandomSongPicker = true }) {
                    Image(systemName: "die.face.5")
                }
                .accessibilityLabel("Pick Random Song")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingEditSessionSheet = true } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingAddPlaySheet) {
            AddPlaySheetView(showingAddPlaySheet: $showingAddPlaySheet, showingAddSongSheet: $showingAddSongSheet, session: session)
        }
        .sheet(isPresented: $showingAddSongSheet) {
            addSongSheet()
        }
        .sheet(item: $editingNote) { note in
            AddNoteSheet(note: note)
        }
        .sheet(isPresented: $showingRecordingMetadataSheet, onDismiss: clearRecordingMetadataFields) {
            recordingMetadataSheetView()
        }
        .sheet(isPresented: $showingEditSessionSheet) {
            EditSessionSheet(isPresented: $showingEditSessionSheet, session: session, context: context)
        }
        .sheet(item: $playToEdit) { play in
            PlayEditSheet(play: play)
        }
        .sheet(isPresented: $showingRandomSongPicker) {
            RandomSongPickerView(songs: songs)
        }
        .overlay(recordingOverlay)
        .onChange(of: audioRecorderManager.finishedRecordingURL) { _, newURL in
            if newURL != nil {
                showingRecordingMetadataSheet = true
            }
        }
        .onChange(of: audioRecorderManager.audioLevel) { _, newLevel in
            if audioRecorderManager.isRecording {
                audioSamples.append(newLevel)
                if audioSamples.count > 100 {
                    audioSamples.removeFirst()
                }
            }
        }
        .onChange(of: audioRecorderManager.isRecording) { _, isRecording in
            if !isRecording {
                audioSamples.removeAll()
            }
        }
    }

    // MARK: - Extracted Tab Views

    private var sessionTab: some View {
        Form {
            PlaysSectionView(session: session, showingAddPlaySheet: $showingAddPlaySheet, showingAddSongSheet: $showingAddSongSheet, playToEdit: $playToEdit)
            NotesSectionView(session: session, editingNote: $editingNote, showingAddNoteSheet: $showingAddNoteSheet)
            
            Section {
                ForEach(session.recordings ?? []) { recording in
                    AudioRecordingCell(recording: recording, audioPlayerManager: audioPlayerManager, onDelete: {
                        deleteRecording(recording)
                    })
                }
                .onDelete(perform: deleteRecordings)
            } header: {
                Label("Recordings", systemImage: "waveform.badge.mic")
            }
        }
    }
    
    private var metronomeTab: some View { MetronomeSectionView() }
    private var tunerTab: some View { TunerTabView() }

    // MARK: - Recording UI

    @ViewBuilder
    private var recordingOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if audioRecorderManager.isRecording {
                    Button(action: { audioRecorderManager.stopRecording() }) {
                        HStack(spacing: 12) {
                            Image(systemName: "stop.circle.fill").font(.title2)
                            Text("Stop Recording").font(.headline)
                            LiveWaveformView(samples: audioSamples).frame(height: 35)
                        }
                        .padding(.horizontal, 20).frame(minWidth: 250, minHeight: 50)
                        .background(LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .top, endPoint: .bottom))
                        .foregroundColor(.white).clipShape(Capsule())
                        .shadow(color: .red.opacity(0.4), radius: 8, y: 4)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    Button(action: { audioRecorderManager.startRecording() }) {
                        Image(systemName: "waveform.badge.microphone").font(.system(size: 36))
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color(.systemBackground)))
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 8, y: 4)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }.padding(.bottom, 60).padding(.trailing, 20)
        .animation(.easeInOut, value: audioRecorderManager.isRecording)
    }

    // MARK: - Sheet Views

    private func addSongSheet() -> some View {
        AddSongSheet(
            isPresented: $showingAddSongSheet,
            title: $newTitle,
            goalPlays: $newGoalPlays,
            songStatus: $newSongStatus,
            pieceType: $newPieceType,
            addAction: { mediaEntries in
                // Create the new song and an initial play for this session
                let song = Song(title: newTitle, studentID: session.studentID)
                song.pieceType = newPieceType
                song.student = session.student
                song.songStatus = newSongStatus
                song.goalPlays = Int(newGoalPlays)
                
                let play = Play(count: 1)
                play.song = song
                play.session = session
                
                song.plays = [play]
                if session.plays == nil { session.plays = [] }
                session.plays?.append(play)
                
                context.insert(play)
                context.insert(song)

                // Asynchronously process and attach media files
                Task {
                    for entry in mediaEntries {
                        let mediaReference: MediaReference?
                        
                        switch entry.type {
                        case .localVideo:
                            if let item = entry.photoPickerItem, let data = try? await item.loadTransferable(type: Data.self) {
                                mediaReference = MediaReference(type: .localVideo, data: data)
                            } else {
                                mediaReference = nil
                            }
                        case .audioRecording:
                            if let url = entry.audioFileURL, url.startAccessingSecurityScopedResource(), let data = try? Data(contentsOf: url) {
                                url.stopAccessingSecurityScopedResource()
                                mediaReference = MediaReference(type: .audioRecording, data: data)
                            } else {
                                mediaReference = nil
                            }
                        default:
                            if let url = URL(string: entry.urlString) {
                                mediaReference = MediaReference(type: entry.type, url: url)
                            } else {
                                mediaReference = nil
                            }
                        }

                        if let newMedia = mediaReference {
                            newMedia.song = song
                            if song.media == nil {
                                song.media = []
                            }
                            song.media?.append(newMedia)
                        }
                    }
                    
                    try? context.save()
                }
            },
            clearAction: {
                newTitle = ""
                newGoalPlays = ""
                newSongStatus = nil
                newPieceType = nil
            }
        )
    }
    
    @ViewBuilder
    private func recordingMetadataSheetView() -> some View {
        if let sourceURL = audioRecorderManager.finishedRecordingURL {
            RecordingMetadataSheet(
                fileURL: sourceURL,
                songs: songs,
                newRecordingTitle: $newRecordingTitle,
                selectedSongIDs: $selectedSongs,
                onSave: { title, songIDs in
                    do {
                        let audioData = try Data(contentsOf: sourceURL)
                        
                        var duration: TimeInterval? = nil
                        if let audioPlayer = try? AVAudioPlayer(data: audioData) {
                            duration = audioPlayer.duration
                        }
                        
                        let selectedSongsObjects: [Song] = songs.filter { songIDs.contains($0.persistentModelID) }
                        
                        let recording = AudioRecording(data: audioData, dateRecorded: .now, title: title.isEmpty ? "Recording" : title, duration: duration)
                        recording.session = session
                        recording.songs = selectedSongsObjects
                        
                        context.insert(recording)
                        try? context.save()
                        
                        showingRecordingMetadataSheet = false
                        
                    } catch {
                        print("Error reading or saving recorded file data: \(error)")
                    }
                },
                onCancel: {
                    showingRecordingMetadataSheet = false
                }
            )
        } else {
            EmptyView()
        }
    }
    
    // MARK: - Helper Functions
    
    private func clearRecordingMetadataFields() {
        audioRecorderManager.finishedRecordingURL = nil
        newRecordingTitle = ""
        selectedSongs = []
    }
    
    private func deleteRecording(_ recording: AudioRecording) {
        context.delete(recording)
        try? context.save()
    }
    
    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            if let recording = session.recordings?[index] {
                deleteRecording(recording)
            }
        }
    }
}

// MARK: - Live Waveform Display
private struct LiveWaveformView: View {
    var samples: [CGFloat]
    var color: Color = .white
    var lineWidth: CGFloat = 1.5

    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else { return }

            let middleY = size.height / 2
            let stepX = size.width / CGFloat(samples.count - 1)

            var topPath = Path()
            var bottomPath = Path()

            for i in 0..<samples.count {
                let x = CGFloat(i) * stepX
                let magnitude = samples[i] * middleY

                if i == 0 {
                    topPath.move(to: CGPoint(x: x, y: middleY - magnitude))
                    bottomPath.move(to: CGPoint(x: x, y: middleY + magnitude))
                } else {
                    topPath.addLine(to: CGPoint(x: x, y: middleY - magnitude))
                    bottomPath.addLine(to: CGPoint(x: x, y: middleY + magnitude))
                }
            }
            
            context.stroke(topPath, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            context.stroke(bottomPath, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}
