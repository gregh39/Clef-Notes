//
//  StudentDetailView.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/10/25.
//
import SwiftUI
import SwiftData

struct StudentDetailView: View {
    @Environment(\.modelContext) private var context
    let student: Student

    @State private var viewModel: StudentPracticeViewModel?

    // State for add song sheet and form fields
    @State private var showingAddSongSheet = false
    @State private var newTitle = ""
    @State private var newGoalPlays = ""
    @State private var newCurrentPlays = ""
    @State private var newYouTubeLink = ""
    @State private var newAppleMusicLink = ""
    @State private var newSpotifyLink = ""
    @State private var newLocalFileLink = ""

    // State for navigating to new session detail
    @State private var newSession: PracticeSession?

    var body: some View {
        NavigationStack {
            TabView {
                List {
                    if let viewModel = viewModel {
                        Section("Sessions") {
                            ForEach(viewModel.sessions, id: \.persistentModelID) { session in
                                NavigationLink(destination: SessionDetailView(session: session)) {
                                    Text(session.day.formatted(date: .abbreviated, time: .omitted))
                                }
                            }
                        }
                    } else {
                        ProgressView("Loading...")
                    }
                }
                .tabItem {
                    Label("Sessions", systemImage: "calendar")
                }

                List {
                    if let viewModel = viewModel {
                        Section("Songs") {
                            ForEach(viewModel.songs, id: \.persistentModelID) { song in
                                NavigationLink(destination: SongDetailView(song: song)) {
                                    VStack(alignment: .leading) {
                                        Text(song.title)
                                        HStack {
                                            Spacer()
                                            Text("\(song.totalPlayCount)/\(song.goalPlays)")
                                                .font(.subheadline)
                                                .monospacedDigit()
                                            Spacer()
                                        }
                                        ProgressView(value: viewModel.progress(for: song))
                                    }
                                }
                            }
                        }
                    } else {
                        ProgressView("Loading...")
                    }
                }
                .tabItem {
                    Label("Songs", systemImage: "music.note.list")
                }
            }
            .navigationTitle(student.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSongSheet = true
                    } label: {
                        Label("Add Song", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let session = PracticeSession(day: .now, durationMinutes: 0, studentID: student.id)
                        session.student = student
                        context.insert(session)
                        try? context.save()
                        newSession = session
                        viewModel?.reload()

                    } label: {
                        Label("Add Session", systemImage: "calendar.badge.plus")
                    }
                }
            }
            .task {
                if viewModel == nil {
                    viewModel = StudentPracticeViewModel(student: student, context: context)
                } else {
                    viewModel?.reload()
                }
            }
            .sheet(isPresented: $showingAddSongSheet) {
                NavigationStack {
                    Form {
                        Section("Song Info") {
                            TextField("Title", text: $newTitle)
                            TextField("Goal Plays", text: $newGoalPlays)
                                .keyboardType(.numberPad)
                            TextField("Current Plays", text: $newCurrentPlays)
                                .keyboardType(.numberPad)
                        }

                        Section("Links") {
                            TextField("YouTube", text: $newYouTubeLink)
                            TextField("Apple Music", text: $newAppleMusicLink)
                            TextField("Spotify", text: $newSpotifyLink)
                            TextField("Local File", text: $newLocalFileLink)
                        }
                    }
                    .navigationTitle("New Song")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingAddSongSheet = false
                                clearSongForm()
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                addSong()
                                showingAddSongSheet = false
                                clearSongForm()
                            }
                            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }
            .navigationDestination(item: $newSession) { session in
                SessionDetailView(session: session)
            }
        }
    }

    private func clearSongForm() {
        newTitle = ""
        newGoalPlays = ""
        newCurrentPlays = ""
        newYouTubeLink = ""
        newAppleMusicLink = ""
        newSpotifyLink = ""
        newLocalFileLink = ""
    }

    private func addSong() {
        guard let goal = Int(newGoalPlays), let current = Int(newCurrentPlays) else { return }

        let song = Song(title: newTitle, goalPlays: goal, studentID: student.id)
        song.student = student

        if current > 0 {
            let play = Play(count: current)
            play.song = song
            song.plays.append(play)
        }

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
        viewModel?.reload()
    }
}
