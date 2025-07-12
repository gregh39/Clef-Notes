//
//  SessionDetailView.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/11/25.
//

import SwiftUI
import SwiftData
import AVFoundation
import PhotosUI

struct SessionDetailView: View {
    @Bindable var session: PracticeSession
    @State private var showingAddPlaySheet = false
    @State private var showingAddNoteSheet = false
    @State private var editingNote: Note?
    @Environment(\.modelContext) private var context
    @Query(sort: \Song.title) private var songs: [Song]

    // New state properties for AddSongSheet
    @State private var showingAddSongSheet = false
    @State private var newTitle = ""
    @State private var newGoalPlays = ""
    @State private var newCurrentPlays = ""
    @State private var newYouTubeLink = ""
    @State private var newAppleMusicLink = ""
    @State private var newSpotifyLink = ""
    @State private var newLocalFileLink = ""
    @State private var newSongStatus: PlayType? = nil
    @State private var newPieceType: PieceType? = nil
    
    @State private var showingEditSessionSheet = false

    @State private var isTunerOn = false
    @State private var isMetronomeOn = false

    // Audio recording state
    @State private var audioRecorder: AVAudioRecorder?
    @State private var isRecording = false
    
    // --- NEW: State for waveform ---
    @State private var recordingTimer: Timer?
    @State private var audioLevel: CGFloat = 0.0
    // --- END NEW ---

    // Use AudioManager to handle audio playback
    @State private var audioPlayerManager = AudioPlayerManager()

    // New state variables for recording metadata sheet
    @State private var showingRecordingMetadataSheet = false
    @State private var pendingRecordingURL: URL? = nil
    @State private var newRecordingTitle = ""
    @State private var selectedSongs: Set<PersistentIdentifier> = []

    @State private var newPlayType: PlayType? = nil
    
    @State private var playToEdit: Play? = nil

    @State private var studentSongsViewModel: StudentDetailViewModel
    @State private var selectedSort: SongSortOption = .title
    
    // New @State property for random song picker
    @State private var showingRandomSongPicker = false
    
    init(session: PracticeSession) {
        self._session = Bindable(wrappedValue: session)
        if let student = session.student, let context = session.modelContext {
            _studentSongsViewModel = State(initialValue: StudentDetailViewModel(student: student, context: context))
        } else {
            // Fallback for preview or missing context
            let dummyContext = { () -> ModelContext in
                if let container = try? ModelContainer(for: Student.self) {
                    return ModelContext(container)
                } else {
                    fatalError("Failed to initialize ModelContext")
                }
            }()
            let dummyStudent = Student(name: "Unknown", instrument: "")
            _studentSongsViewModel = State(initialValue: StudentDetailViewModel(student: dummyStudent, context: dummyContext))
        }
    }
    
    private var noteTextBinding: Binding<String> {
        Binding(
            get: { editingNote?.text ?? "" },
            set: { editingNote?.text = $0 }
        )
    }
    
