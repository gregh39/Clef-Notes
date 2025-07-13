import SwiftUI
import SwiftData

struct StudentSongsTabView: View {
    @Binding var viewModel: StudentDetailViewModel
    @Binding var selectedSort: SongSortOption
    
    // Get the AudioManager from the environment
    @EnvironmentObject var audioManager: AudioManager
    
    @State private var selectedPieceType: PieceType? = nil
    @State private var editingSongForEditSheet: Song? = nil

    private var availablePieceTypes: [PieceType] {
        let allTypes = viewModel.songs.compactMap { $0.pieceType }
        return Array(Set(allTypes)).sorted { $0.rawValue < $1.rawValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            typeFilterBar
            
            List {
                songsSection
                
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

    @ViewBuilder
    private var songsSection: some View {
        if selectedPieceType == nil || selectedPieceType == .song {
            let normalSongs = viewModel.songs.filter { $0.pieceType == nil || $0.pieceType == .song }
            let grouped = Dictionary(grouping: normalSongs, by: { $0.songStatus })
            
            let sortedKeys = PlayType.allCases.map { Optional($0) } + [nil]

            ForEach(sortedKeys, id: \.self) { status in
                if let songsInGroup = grouped[status], !songsInGroup.isEmpty {
                    Section(header: Text(status?.rawValue ?? "No Status")) {
                        ForEach(songsInGroup) { song in
                            // Pass the audioManager to the SongDetailView initializer
                            NavigationLink(destination: SongDetailView(song: song, audioManager: audioManager)) {
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
    
    private func filteredSongs(for type: PieceType) -> [Song] {
        guard selectedPieceType == nil || selectedPieceType == type else { return [] }
        return viewModel.songs.filter { $0.pieceType == type }
    }
}


// MARK: - Reusable Components

private struct SongSectionView: View {
    let title: String
    let songs: [Song]
    @Binding var editingSong: Song?
    
    // Get the AudioManager from the environment to pass it down
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        if !songs.isEmpty {
            Section(header: Text(title)) {
                ForEach(songs) { song in
                    // Pass the audioManager to the SongDetailView initializer
                    NavigationLink(destination: SongDetailView(song: song, audioManager: audioManager)) {
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
