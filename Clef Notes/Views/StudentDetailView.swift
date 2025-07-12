//
//  StudentDetailView.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/10/25.
//
import SwiftUI
import SwiftData

enum SongSortOption: String, CaseIterable, Identifiable {
    case title = "Title"
    case playCount = "Play Count"
    case recentlyPlayed = "Recently Played"

    var id: String { rawValue }
}


struct StudentDetailView: View {
    @Environment(\.modelContext) private var context
    let student: Student

    @State private var viewModel: StudentDetailViewModel

    // State for add song sheet and form fields
    @State private var showingAddSongSheet = false

    // State for navigating to new session detail
    @State private var newSession: PracticeSession?

    @State private var showingAddSessionSheet = false

    @State private var selectedSort: SongSortOption = .title

    init(student: Student, context: ModelContext) {
        self.student = student
        self._viewModel = State(initialValue: StudentDetailViewModel(student: student, context: context))
    }

    var body: some View {
        var sortedSongs: [Song] {
            switch selectedSort {
            case .title:
                return viewModel.songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .playCount:
                return viewModel.songs.sorted { $0.totalPlayCount > $1.totalPlayCount }
            case .recentlyPlayed:
                return viewModel.songs.sorted {
                    ($0.lastPlayedDate ?? .distantPast) > ($1.lastPlayedDate ?? .distantPast)
                }
            }
        }

        NavigationStack {
            TabView {
                SessionListView(viewModel: $viewModel)
                    .tabItem {
                        Label("Sessions", systemImage: "calendar")
                    }
                StudentSongsTabView(viewModel: $viewModel, selectedSort: $selectedSort)
                    .tabItem { Label("Songs", systemImage: "music.note.list") }

                StatsTabView(sessions: viewModel.sessions)
                    .tabItem { Label("Stats", systemImage: "chart.bar") }
            }
            .navigationTitle(student.name)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $newSession) { session in
                SessionDetailView(session: session)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.pieceType = .song
                        showingAddSongSheet = true
                    } label: {
                        Label {
                            Text("Add Song")
                        } icon: {
                            Image("add.song")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSessionSheet = true
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
                    songStatus: $viewModel.songStatus, // Now PlayType? binding
                    pieceType: $viewModel.pieceType, // <-- Added binding
                    addAction: {
                        let mediaSources: [(String, MediaType)] = [
                            (viewModel.youtubeLink, .youtubeVideo),
                            (viewModel.appleMusicLink, .appleMusicLink),
                            (viewModel.spotifyLink, .spotifyLink),
                            (viewModel.localFileLink, .audioRecording)
                        ]

                        viewModel.addSong(mediaSources: mediaSources)

                    },
                    clearAction: viewModel.clearSongForm
                )
            }
            .sheet(isPresented: $showingAddSessionSheet) {
                AddSessionSheet(
                    isPresented: $showingAddSessionSheet,
                    student: student,
                    context: context,
                    onAdd: { session in
                        viewModel.practiceVM.reload()
                        newSession = session
                    }
                )
            }
        }
    }
}

