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

    @State private var viewModel: StudentDetailViewModel

    // State for add song sheet and form fields
    @State private var showingAddSongSheet = false

    // State for navigating to new session detail
    @State private var newSession: PracticeSession?

    init(student: Student, context: ModelContext) {
        self.student = student
        self._viewModel = State(initialValue: StudentDetailViewModel(student: student, context: context))
    }

    var body: some View {
        NavigationStack {
            TabView {
                List {
                    Section("Sessions") {
                        ForEach(viewModel.sessions, id: \.persistentModelID) { session in
                            NavigationLink(destination: SessionDetailView(session: session)) {
                                Text(session.day.formatted(date: .abbreviated, time: .omitted))
                            }
                        }
                    }
                }
                .tabItem {
                    Label("Sessions", systemImage: "calendar")
                }

                List {
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
                                    ProgressView(value: viewModel.practiceVM.progress(for: song))
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let song = viewModel.songs[index]
                                viewModel.deleteSong(song)                            }
                            try? viewModel.context.save()
                            viewModel.practiceVM.reload()
                        }
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
                        newSession = viewModel.addSession()
                    } label: {
                        Label("Add Session", systemImage: "calendar.badge.plus")
                    }
                }
            }
            .task {
                viewModel.practiceVM.reload()
            }
            .sheet(isPresented: $showingAddSongSheet) {
                AddSongSheet(
                    isPresented: $showingAddSongSheet,
                    title: $viewModel.title,
                    goalPlays: $viewModel.goalPlays,
                    currentPlays: $viewModel.currentPlays,
                    youtubeLink: $viewModel.youtubeLink,
                    appleMusicLink: $viewModel.appleMusicLink,
                    spotifyLink: $viewModel.spotifyLink,
                    localFileLink: $viewModel.localFileLink,
                    addAction: viewModel.addSong,
                    clearAction: viewModel.clearSongForm
                )
            }
            .navigationDestination(item: $newSession) { session in
                SessionDetailView(session: session)
            }
        }
    }
}
