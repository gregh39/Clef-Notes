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
    @EnvironmentObject var usageManager: UsageManager
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
    
    @State private var showingPaywallView = false

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
                case .session, .record:
                    sessionTab
                        .navigationTitle(session.title ?? "Practice Session")
                case .metronome:
                    MetronomeSectionView()
                        .navigationTitle("Metronome")

                case .tuner:
                    TunerTabView()
                        .navigationTitle("Tuner")

                }
            }
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
                    .presentationSizing(.page)
            }
            .sheet(isPresented: $showingAddSongSheet) {
                if let student = session.student {
                    AddSongSheetCD(student: student)
                        .presentationSizing(.page)
                }
            }
            .sheet(item: $editingNote) { note in
                AddNoteSheetCD(note: note)
                    .presentationSizing(.page)
            }
            .sheet(item: $playToEdit) { play in
                PlayEditSheetCD(play: play)
            }
            .sheet(isPresented: $showingEditSessionSheet) {
                EditSessionSheetCD(session: session)
            }
            .sheet(isPresented: $showingPaywallView) {
                PaywallView()
            }
            .sheet(isPresented: $showingRandomSongPicker) {
                if let songs = session.student?.songsArray {
                    RandomSongPickerViewCD(songs: songs)
                        .presentationSizing(.page)
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
            .onChange(of: audioRecorderManager.finishedRecordingURL) { oldValue, newValue in
                if let newURL = newValue {
                    DispatchQueue.main.async {
                        recordingURLForSheet = newURL
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                ZStack {
                    SessionBottomNavBar(selectedSection: $selectedSection, showingPaywallView: $showingPaywallView)
                        .environmentObject(audioRecorderManager)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            
            if audioRecorderManager.isRecording {
                RecordingStopBar(audioRecorderManager: audioRecorderManager)
                    .padding(.bottom, 60)
                    .padding(.horizontal)
                    .animation(.spring(), value: audioRecorderManager.isRecording)
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
    
    private func saveRecording(url: URL, title: String, songs: Set<SongCD>) {
        do {
            let audioData = try Data(contentsOf: url)
            var duration: TimeInterval?
            if let player = try? AVAudioPlayer(data: audioData) {
                duration = player.duration
            }
            
            let recording = AudioRecordingCD(context: viewContext)
            recording.id = UUID()
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

// --- START OF WAVEFORM CODE ---

private struct WaveformShape: Shape {
    var samples: [CGFloat]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !samples.isEmpty else { return path }

        let stepX = rect.width / CGFloat(samples.count > 1 ? samples.count - 1 : 1)
        let midY = rect.height / 2
        // Set a minimum thickness for the baseline
        let baseline: CGFloat = 1.0

        path.move(to: CGPoint(x: 0, y: midY))

        // Draw the top half
        for i in samples.indices {
            let x = CGFloat(i) * stepX
            let peak = (samples[i] * (midY - (baseline / 2))) + (baseline / 2)
            path.addLine(to: CGPoint(x: x, y: midY - peak))
        }

        // Draw the bottom half in reverse
        path.addLine(to: CGPoint(x: rect.width, y: midY))
        for i in (0..<samples.count).reversed() {
            let x = CGFloat(i) * stepX
            let peak = (samples[i] * (midY - (baseline / 2))) + (baseline / 2)
            path.addLine(to: CGPoint(x: x, y: midY + peak))
        }
        
        path.closeSubpath()
        return path
    }
}

struct WaveformView: View {
    var samples: [CGFloat]

    var body: some View {
        WaveformShape(samples: samples)
            .fill(Color.white.opacity(0.9))
            .animation(.easeOut(duration: 0.05), value: samples)
            .clipped()
    }
}

struct RecordingStopBar: View {
    @ObservedObject var audioRecorderManager: AudioRecorderManager

    var body: some View {
        HStack {
            Button(action: {
                if audioRecorderManager.isRecording {
                    audioRecorderManager.stopRecording()
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 35)
                        .fill(Color.red)
                        .shadow(radius: 7)

                    HStack(spacing: 12) {
                        Image(systemName: "stop.fill")
                        WaveformView(samples: audioRecorderManager.waveformSamples)
                            .frame(height: 35)
                    }
                    .padding(.horizontal)
                    .foregroundColor(.white)
                }
                .frame(height: 35)
            }
            .buttonStyle(.plain)
        }
    }
}
// --- END OF WAVEFORM CODE ---

enum SessionDetailSection: String, CaseIterable, Identifiable {
    case session = "Session"
    case metronome = "Metronome"
    case tuner = "Tuner"
    case record = "Record"

    var id: String { self.rawValue }

    var systemImageName: String {
        switch self {
        case .session: "calendar"
        case .metronome: "metronome"
        case .tuner: "tuningfork"
        case .record: "record.circle"
        }
    }
}

struct SessionBottomNavBar: View {
    @Binding var selectedSection: SessionDetailSection
    @EnvironmentObject var audioRecorderManager: AudioRecorderManager
    @EnvironmentObject var usageManager: UsageManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var showingPaywallView: Bool

    var body: some View {
            HStack {
                ForEach(SessionDetailSection.allCases) { section in
                        Button(action: {
                            if section == .record {
                                if !audioRecorderManager.isRecording{
                                    audioRecorderManager.startRecording()
                                } else {
                                    audioRecorderManager.stopRecording()
                                }
                            }
                            else if section == .metronome {
                                print("Metronome pressed")
                                if !subscriptionManager.isSubscribed && usageManager.metronomeOpens >= 10 {
                                    showingPaywallView = true
                                } else {
                                    selectedSection = section
                                }
                            }
                            else if section == .tuner {
                                if !subscriptionManager.isSubscribed && usageManager.tunerOpens >= 10 {
                                    showingPaywallView = true
                                } else {
                                    selectedSection = section
                                }
                            }
                            else {
                                selectedSection = section
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: section.systemImageName)
                                    .font(.system(size: 22))
                                Text(section.rawValue)
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(selectedSection == section ? .accentColor : (section == .record ? .red : .gray))
                            .frame(maxWidth: .infinity)
                        }
                        //.disabled((section == .metronome && !subscriptionManager.isSubscribed && (usageManager.metronomeOpens >= 10 || section == .tuner && usageManager.tunerOpens >= 10)))
                }
            }
            .padding(.top, 5)
            .padding(.bottom, 35)
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
            .onAppear{
                print("Subscription Status: \(subscriptionManager.isSubscribed)")
                print("Metronome Count: \(usageManager.metronomeOpens)")
                print("Tuner Count: \(usageManager.tunerOpens)")

            }
    }
}

