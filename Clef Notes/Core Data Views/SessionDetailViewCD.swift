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
    @EnvironmentObject var sessionTimerManager: SessionTimerManager
    @EnvironmentObject var practiceSessionManager: PracticeSessionManager
    @EnvironmentObject var settingsManager: SettingsManager

    @State private var showingAddPlaySheet = false
    @State private var showingAddSongSheet = false
    @State private var showingEditSessionSheet = false
    @State private var showingRandomSongPicker = false
    @State private var showingAddNoteSheet = false

    @State private var editingNote: NoteCD?
    @State private var playToEdit: PlayCD?

    // Expanded audio cell tracking
    @State private var expandedAudioCellID: NSManagedObjectID? = nil

    @StateObject private var audioPlayerManager: AudioPlayerManager

    init(session: PracticeSessionCD, audioManager: AudioManager) {
        self.session = session
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
        // The metronome, tuner, and recorder live in the practice bar (PracticeBarView), which
        // stays available on every tab, so this screen is just the session itself.
        sessionForm
            .navigationTitle(session.title ?? "Practice Session")
            .navigationBarTitleDisplayMode(.large)
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
                if #available(iOS 18.0, *) {
                    AddPlaySheetViewCD(session: session, showingAddPlaySheet: $showingAddPlaySheet, showingAddSongSheet: $showingAddSongSheet)
                        .presentationSizing(.page)
                } else {
                    AddPlaySheetViewCD(session: session, showingAddPlaySheet: $showingAddPlaySheet, showingAddSongSheet: $showingAddSongSheet)
                }
            }
            .sheet(isPresented: $showingAddSongSheet) {
                if let student = session.student {
                    if #available(iOS 18.0, *) {
                        AddSongSheetCD(student: student)
                            .presentationSizing(.page)
                    } else {
                        AddSongSheetCD(student: student)
                    }
                }
            }
            .sheet(item: $editingNote) { note in
                if #available(iOS 18.0, *) {
                    AddNoteSheetCD(note: note)
                        .presentationSizing(.page)
                } else {
                    AddNoteSheetCD(note: note)
                }
            }
            .sheet(item: $playToEdit) { play in
                PlayEditSheetCD(play: play)
            }
            .sheet(isPresented: $showingEditSessionSheet) {
                EditSessionSheetCD(session: session)
            }
            .sheet(isPresented: $showingRandomSongPicker) {
                if let songs = session.student?.songsArray {
                    if #available(iOS 18.0, *) {
                        RandomSongPickerViewCD(songs: songs)
                            .presentationSizing(.page)
                    } else {
                        RandomSongPickerViewCD(songs: songs)
                    }
                }
            }
            .onAppear {
                // Opening a session attaches the practice bar to it, timed or not.
                practiceSessionManager.open(session)
            }
            .onDisappear {
                practiceSessionManager.sessionScreenDidDisappear(session)
            }
            .safeAreaInset(edge: .bottom) {
                // On iOS 26.1+ the bar is the tab view's bottom accessory instead.
                if #unavailable(iOS 26.1) {
                    PracticeBarView(session: session)
                        .floatingPracticeBarStyle()
                }
            }
    }

    private var sessionForm: some View {
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
                        audioPlayerManager: audioPlayerManager,
                        expandedCellID: $expandedAudioCellID
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
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Label(SessionTimerManager.format(sessionTimerManager.elapsed(at: context.date)), systemImage: "timer")
                    .font(.body.monospacedDigit())
                    .foregroundColor(.primary)
            }

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
                    .background(settingsManager.activeAccentColor.opacity(0.2))
                    .foregroundColor(settingsManager.activeAccentColor)
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
}
