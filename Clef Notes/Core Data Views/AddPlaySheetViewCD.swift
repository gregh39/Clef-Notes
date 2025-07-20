import SwiftUI
import CoreData

struct AddPlaySheetViewCD: View {
    @ObservedObject var session: PracticeSessionCD
    @Binding var showingAddPlaySheet: Bool
    @Binding var showingAddSongSheet: Bool
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest var songs: FetchedResults<SongCD>
    
    @State private var selectedSong: SongCD? = nil
    @State private var selectedPlayType: PlayType? = nil
    @State private var searchText = ""
    @State private var selectedPieceType: PieceType? = nil

    init(session: PracticeSessionCD, showingAddPlaySheet: Binding<Bool>, showingAddSongSheet: Binding<Bool>) {
        self.session = session
        self._showingAddPlaySheet = showingAddPlaySheet
        self._showingAddSongSheet = showingAddSongSheet
        
        let studentID = session.student?.id
        let predicate = NSPredicate(format: "student.id == %@", (studentID ?? UUID()) as NSUUID)
        
        self._songs = FetchRequest<SongCD>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SongCD.title, ascending: true)],
            predicate: predicate
        )
    }
    
    private var filteredSongs: [SongCD] {
        var songsToFilter = Array(songs)
        
        if let type = selectedPieceType {
            songsToFilter = songsToFilter.filter { $0.pieceType == type }
        }
        
        if !searchText.isEmpty {
            songsToFilter = songsToFilter.filter { $0.title?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
        
        return songsToFilter
    }
    
    private var availablePieceTypes: [PieceType] {
        let allTypes = songs.compactMap { $0.pieceType }
        return Array(Set(allTypes)).sorted { $0.rawValue < $1.rawValue }
    }
    
    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterButton(title: "All", type: nil, selectedType: $selectedPieceType)
                
                ForEach(availablePieceTypes, id: \.self) { type in
                    FilterButton(title: type.rawValue, type: type, selectedType: $selectedPieceType)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
    
    var body: some View {
        NavigationStack {
            // --- THIS IS THE FIX: A VStack now separates the scrolling content from the footer ---
            VStack(spacing: 0) {
                // The ScrollView contains the song list
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Section {
                            Button {
                                showingAddPlaySheet = false
                                showingAddSongSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill").foregroundColor(.green)
                                    Text("Add New Song")
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                                }
                                .padding()
                                .background(.background.secondary)
                                .cornerRadius(10)
                            }
                        }
                        .listRowInsets(EdgeInsets())

                        if !availablePieceTypes.isEmpty {
                            typeFilterBar
                        }
                        
                        if filteredSongs.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                                .padding(.top, 50)
                        } else {
                            let grouped = Dictionary(grouping: filteredSongs, by: { $0.pieceType })
                            let sortedKeys = grouped.keys.sorted {
                                let order: [PieceType?] = [nil, .song, .scale, .warmUp, .exercise]
                                let firstIndex = order.firstIndex(of: $0) ?? 99
                                let secondIndex = order.firstIndex(of: $1) ?? 99
                                return firstIndex < secondIndex
                            }
                            
                            ForEach(sortedKeys, id: \.self) { key in
                                if let songsInGroup = grouped[key], !songsInGroup.isEmpty {
                                    Section(header: Text(key?.rawValue ?? "Songs").font(.title3.bold())) {
                                        ForEach(songsInGroup) { song in
                                            Button(action: {
                                                selectedSong = song
                                                selectedPlayType = song.songStatus
                                            }) {
                                                SongPickerCardView(song: song, isSelected: selectedSong == song)
                                            }
                                        }
                                    }
                                    .padding(.bottom, 8)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(UIColor.systemGroupedBackground))

                // The "footer" view is outside the ScrollView, so it's always visible.
                if selectedSong != nil {
                    VStack(spacing: 8) {
                        Divider()
                        Picker("Play Type", selection: $selectedPlayType) {
                            Text("None").tag(PlayType?.none)
                            ForEach(PlayType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(Optional(type))
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        if selectedPlayType == .learning {
                            Text("When learning a song, new plays will not be counted toward the number of plays goal.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    .background(.bar)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: selectedSong)
            .navigationTitle("Choose Song")
            .searchable(text: $searchText, prompt: "Find a song...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addPlay()
                        dismiss()
                    }
                    .disabled(selectedSong == nil)
                }
            }
        }
    }
    
    private func addPlay() {
        guard let song = selectedSong else { return }
        let play = PlayCD(context: viewContext)
        play.count = 1
        play.song = song
        play.session = session
        play.student = session.student
        play.playType = selectedPlayType
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save play: \(error)")
        }
    }
}


private struct FilterButton: View {
    let title: String
    let type: PieceType?
    @Binding var selectedType: PieceType?
    
    private var isSelected: Bool { selectedType == type }
    
    var body: some View {
        Button(action: {
            withAnimation { selectedType = type }
        }) {
            Text(title)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

private struct SongPickerCardView: View {
    @ObservedObject var song: SongCD
    let isSelected: Bool
    
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
        .padding()
        .background(.background.secondary)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}
