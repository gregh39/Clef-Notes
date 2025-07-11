import SwiftUI
import SwiftData

struct StudentSongsTabView: View {
    @Binding var viewModel: StudentDetailViewModel
    @Binding var selectedSort: SongSortOption
    
    @State private var showingRandomSongPicker = false
    @State private var selectedPieceType: PieceType? = nil
    @State private var editingSong: Song? = nil
    @State private var editingSongForEditSheet: Song? = nil

    private var availablePieceTypes: [PieceType] {
        [PieceType.song, .scale, .exercise, .warmUp].filter { wanted in viewModel.songs.contains { $0.pieceType == wanted } }
    }
    
    private var filteredSongs: [Song] {
        if let selectedType = selectedPieceType {
            return viewModel.songs.filter { $0.pieceType == selectedType }
        } else {
            return viewModel.songs
        }
    }

    // Helper to group and sort songs by status
    private var groupedSortedSongs: [(key: PlayType?, value: [Song])]
    {
        // Only include songs that are of type 'Song' or have no pieceType
        let normalSongs = filteredSongs.filter { $0.pieceType == nil || $0.pieceType == .song }
        // 1. Group by songStatus
        let grouped = Dictionary(grouping: normalSongs, by: { $0.songStatus })
        // 2. Sort each group as per selectedSort
        let sortedKeys = PlayType.allCases.map { Optional($0) } + [nil] // All statuses, nil last

        return sortedKeys.compactMap { status in
            guard let group = grouped[status] else { return nil }
            let sortedGroup: [Song]
            switch selectedSort {
            case .title:
                sortedGroup = group.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .playCount:
                sortedGroup = group.sorted { $0.totalPlayCount > $1.totalPlayCount }
            case .recentlyPlayed:
                sortedGroup = group.sorted { ($0.lastPlayedDate ?? .distantPast) > ($1.lastPlayedDate ?? .distantPast) }
            }
            return (key: status, value: sortedGroup)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button(action: { selectedPieceType = nil }) {
                        Text("All")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(selectedPieceType == nil ? Color.accentColor : Color.gray.opacity(0.2))
                            .foregroundColor(selectedPieceType == nil ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    ForEach(availablePieceTypes, id: \.self) { type in
                        Button(action: { selectedPieceType = type }) {
                            Text(type.rawValue)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(selectedPieceType == type ? Color.accentColor : Color.gray.opacity(0.2))
                                .foregroundColor(selectedPieceType == type ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }.padding(.horizontal)
            }
            
            List {
                /*Section() {
                    Picker("Sort by", selection: $selectedSort) {
                        ForEach(SongSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }*/

                ForEach(groupedSortedSongs, id: \.key) { section in
                    Section(header: Text(section.key?.rawValue ?? "No Status")) {
                        ForEach(section.value, id: \.persistentModelID) { song in
                            NavigationLink(destination: SongDetailView(song: song)) {
                                SongRowView(song: song, progress: viewModel.practiceVM.progress(for: song))
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingSongForEditSheet = song
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }.tint(.orange)
                            }
                        }
                        .onDelete { indexSet in
                            // Delete the correct songs from this group
                            let toDelete = indexSet.map { section.value[$0] }
                            for song in toDelete {
                                viewModel.deleteSong(song)
                            }
                            try? viewModel.context.save()
                            viewModel.practiceVM.reload()
                        }
                    }
                }

                // New sections for Scales, Warm-ups, and Exercises
                // Only show these sections if no filter or if the selectedPieceType matches
                
                if selectedPieceType == nil || selectedPieceType == .scale {
                    Section(header: Text("Scales")) {
                        let scales = filteredSongs.filter { $0.pieceType == .scale }
                        ForEach(scales, id: \.persistentModelID) { song in
                            NavigationLink(destination: SongDetailView(song: song)) {
                                SongRowView(song: song, progress: viewModel.practiceVM.progress(for: song))
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingSongForEditSheet = song
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }.tint(.orange)
                            }
                        }
                    }
                }

                if selectedPieceType == nil || selectedPieceType == .warmUp {
                    Section(header: Text("Warm-ups")) {
                        let warmUps = filteredSongs.filter { $0.pieceType == .warmUp }
                        ForEach(warmUps, id: \.persistentModelID) { song in
                            NavigationLink(destination: SongDetailView(song: song)) {
                                SongRowView(song: song, progress: viewModel.practiceVM.progress(for: song))
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingSongForEditSheet = song
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }.tint(.orange)
                            }
                        }
                    }
                }

                if selectedPieceType == nil || selectedPieceType == .exercise {
                    Section(header: Text("Exercises")) {
                        let exercises = filteredSongs.filter { $0.pieceType == .exercise }
                        ForEach(exercises, id: \.persistentModelID) { song in
                            NavigationLink(destination: SongDetailView(song: song)) {
                                SongRowView(song: song, progress: viewModel.practiceVM.progress(for: song))
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingSongForEditSheet = song
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }.tint(.orange)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingRandomSongPicker) {
            RandomSongPickerView(songs: viewModel.songs)
        }
        .sheet(item: $editingSong) { song in
            SongDetailView(song: song)
        }
        .sheet(item: $editingSongForEditSheet) { song in
            EditSongSheet(isPresented: Binding(get: { editingSongForEditSheet != nil }, set: { if !$0 { editingSongForEditSheet = nil } }), song: song)
        }
    }
}
