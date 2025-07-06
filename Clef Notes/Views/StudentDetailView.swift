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

    @State private var showingAddSessionSheet = false

    enum SongSortOption: String, CaseIterable, Identifiable {
        case title = "Title"
        case playCount = "Play Count"
        case recentlyPlayed = "Recently Played"

        var id: String { rawValue }
    }

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

        
            TabView {
                NavigationStack {
                    SessionListView(viewModel: $viewModel)
                        .navigationDestination(item: $newSession) { session in
                            SessionDetailView(session: session)
                        }
                        .navigationTitle(student.name)
                        .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Sessions", systemImage: "calendar")
                }

                NavigationStack {
                    StudentSongsTabView(viewModel: $viewModel, selectedSort: $selectedSort)
                        .navigationTitle("Songs")
                        .navigationBarTitleDisplayMode(.large)
                }
                .tabItem { Label("Songs", systemImage: "music.note.list") }
                
                NavigationStack {
                    StatsTabView(sessions: viewModel.sessions)
                        .navigationTitle("Practice Stats")
                        .navigationBarTitleDisplayMode(.large)
                }
                .tabItem { Label("Stats", systemImage: "chart.bar") }
            }
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

