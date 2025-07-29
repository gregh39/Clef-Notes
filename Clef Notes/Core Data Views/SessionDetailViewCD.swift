// Clef Notes/Core Data Views/SessionDetailViewCD.swift

import SwiftUI
import CoreData
import AVFoundation

// Add this extension to make URL identifiable for the .sheet(item:) modifier
extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

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
    
    // State to drive the metadata sheet presentation
    @State private var recordingURLForSheet: URL?

    @State private var editingNote: NoteCD?
    @State private var playToEdit: PlayCD?

    @StateObject private var audioRecorderManager: AudioRecorderManager
    @StateObject private var audioPlayerManager: AudioPlayerManager
    
    @State private var newRecordingTitle = ""
    @State private var selectedSongsForRecording: Set<SongCD> = []
    
    @State private var selectedTab: Int = 0
    @State private var selectedSection: SessionDetailSection = .session

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
        ZStack(alignment: .bottom) {
            VStack {
                switch selectedSection {
                case .session:
                    sessionTab
                case .metronome:
                    MetronomeSectionView()
                case .tuner:
                    TunerTabView()
                }
            }
            .navigationTitle(session.title ?? "Practice Session")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
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
            .sheet(item: $recordingURLForSheet, onDismiss: {
                audioRecorderManager.reset()
                clearRecordingMetadataFields()
            }) { url in
                if let songs = session.student?.songsArray {
                    RecordingMetadataSheetCD(
                        fileURL: url,
                        songs: songs,
                        newRecordingTitle: $newRecordingTitle,
                        selectedSongs: $selectedSongsForRecording,
                        onSave: { newTitle, newSongs in
                            saveRecording(url: url, title: newTitle, songs: newSongs)
                        }
                    )
                }
            }
            .onChange(of: audioRecorderManager.finishedRecordingURL) {
                if let newURL = audioRecorderManager.finishedRecordingURL {
                    DispatchQueue.main.async {
                        recordingURLForSheet = newURL
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    TimerBarView()
                    SessionBottomNavBar(selectedSection: $selectedSection)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            
            FloatingRecordButton(audioRecorderManager: audioRecorderManager)
                .padding(.bottom, 85)
                .padding(.horizontal)
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
    
    // Clef Notes/Core Data Views/SessionDetailViewCD.swift
    private func saveRecording(url: URL, title: String, songs: Set<SongCD>) {
        do {
            let audioData = try Data(contentsOf: url)
            var duration: TimeInterval?
            if let player = try? AVAudioPlayer(data: audioData) {
                duration = player.duration
            }
            
            let recording = AudioRecordingCD(context: viewContext)
            recording.id = UUID() // <<< --- ADD THIS LINE ---
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
    }

    private func clearRecordingMetadataFields() {
        newRecordingTitle = ""
        selectedSongsForRecording = []
    }
}

struct WaveformView: View {
    var audioLevel: CGFloat
    private let barCount: Int = 30

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { _ in
                let heightMultiplier = audioLevel
                let barHeight = max(3, heightMultiplier * audioLevel * 40)

                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 3, height: barHeight)
            }
        }
        .foregroundColor(.white.opacity(0.8))
        .animation(.easeOut(duration: 0.05), value: audioLevel)
    }
}


struct FloatingRecordButton: View {
    @ObservedObject var audioRecorderManager: AudioRecorderManager

    var body: some View {
        GeometryReader { geo in
            HStack {
                if !audioRecorderManager.isRecording {
                    Spacer()
                }

                Button(action: {
                    if audioRecorderManager.isRecording {
                        audioRecorderManager.stopRecording()
                    } else {
                        audioRecorderManager.startRecording()
                    }
                }) {
                    ZStack {
                        // Using RoundedRectangle and animating the corner radius
                        // ensures it's a perfect circle when collapsed.
                        RoundedRectangle(cornerRadius: audioRecorderManager.isRecording ? 40 : 40)
                            .fill(audioRecorderManager.isRecording ? Color.red : Color.white)
                            .shadow(radius: 7)

                        if audioRecorderManager.isRecording {
                            HStack(spacing: 12) {
                                Image(systemName: "stop.fill")
                                WaveformView(audioLevel: audioRecorderManager.audioLevel)
                                    .frame(height: 40)
                                Text("Stop")
                                    .bold()
                            }
                            .padding(.horizontal)
                            .foregroundColor(.white)
                            .opacity(audioRecorderManager.isRecording ? 1 : 0)
                            .animation(.easeIn.delay(0.15), value: audioRecorderManager.isRecording)
                        }
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 30))
                            .foregroundColor(.red)
                            .opacity(audioRecorderManager.isRecording ? 0 : 1)
                            .animation(.easeOut(duration: 0.15), value: audioRecorderManager.isRecording)
                    }
                    .frame(
                        width: audioRecorderManager.isRecording ? geo.size.width : 40,
                        height: 40
                    )
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: audioRecorderManager.isRecording)
            }
        }
        .frame(height: 40)
    }
}
enum SessionDetailSection: String, CaseIterable, Identifiable {
    case session = "Session"
    case metronome = "Metronome"
    case tuner = "Tuner"

    var id: String { self.rawValue }

    var systemImageName: String {
        switch self {
        case .session: "calendar"
        case .metronome: "metronome"
        case .tuner: "tuningfork"
        }
    }
}

struct SessionBottomNavBar: View {
    @Binding var selectedSection: SessionDetailSection
    
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
            HStack {
                ForEach(SessionDetailSection.allCases) { section in
                        Button(action: {
                            selectedSection = section
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: section.systemImageName)
                                    .font(.system(size: 22))
                                Text(section.rawValue)
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(selectedSection == section ? .accentColor : .gray)
                            .frame(maxWidth: .infinity)
                        }
                }
            }
            .padding(.top, 5)
            .padding(.bottom, 35)
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
        }
}
