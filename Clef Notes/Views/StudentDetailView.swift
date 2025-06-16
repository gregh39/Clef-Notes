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

        NavigationStack {
            TabView {
                List {
                    Section("Sessions") {
                        ForEach(viewModel.sessions, id: \.persistentModelID) { session in
                            NavigationLink(destination: SessionDetailView(session: session)) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(session.title ?? "Practice")
                                            .font(.headline)
                                        if let location = session.location {
                                            Text(location.rawValue)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        if let instructor = session.instructor {
                                            Text("Instructor: \(instructor.name)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(session.day.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contextMenu {
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let session = viewModel.sessions[index]
                                viewModel.context.delete(session)
                            }
                            try? viewModel.context.save()
                            viewModel.practiceVM.reload()
                        }
                    }
                }
                .tabItem {
                    Label("Sessions", systemImage: "calendar")
                }

                List {
                    Section("Songs") {
                        Picker("Sort by", selection: $selectedSort) {
                            ForEach(SongSortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        ForEach(sortedSongs, id: \.persistentModelID) { song in
                            NavigationLink(destination: SongDetailView(song: song)) {
                                VStack(alignment: .leading) {
                                    Text(song.title)
                                    HStack {
                                        Spacer()
                                        if let gP = song.goalPlays {
                                            Text("\(song.totalPlayCount)/\(gP)")
                                                .font(.subheadline)
                                                .monospacedDigit()
                                        }
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
                StatsTabView(sessions: viewModel.sessions)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
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
            .navigationDestination(item: $newSession) { session in
                SessionDetailView(session: session)
            }
        }
    }
}
