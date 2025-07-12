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

    // State for add song sheet
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
            // --- MODIFIED SECTION ---
            .sheet(isPresented: $showingAddSongSheet) {
                AddSongSheet(
                    isPresented: $showingAddSongSheet,
                    title: $viewModel.title,
                    goalPlays: $viewModel.goalPlays,
                    songStatus: $viewModel.songStatus,
                    pieceType: $viewModel.pieceType,
                    // The addAction now receives the array of media entries directly
                    addAction: { mediaEntries in
                        viewModel.addSong(mediaEntries: mediaEntries)
                    },
                    clearAction: viewModel.clearSongForm
                )
            }
            // --- END MODIFIED SECTION ---
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
