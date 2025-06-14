//
//  SessionDetailView.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/11/25.
//

import SwiftUI
import SwiftData
import AVFoundation
// Import AddSongSheet if it's in a separate file
// If AddSongSheet is in the same file, ignore this line.

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

    @State private var isTunerOn = false
    private let audioEngine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)

    @State private var isMetronomeOn = false
    @State private var tempo: Double = 60.0
    @State private var metronomeTimer: Timer?
    private let metronomeEngine = AVAudioEngine()
    private let metronomePlayer = AVAudioPlayerNode()
    private let metronomeFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)

    private var noteTextBinding: Binding<String> {
        Binding(
            get: { editingNote?.text ?? "" },
            set: { editingNote?.text = $0 }
        )
    }

    private var noteSongBinding: Binding<Song?> {
        Binding(
            get: { editingNote?.song },
            set: { editingNote?.song = $0 }
        )
    }

    private func playDrone() {
        let sampleRate = 44100.0
        let duration = 10.0 // seconds
        let frequency = 440.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat!, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        let thetaIncrement = 2.0 * Double.pi * frequency / sampleRate
        for frame in 0..<Int(frameCount) {
            let sample = sin(thetaIncrement * Double(frame))
            buffer.floatChannelData?.pointee[frame] = Float(sample)
        }

        audioEngine.attach(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: audioFormat)

        do {
            try audioEngine.start()
            player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            player.play()
        } catch {
            print("Audio Engine error: \(error)")
        }
    }

    private func stopDrone() {
        player.stop()
        audioEngine.stop()
    }

    private func startMetronome() {
        guard let format = metronomeFormat else { return }

        let sampleRate = format.sampleRate
        let duration = 0.05 // 50ms click
        let frequency = 660.0 // softer tone
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        let thetaIncrement = 2.0 * Double.pi * frequency / sampleRate
        let attackFrames = Int(Double(frameCount) * 0.1)
        let releaseFrames = Int(Double(frameCount) * 0.1)

        for frame in 0..<Int(frameCount) {
            var sample = sin(thetaIncrement * Double(frame))

            if frame < attackFrames {
                sample *= Double(frame) / Double(attackFrames)
            } else if frame > Int(frameCount) - releaseFrames {
                sample *= Double(Int(frameCount) - frame) / Double(releaseFrames)
            }

            buffer.floatChannelData?.pointee[frame] = Float(sample * 0.5)
        }

        metronomeEngine.attach(metronomePlayer)
        metronomeEngine.connect(metronomePlayer, to: metronomeEngine.mainMixerNode, format: format)

        do {
            try metronomeEngine.start()
        } catch {
            print("Metronome engine failed to start: \(error)")
            return
        }

        metronomeTimer?.invalidate()
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: 60.0 / tempo, repeats: true) { _ in
            self.metronomePlayer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            self.metronomePlayer.play()
        }
    }

    private func stopMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        metronomePlayer.stop()
        metronomeEngine.stop()
    }

    var body: some View {
        Form {
            Section("Session Info") {
                DatePicker("Date", selection: $session.day, displayedComponents: .date)
                Stepper(value: $session.durationMinutes, in: 0...240) {
                    Text("Duration: \(session.durationMinutes) minutes")
                }
            }

            PlaysSectionView(session: session)
            NotesSectionView(session: session, editingNote: $editingNote, showingAddNoteSheet: $showingAddNoteSheet)
            TunerSectionView(isTunerOn: $isTunerOn) { newValue in
                if newValue { playDrone() } else { stopDrone() }
            }
            MetronomeSectionView(isMetronomeOn: $isMetronomeOn, tempo: $tempo, toggleAction: { enabled in
                if enabled { startMetronome() } else { stopMetronome() }
            }, tempoChanged: {
                if isMetronomeOn {
                    stopMetronome()
                    startMetronome()
                }
            })
        }
        .navigationTitle("Session Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddPlaySheet = true
                } label: {
                    Label("Add Play", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    let note = Note(text: "")
                    note.session = session
                    session.notes.append(note)
                    context.insert(note)
                    editingNote = note
                } label: {
                    Label("Add Note", systemImage: "note.text.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPlaySheet) {
            NavigationStack {
                List {
                    Button("Add New Song") {
                        showingAddPlaySheet = false
                        showingAddSongSheet = true
                    }
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
                }
                .navigationTitle("Choose Song")
            }
        }
        .sheet(isPresented: $showingAddSongSheet) {
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
                    let current = Int(newCurrentPlays) ?? 0
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
        .sheet(item: $editingNote) { note in
            NavigationStack {
                Form {
                    Section("Note") {
                        TextField("Enter note text", text: Binding(
                            get: { note.text },
                            set: { note.text = $0 }
                        ), axis: .vertical)
                        .lineLimit(3...6)
                    }

                    Section("Tag a Song") {
                        Picker("Song", selection: Binding(
                            get: { note.song },
                            set: { note.song = $0 }
                        )) {
                            Text("None").tag(Optional<Song>.none)
                            ForEach(songs, id: \.persistentModelID) { song in
                                Text(song.title).tag(Optional(song))
                            }
                        }
                    }
                }
                .navigationTitle("Edit Note")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editingNote = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            try? context.save()
                            editingNote = nil
                        }
                        .disabled(note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
}