    private var formattedSessionDay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: session.day)
    }
    
    // --- MODIFIED FUNCTION ---
    private func startOrStopRecording() {
        if isRecording {
            // --- Stop recording ---
            audioRecorder?.stop()
            recordingTimer?.invalidate() // Stop the timer
            
            if let url = audioRecorder?.url {
                pendingRecordingURL = url
                showingRecordingMetadataSheet = true
            }
            isRecording = false
            withAnimation { audioLevel = 0.0 } // Animate waveform collapse
            
        } else {
            // --- Start recording ---
            let filename = UUID().uuidString + ".m4a"
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Failed to get the documents directory.")
                return
            }
            let url = documentsPath.appendingPathComponent(filename)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                
                audioRecorder = try AVAudioRecorder(url: url, settings: settings)
                audioRecorder?.isMeteringEnabled = true // **IMPORTANT: Enable metering**
                
                try audioSession.setActive(true)
                audioRecorder?.record()
                isRecording = true
                
                // --- NEW: Start the timer to update the waveform ---
                recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    audioRecorder?.updateMeters()
                    // Get power in dB, convert to a 0-1 scale
                    let power = audioRecorder?.averagePower(forChannel: 0) ?? -160.0
                    let normalizedPower = CGFloat((160.0 + power) / 160.0)
                    withAnimation(.linear(duration: 0.1)) {
                        self.audioLevel = normalizedPower
                    }
                }
                // --- END NEW ---
                
            } catch {
                print("Failed to start recording: \(error)")
            }
        }
    }
    // --- END MODIFIED FUNCTION ---
    
    // Clear recording metadata fields
    private func clearRecordingMetadataFields() {
        pendingRecordingURL = nil
        newRecordingTitle = ""
        selectedSongs = []
    }
    
    private var newGoalPlaysIntBinding: Binding<Int> {
        Binding<Int>(
            get: { Int(newGoalPlays) ?? 0 },
            set: { newGoalPlays = String($0) }
        )
    }
    
    private var newCurrentPlaysIntBinding: Binding<Int> {
        Binding<Int>(
            get: { Int(newCurrentPlays) ?? 0 },
            set: { newCurrentPlays = String($0) }
        )
    }
    
    func progress(for song: Song) -> Double {
        let total = Double(song.totalPlayCount)
        guard let goalPlays = song.goalPlays, goalPlays > 0 else { return 0.0 }
        let goal = Double(goalPlays)
        return min(total / goal, 1.0)
    }
    
    private func addSongSheet() -> some View {
        AddSongSheet(
            isPresented: $showingAddSongSheet,
            title: $newTitle,
            goalPlays: $newGoalPlays,
            currentPlays: $newCurrentPlays,
            youtubeLink: $newYouTubeLink,
            appleMusicLink: $newAppleMusicLink,
            spotifyLink: $newSpotifyLink,
            localFileLink: $newLocalFileLink,
            songStatus: $newSongStatus,
            pieceType: $newPieceType,
            addAction: {
                let goal = Int(newGoalPlays)
                let song = Song(title: newTitle, studentID: session.studentID)
                song.pieceType = newPieceType
                song.student = session.student
                song.songStatus = newSongStatus

                let play = Play(count: 1)
                play.song = song
                play.session = session
                play.playType = newPlayType

                // Safely add play to song
                if song.plays == nil {
                    song.plays = [play]
                } else {
                    song.plays!.append(play)
                }

                // Safely add play to session
                if session.plays == nil {
                    session.plays = [play]
                } else {
                    session.plays?.append(play)
                }

                context.insert(play)
                
                if let url = URL(string: newYouTubeLink), !newYouTubeLink.isEmpty {
                    let media = MediaReference(type: .youtubeVideo, url: url)
                    media.song = song
                    if song.media == nil {
                        song.media = []
                    }
                    song.media?.append(media)
                }
                if let url = URL(string: newAppleMusicLink), !newAppleMusicLink.isEmpty {
                    let media = MediaReference(type: .appleMusicLink, url: url)
                    media.song = song
                    if song.media == nil {
                        song.media = []
                    }
                    song.media?.append(media)
                }
                if let url = URL(string: newSpotifyLink), !newSpotifyLink.isEmpty {
                    let media = MediaReference(type: .spotifyLink, url: url)
                    media.song = song
                    if song.media == nil {
                        song.media = []
                    }
                    song.media?.append(media)
                }
                if let url = URL(string: newLocalFileLink), !newLocalFileLink.isEmpty {
                    let media = MediaReference(type: .audioRecording, url: url)
                    media.song = song
                    if song.media == nil {
                        song.media = []
                    }
                    song.media?.append(media)
                }

                context.insert(song)
                try? context.save()
                newPlayType = nil
            },
            clearAction: {
                newTitle = ""
                newGoalPlays = ""
                newCurrentPlays = ""
                newYouTubeLink = ""
                newAppleMusicLink = ""
                newSpotifyLink = ""
                newLocalFileLink = ""
                newPlayType = nil
                newSongStatus = nil
                newPieceType = nil
            }
        )
    }
    
    private func recordingMetadataSheetView() -> some View {
        Group {
            if let url = pendingRecordingURL {
                RecordingMetadataSheet(
                    fileURL: url,
                    songs: songs,
                    newRecordingTitle: $newRecordingTitle,
                    selectedSongIDs: $selectedSongs,
                    onSave: { title, songIDs in
                        var duration: TimeInterval? = nil
                        if let audioPlayer = try? AVAudioPlayer(contentsOf: url) {
                            duration = audioPlayer.duration
                        }
                        let selectedSongs: [Song] = songs.filter { songIDs.contains($0.persistentModelID) }
                        let recording = AudioRecording(fileURL: url, duration: duration)
                        recording.title = title.isEmpty ? url.lastPathComponent : title
                        recording.session = session
                        recording.dateRecorded = Date()
                        recording.songs = selectedSongs
                        // Safely ensure session.recordings is not nil
                        if session.recordings == nil {
                            session.recordings = []
                        }
                        session.recordings?.append(recording)
                        context.insert(recording)
                        try? context.save()
                        clearRecordingMetadataFields()
                        showingRecordingMetadataSheet = false
                    },
                    onCancel: {
                        clearRecordingMetadataFields()
                        showingRecordingMetadataSheet = false
                    }
                )
            }
        }
    }

    var body: some View {
        
            TabView {
                // MARK: - Session Tab
                sessionTab
                    .tabItem {
                        Label("Session", systemImage: "calendar")
                    }
                
                // MARK: - Songs Tab
                StudentSongsTabView(viewModel: $studentSongsViewModel, selectedSort: $selectedSort)
                    .tabItem {
                        Label("Songs", systemImage: "music.note.list")
                    }
                
                // MARK: - Metronome Tab
                metronomeTab
                    .tabItem {
                        Label("Metronome", systemImage: "metronome")
                    }
                
                // MARK: - Tuner Tab
                tunerTab
                    .tabItem {
                        Label("Tuner", systemImage: "tuningfork")
                    }
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
                    Button {
                        showingEditSessionSheet = true
                    } label: {
                        Label("Edit", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingAddPlaySheet) {
                AddPlaySheetView(
                    showingAddPlaySheet: $showingAddPlaySheet,
                    showingAddSongSheet: $showingAddSongSheet,
                    session: session
                )
            }
            .sheet(isPresented: $showingAddSongSheet) {
                addSongSheet()
            }
            .sheet(item: $editingNote) { note in
                AddNoteSheet(note: note)
            }
            .sheet(isPresented: $showingRecordingMetadataSheet, onDismiss: { clearRecordingMetadataFields() }) {
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
            .overlay(
                GeometryReader { geometry in
                    ZStack {
                        if isRecording {
                            // Wide recording button expanded
                            Button(action: startOrStopRecording) {
                                HStack(spacing: 12) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    Text("Stop Recording")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    LiveWaveformView(level: audioLevel)
                                        .frame(height: 35)
                                }
                                .padding(.horizontal, 20)
                                .frame(width: geometry.size.width * 0.9, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 30)
                                        .fill(
                                            LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                )
                                .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
                                .animation(.easeInOut(duration: 0.3), value: isRecording)
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            // Circular record button idle
                            Button(action: startOrStopRecording) {
                                Image(systemName: "waveform.badge.microphone")
                                    .font(.system(size: 36))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(Color(.systemBackground))
                                            .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                                    )
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.bottom, 60)
                    .padding(.trailing, 20)
                }
            )
        
    }
    
    // MARK: - Extracted Tab Views
    
    private var sessionTab: some View {
        Form {
            
            PlaysSectionView(session: session, showingAddPlaySheet: $showingAddPlaySheet, showingAddSongSheet: $showingAddSongSheet, playToEdit: $playToEdit)
            NotesSectionView(session: session, editingNote: $editingNote, showingAddNoteSheet: $showingAddNoteSheet)
            
            // Recordings Section
                Section {
                    ForEach(session.recordings ?? [], id: \.persistentModelID) { recording in
                        AudioRecordingCell(
                            recording: recording,
                            audioPlayerManager: audioPlayerManager,
                            onDelete: {
                                if var recordings = session.recordings,
                                   let idx = recordings.firstIndex(where: { $0.persistentModelID == recording.persistentModelID }) {
                                    let removed = recordings.remove(at: idx)
                                    session.recordings = recordings
                                    context.delete(removed)
                                    try? context.save()
                                }
                            }
                        )
                    }
                } header: {
                    Label("Recordings", systemImage: "waveform.badge.mic")
                }
            
        }
    }
    
    private var metronomeTab: some View {
        VStack(spacing: 20) {
            
            MetronomeSectionView()
                .padding()
            
            Spacer()
        }
    }
    
    private var tunerTab: some View {
        VStack {
            
            TunerTabView()
                .padding()
            
        }
    }
}


// MARK: - Enhanced Live Waveform Display
struct LiveWaveformView: View {
    var level: CGFloat // Normalized level from 0.0 to 1.0
    var lineColor: Color = .white
    let baseThickness: CGFloat = 4
    let maxThickness: CGFloat = 24
    
    var body: some View {
        GeometryReader { geo in
            let thickness = baseThickness + (maxThickness - baseThickness) * level
            Capsule()
                .fill(lineColor)
                .frame(height: thickness)
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.1), value: thickness)
                .accessibilityLabel("Waveform level line")
        }
        .frame(height: maxThickness)
        .padding(.horizontal, 8)
    }
}

#Preview {
    // Minimal mock session
    let mockSession = PracticeSession(day: Date(), durationMinutes: 45, studentID: UUID())
    return NavigationStack {
        SessionDetailView(session: mockSession)
    }
}
