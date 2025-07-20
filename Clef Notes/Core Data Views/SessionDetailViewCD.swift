import SwiftUI
import CoreData
import AVFoundation

struct SessionDetailViewCD: View {
    @ObservedObject var session: PracticeSessionCD
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager

    // State for controlling sheets
    @State private var showingAddPlaySheet = false
    @State private var showingAddSongSheet = false
    @State private var showingEditSessionSheet = false
    @State private var showingRandomSongPicker = false
    @State private var showingAddNoteSheet = false
    @State private var showingRecordingMetadataSheet = false

    // State for editing specific items
    @State private var editingNote: NoteCD?
    @State private var playToEdit: PlayCD?

    // State for audio recording
    @StateObject private var audioRecorderManager: AudioRecorderManager
    @StateObject private var audioPlayerManager: AudioPlayerManager
    @State private var audioSamples: [CGFloat] = []
    
    // State for the "Recording Metadata" sheet
    @State private var newRecordingTitle = ""
    @State private var selectedSongsForRecording: Set<SongCD> = []

    init(session: PracticeSessionCD, audioManager: AudioManager) {
        self.session = session
        _audioRecorderManager = StateObject(wrappedValue: AudioRecorderManager(audioManager: audioManager))
        _audioPlayerManager = StateObject(wrappedValue: AudioPlayerManager(audioManager: audioManager))
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

    private var sessionTab: some View {
        Form {
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
    
    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = session.recordingsArray[index]
            viewContext.delete(recording)
        }
        try? viewContext.save()
    }
    
    // --- THIS IS THE FIX ---
    // gregh39/clef-notes/Clef-Notes-CoreData/Clef Notes/Core Data Views/SessionDetailViewCD.swift
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
