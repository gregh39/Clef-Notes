import SwiftUI
import SwiftData

struct StudentSongsTabView: View {
    @Binding var viewModel: StudentDetailViewModel
    @Binding var selectedSort: SongSortOption
    
    @State private var selectedPieceType: PieceType? = nil
    @State private var editingSongForEditSheet: Song? = nil

    private var availablePieceTypes: [PieceType] {
        // Creates a unique, ordered list of piece types present in the songs
        let allTypes = viewModel.songs.compactMap { $0.pieceType }
        return Array(Set(allTypes)).sorted { $0.rawValue < $1.rawValue }
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // This is our filter bar
            typeFilterBar
            
            // The main list now delegates its content to smaller views
            List {
                // Display normal songs, grouped by status
                songsSection
                
                // Display other piece types in their own dedicated sections
                SongSectionView(
                    title: "Scales",
                    songs: filteredSongs(for: .scale),
                    editingSong: $editingSongForEditSheet
                )
                
                SongSectionView(
                    title: "Warm-ups",
                    songs: filteredSongs(for: .warmUp),
                    editingSong: $editingSongForEditSheet
                )
                
                SongSectionView(
                    title: "Exercises",
                    songs: filteredSongs(for: .exercise),
                    editingSong: $editingSongForEditSheet
                )
            }
        }
        .sheet(item: $editingSongForEditSheet) { song in
            EditSongSheet(song: song)
        }
    }

    // MARK: - Extracted Subviews

    /// A horizontal scroll view for filtering by piece type.
    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterButton(title: "All", type: nil, selectedType: $selectedPieceType)
                
                ForEach(availablePieceTypes, id: \.self) { type in
                    FilterButton(title: type.rawValue, type: type, selectedType: $selectedPieceType)
                }
            }.padding(.horizontal)
        }
    }

    /// The section for displaying standard songs, grouped by their status.
    @ViewBuilder
    private var songsSection: some View {
        // Only show this section if "All" or "Song" is selected
        if selectedPieceType == nil || selectedPieceType == .song {
            let normalSongs = viewModel.songs.filter { $0.pieceType == nil || $0.pieceType == .song }
            let grouped = Dictionary(grouping: normalSongs, by: { $0.songStatus })
            
            // Sort keys to ensure consistent order: Learning, Practice, Review, No Status
            let sortedKeys = PlayType.allCases.map { Optional($0) } + [nil]

            ForEach(sortedKeys, id: \.self) { status in
                if let songsInGroup = grouped[status], !songsInGroup.isEmpty {
                    Section(header: Text(status?.rawValue ?? "No Status")) {
                        ForEach(songsInGroup) { song in
                            NavigationLink(destination: SongDetailView(song: song)) {
                                SongRowView(song: song, progress: viewModel.practiceVM.progress(for: song))
                            }
                            .swipeActions(edge: .leading) {
                                Button { editingSongForEditSheet = song } label: { Label("Edit", systemImage: "pencil") }.tint(.orange)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions
    
    /// Filters the main songs list for a specific piece type.
    private func filteredSongs(for type: PieceType) -> [Song] {
        // Only return songs for this section if "All" or the specific type is selected
        guard selectedPieceType == nil || selectedPieceType == type else { return [] }
        return viewModel.songs.filter { $0.pieceType == type }
    }
}


// MARK: - Reusable Components

/// A reusable view for displaying a section of songs (e.g., Scales, Exercises).
private struct SongSectionView: View {
    let title: String
    let songs: [Song]
    @Binding var editingSong: Song?

    var body: some View {
        if !songs.isEmpty {
            Section(header: Text(title)) {
                ForEach(songs) { song in
                    NavigationLink(destination: SongDetailView(song: song)) {
                        // Using SongRowView without progress for non-goal-oriented pieces
                        SongRowView(song: song, progress: 0)
                    }
                    .swipeActions(edge: .leading) {
                        Button { editingSong = song } label: { Label("Edit", systemImage: "pencil") }.tint(.orange)
                    }
                }
            }
        }
    }
}

/// A reusable filter button for the top bar.
private struct FilterButton: View {
    let title: String
    let type: PieceType?
    @Binding var selectedType: PieceType?
    
    private var isSelected: Bool { selectedType == type }
    
    var body: some View {
        Button(action: { selectedType = type }) {
            Text(title)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
