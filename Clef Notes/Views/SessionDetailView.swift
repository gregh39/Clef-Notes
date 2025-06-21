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
            addAction: {
                let goal = Int(newGoalPlays)
                let song = Song(title: newTitle, goalPlays: goal, studentID: session.studentID)
                song.student = session.student

                let play = Play(count: 1)
                play.song = song
                play.session = session
                song.plays.append(play)
                session.plays.append(play)
                context.insert(play)

                if let url = URL(string: newYouTubeLink), !newYouTubeLink.isEmpty {
                    let media = MediaReference(type: .youtubeVideo, url: url)
                    media.song = song
                    song.media.append(media)
                }
                if let url = URL(string: newAppleMusicLink), !newAppleMusicLink.isEmpty {
                    let media = MediaReference(type: .appleMusicLink, url: url)
                    media.song = song
                    song.media.append(media)
                }
                if let url = URL(string: newSpotifyLink), !newSpotifyLink.isEmpty {
                    let media = MediaReference(type: .spotifyLink, url: url)
                    media.song = song
                    song.media.append(media)
                }
                if let url = URL(string: newLocalFileLink), !newLocalFileLink.isEmpty {
                    let media = MediaReference(type: .audioRecording, url: url)
                    media.song = song
                    song.media.append(media)
                }

                context.insert(song)
                try? context.save()
            },
            clearAction: {
                newTitle = ""
                newGoalPlays = ""
                newCurrentPlays = ""
                newYouTubeLink = ""
                newAppleMusicLink = ""
                newSpotifyLink = ""
                newLocalFileLink = ""
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
                        let recording = AudioRecording(fileURL: url, duration: duration)
                        recording.title = title.isEmpty ? url.lastPathComponent : title
                        recording.session = session
                        recording.dateRecorded = Date()
                        for song in songs where songIDs.contains(song.persistentModelID) {
                            recording.songs.append(song)
                        }
                        session.recordings.append(recording)
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

    private func addPlaySheetView() -> some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingAddPlaySheet = false
                        showingAddSongSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add New Song")
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Create")
                }

                if !songs.isEmpty {
                    Section {
                        ForEach(songs, id: \.persistentModelID) { song in
                            Button(song.title) {
                                let play = Play(count: 1)
                                play.song = song
                                play.session = session
                                session.plays.append(play)
                                context.insert(play)
                                try? context.save()
                                showingAddPlaySheet = false
                            }
                        }
                    } header: {
                        Text("Existing Songs")
                    }
                }
            }
            .navigationTitle("Choose Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingAddPlaySheet = false
                    }
                }
            }
        }
    }

    var body: some View {
        
            TabView {
                // MARK: - Session Tab
                Form {
                    // Recording Section
                    Section {
                        VStack(spacing: 12) {
                            Button(action: startOrStopRecording) {
                                HStack {
                                    Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                                        .font(.title2)
                                        .foregroundColor(isRecording ? .red : .white)
                                    
                                    Text(isRecording ? "Stop Recording" : "Start Recording")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    if isRecording {
                                        VStack(spacing: 8) {
                                            LiveWaveformView(level: audioLevel)
                                                .transition(.opacity.combined(with: .scale))
                                        }
                                        .padding(.top, 4)
                                    }
                                    
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isRecording ?
                                              LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                                LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                             )
                                        .shadow(color: isRecording ? .red.opacity(0.3) : .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Label("Recording", systemImage: "mic")
                    }
                    
                    PlaysSectionView(session: session)
                    NotesSectionView(session: session, editingNote: $editingNote, showingAddNoteSheet: $showingAddNoteSheet)
                    
                    // Recordings Section
                    if !session.recordings.isEmpty {
                        Section {
                            ForEach(session.recordings, id: \.persistentModelID) { recording in
                                AudioRecordingCell(
                                    recording: recording,
                                    audioPlayerManager: audioPlayerManager,
                                    onDelete: {
                                        if let idx = session.recordings.firstIndex(where: { $0.persistentModelID == recording.persistentModelID }) {
                                            let removed = session.recordings.remove(at: idx)
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
                .tabItem {
                    Label("Session", systemImage: "calendar")
                }
                
                // MARK: - Songs Tab
                List {
                    Section {
                        ForEach(songs, id: \.persistentModelID) { song in
                            NavigationLink(destination: SongDetailView(song: song)) {
                                SongRowView(song: song, progress: progress(for: song))
                            }
                        }
                    } header: {
                        Label("Songs", systemImage: "music.note.list")
                    }
                }
                .tabItem {
                    Label("Songs", systemImage: "music.note.list")
                }
                
                // MARK: - Metronome Tab
                VStack(spacing: 20) {
                    
                    MetronomeSectionView()
                        .padding()
                    
                    Spacer()
                }
                .tabItem {
                    Label("Metronome", systemImage: "metronome")
                }
                
                // MARK: - Tuner Tab
                VStack {
                    
                    TunerTabView()
                        .padding()
                    
                }
                .tabItem {
                    Label("Tuner", systemImage: "tuningfork")
                }
            }
            .navigationTitle(session.title ?? "Practice Session")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingEditSessionSheet = true
                        } label: {
                            Label("Edit Session", systemImage: "square.and.pencil")
                        }
                        Button {
                            showingAddPlaySheet = true
                        } label: {
                            Label("Add Play", systemImage: "plus.circle.fill")
                        }
                        Button {
                            let note = Note(text: "")
                            note.session = session
                            session.notes.append(note)
                            context.insert(note)
                            editingNote = note
                        } label: {
                            Label("Add Note", systemImage: "note.text.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddPlaySheet) {
                addPlaySheetView()
            }
            .sheet(isPresented: $showingAddSongSheet) {
                addSongSheet()
            }
            .sheet(item: $editingNote) { note in
                AddNoteSheet(note: note, songs: songs)
            }
            .sheet(isPresented: $showingRecordingMetadataSheet, onDismiss: { clearRecordingMetadataFields() }) {
                recordingMetadataSheetView()
            }
            .sheet(isPresented: $showingEditSessionSheet) {
                EditSessionSheet(isPresented: $showingEditSessionSheet, session: session, context: context)
            }
        
    }
}

// MARK: - Enhanced Song Row View
struct SongRowView: View {
    let song: Song
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(song.totalPlayCount)/\(song.goalPlays ?? 0)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor(for: progress)))
                .scaleEffect(y: 1.5)
        }
        .padding(.vertical, 4)
    }
    
    private func progressColor(for progress: Double) -> Color {
        switch progress {
        case 0..<0.3:
            return .red
        case 0.3..<0.7:
            return .orange
        case 0.7..<1.0:
            return .yellow
        default:
            return .green
        }
    }
}

// MARK: - Enhanced Live Waveform Display
struct LiveWaveformView: View {
    var level: CGFloat // Normalized level from 0.0 to 1.0
    var barColor: Color = .red

    private let barCount = 12
    private let maxHeight: CGFloat = 35.0

    // Enhanced multipliers for a more dynamic waveform
    private let multipliers: [CGFloat] = [0.15, 0.3, 0.5, 0.7, 0.85, 1.0, 1.0, 0.85, 0.7, 0.5, 0.3, 0.15]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                let baseHeight: CGFloat = 3
                let dynamicHeight = max(baseHeight, level * maxHeight * multipliers[index])
                
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 4, height: dynamicHeight)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [barColor.opacity(0.8), barColor],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: barColor.opacity(0.3), radius: 2, x: 0, y: 1)
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
        .frame(height: maxHeight, alignment: .center)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary, lineWidth: 1)
                )
        )
    }
}

#Preview {
    // Minimal mock session
    let mockSession = PracticeSession(day: Date(), durationMinutes: 45, studentID: UUID())
    return NavigationStack {
        SessionDetailView(session: mockSession)
    }
}

