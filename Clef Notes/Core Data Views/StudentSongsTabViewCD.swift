import SwiftUI
import CoreData

struct StudentSongsTabViewCD: View {
    @ObservedObject var student: StudentCD
    var onAddSong: () -> Void
    
    @EnvironmentObject var audioManager: AudioManager
    
    // State for sorting and filtering
    @State private var selectedSort: SongSortOption = .title
    @State private var selectedPieceType: PieceType? = nil
    @State private var searchText = ""
    
    // State for sheets and navigation
    @State private var editingSongForEditSheet: SongCD? = nil
    @State private var path = NavigationPath()

    // Computed property for available piece types to build the filter bar
    private var availablePieceTypes: [PieceType] {
        let allTypes = student.songsArray.compactMap { $0.pieceType }
        return Array(Set(allTypes)).sorted { $0.rawValue < $1.rawValue }
    }
    
    // Computed property that handles sorting AND filtering
    private var filteredAndSortedSongs: [SongCD] {
        // Start with the base array
        var filteredSongs = Array(student.songs as? Set<SongCD> ?? [])

        // Apply piece type filter
        if let type = selectedPieceType {
            filteredSongs = filteredSongs.filter { $0.pieceType == type }
        }

        // Apply search text filter
        if !searchText.isEmpty {
            filteredSongs = filteredSongs.filter {
                ($0.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.composer?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Apply sorting
        switch selectedSort {
        case .title:
            return filteredSongs.sorted { ($0.title ?? "") < ($1.title ?? "") }
        case .playCount:
            return filteredSongs.sorted { $0.totalPlayCount > $1.totalPlayCount }
        case .recentlyPlayed:
            return filteredSongs.sorted { ($0.lastPlayedDate ?? .distantPast) > ($1.lastPlayedDate ?? .distantPast) }
        }
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if student.songsArray.isEmpty {
                    ContentUnavailableView {
                        Label("No Songs Added", image: "add.song")
                    } description: {
                        Text("Tap the button to add your first song.")
                    } actions: {
                        Button("Add First Song", action: onAddSong)
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    songList
                }
            }
            .navigationDestination(for: SongCD.self) { song in
                SongDetailViewCD(song: song, audioManager: audioManager)
            }
            .navigationTitle("Songs")
            .searchable(text: $searchText, prompt: "Search Songs or Composers")
        }
    }

    @ViewBuilder
    private var songList: some View {
        if filteredAndSortedSongs.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            List {
                Section {
                    EmptyView()
                } header: {
                    typeFilterBar
                        .padding(.vertical, 2)
                }
                
                songsSection
                
                SongSectionViewCD(
                    title: "Scales",
                    songs: filteredSongs(for: .scale),
                    editingSong: $editingSongForEditSheet
                )
                
                SongSectionViewCD(
                    title: "Warm-ups",
                    songs: filteredSongs(for: .warmUp),
                    editingSong: $editingSongForEditSheet
                )
                
                SongSectionViewCD(
                    title: "Exercises",
                    songs: filteredSongs(for: .exercise),
                    editingSong: $editingSongForEditSheet
                )
            }
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort By", selection: $selectedSort) {
                            ForEach(SongSortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                    }
                }
            }
        }
    }

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
        let normalSongs = filteredAndSortedSongs.filter { $0.pieceType == nil || $0.pieceType == .song }
        let grouped = Dictionary(grouping: normalSongs, by: { $0.songStatus })
        
        let sortedKeys = PlayType.allCases.map { Optional($0) } + [nil]

        ForEach(sortedKeys, id: \.self) { status in
            if let songsInGroup = grouped[status], !songsInGroup.isEmpty {
                Section(header: Text(status?.rawValue ?? "No Status")) {
                    ForEach(songsInGroup) { song in
                        ZStack {
                            SongCardView(song: song)
                            NavigationLink(value: song) {
                                EmptyView()
                            }
                            .opacity(0)
                        }
                        .swipeActions(edge: .leading) {
                            Button { editingSongForEditSheet = song } label: { Label("Edit", systemImage: "pencil") }.tint(.orange)
                        }
                    }
                }
            }
        }
    }
    
    private func filteredSongs(for type: PieceType) -> [SongCD] {
        return filteredAndSortedSongs.filter { $0.pieceType == type }
    }
}

private struct SongSectionViewCD: View {
    let title: String
    let songs: [SongCD]
    @Binding var editingSong: SongCD?
    
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        if !songs.isEmpty {
            Section(header: Text(title)) {
                ForEach(songs) { song in
                    ZStack {
                        SongCardView(song: song)
                        NavigationLink(value: song) {
                            EmptyView()
                        }
                        .opacity(0)
                    }
                    .swipeActions(edge: .leading) {
                        Button { editingSong = song } label: { Label("Edit", systemImage: "pencil") }.tint(.orange)
                    }
                }
            }
        }
    }
}

private struct SongCardView: View {
    @ObservedObject var song: SongCD
    
    private var progress: Double {
        guard let goal = song.goalPlays > 0 ? Double(song.goalPlays) : nil else { return 0.0 }
        let total = Double(song.totalGoalPlayCount)
        return min(total / goal, 1.0)
    }
    
    private var statusColor: Color {
        switch song.songStatus {
        case .learning: .blue
        case .practice: .green
        case .review: .purple
        case .none: .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(song.title ?? "Unknown Song")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if let status = song.songStatus {
                    Text(status.rawValue.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            if song.songStatus == .practice {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: statusColor))
                    
                    HStack {
                        Text("Goal")
                        Spacer()
                        Text("\(song.totalGoalPlayCount) / \(song.goalPlays) Plays")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
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
                .textCase(.none)
                .padding(.horizontal, 14)
                .padding(.vertical, 2)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
