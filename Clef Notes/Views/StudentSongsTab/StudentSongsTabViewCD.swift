import SwiftUI
import CoreData

struct StudentSongsTabViewCD: View {
    @ObservedObject var student: StudentCD
    var onAddSong: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager
    
    // State for sorting and filtering
    @State private var selectedSort: SongSortOption = .title
    @State private var selectedPieceType: PieceType? = nil
    @State private var searchText = ""
    @State private var selectedSuzukiBook: SuzukiBook? = nil
    @State private var showingFilterSheet = false
    
    // State for sheets and navigation
    @State private var editingSongForEditSheet: SongCD? = nil
    @State private var path = NavigationPath()

    // Add state for the delete confirmation alert
    @State private var songToDelete: SongCD?
    @State private var showingDeleteAlert = false

    // Computed property for available piece types to build the filter bar
    private var availablePieceTypes: [PieceType] {
        let allTypes = student.songsArray.compactMap { $0.pieceType }
        return Array(Set(allTypes)).sorted { $0.rawValue < $1.rawValue }
    }
    
    private var activeFilterCount: Int {
        var count = 0
        if selectedPieceType != nil { count += 1 }
        if selectedSuzukiBook != nil { count += 1 }
        return count
    }
    
    // Computed property that handles sorting AND filtering
    private var filteredAndSortedSongs: [SongCD] {
        // Start with the base array
        var filteredSongs = Array(student.songs as? Set<SongCD> ?? [])

        // Apply piece type filter
        if let type = selectedPieceType {
            filteredSongs = filteredSongs.filter { $0.pieceType == type }
        }
        
        // Apply SuzukiBook filter
        if let suzukiBook = selectedSuzukiBook {
            filteredSongs = filteredSongs.filter { $0.suzukiBook == suzukiBook }
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
            .alert(isPresented: $showingDeleteAlert) {
                Alert(
                    title: Text("Delete Song?"),
                    message: Text("Are you sure you want to delete this song? All of its plays will be deleted as well."),
                    primaryButton: .destructive(Text("Delete")) {
                        if let song = songToDelete {
                            delete(song: song)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showingFilterSheet) {
                SongFilterSheet(
                    availablePieceTypes: availablePieceTypes,
                    selectedPieceType: $selectedPieceType,
                    isSuzuki: student.suzukiStudent?.boolValue == true,
                    selectedSuzukiBook: $selectedSuzukiBook
                )
                .presentationDetents([.medium])
            }
            .toolbar {
                ToolbarItem() {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        ZStack {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                            if activeFilterCount > 0 {
                                Text("\(activeFilterCount)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 12, y: -12)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var songList: some View {
        VStack(spacing: 0) {
            if filteredAndSortedSongs.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    songsSection
                    
                    SongSectionViewCD(
                        title: "Scales",
                        songs: filteredSongs(for: .scale),
                        editingSong: $editingSongForEditSheet,
                        songToDelete: $songToDelete,
                        showingDeleteAlert: $showingDeleteAlert
                    )
                    
                    SongSectionViewCD(
                        title: "Warm-ups",
                        songs: filteredSongs(for: .warmUp),
                        editingSong: $editingSongForEditSheet,
                        songToDelete: $songToDelete,
                        showingDeleteAlert: $showingDeleteAlert
                    )
                    
                    SongSectionViewCD(
                        title: "Exercises",
                        songs: filteredSongs(for: .exercise),
                        editingSong: $editingSongForEditSheet,
                        songToDelete: $songToDelete,
                        showingDeleteAlert: $showingDeleteAlert
                    )
                }
                .listStyle(.insetGrouped)
            }
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                songToDelete = song
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
            }
        }
    }
    
    private func filteredSongs(for type: PieceType) -> [SongCD] {
        return filteredAndSortedSongs.filter { $0.pieceType == type }
    }

    private func delete(song: SongCD) {
        viewContext.delete(song)
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}


