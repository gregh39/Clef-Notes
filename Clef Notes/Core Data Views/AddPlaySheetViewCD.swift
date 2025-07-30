import SwiftUI
import CoreData
import TipKit

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

    @State private var addPlayTip = AddPlaySheetTip()

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
    
    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    List {
                        TipView(addPlayTip)
                        
                        if filteredSongs.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        } else {
                            let normalSongs = filteredSongs.filter { $0.pieceType == nil || $0.pieceType == .song }
                            let groupedByStatus = Dictionary(grouping: normalSongs, by: { $0.songStatus })
                            
                            let sortedStatusKeys = PlayType.allCases.map { Optional($0) } + [nil]

                            ForEach(sortedStatusKeys, id: \.self) { status in
                                if let songsInGroup = groupedByStatus[status], !songsInGroup.isEmpty {
                                    Section(header: Text(status?.rawValue ?? "No Status")) {
                                        ForEach(songsInGroup) { song in
                                            Button(action: {
                                                selectedSong = song
                                                selectedPlayType = song.songStatus
                                            }) {
                                                SongPickerRowView(song: song, isSelected: selectedSong == song)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            ForEach(PieceType.allCases.filter { $0 != .song }, id: \.self) { type in
                                let specificSongs = filteredSongs.filter { $0.pieceType == type }
                                if !specificSongs.isEmpty {
                                    Section(header: Text(type.rawValue)) {
                                        ForEach(specificSongs) { song in
                                            Button(action: {
                                                selectedSong = song
                                                selectedPlayType = song.songStatus
                                            }) {
                                                SongPickerRowView(song: song, isSelected: selectedSong == song)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)

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
                
                SaveButtonView(title: "Save", action: {
                    addPlay()
                    dismiss()
                }, isDisabled: selectedSong == nil)
            }
            .navigationTitle("Choose Song")
            .searchable(text: $searchText, prompt: "Find a song...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddPlaySheet = false
                        showingAddSongSheet = true
                    } label: {
                        Label("Add New Song", image: "add.song")
                    }
                }
                
                ToolbarItemGroup(placement: .confirmationAction) {
                    Menu {
                        Button {
                            selectedPieceType = nil
                        } label: {
                            Label("All", systemImage: selectedPieceType == nil ? "checkmark" : "")
                        }
                        
                        Divider()
                        
                        ForEach(availablePieceTypes, id: \.self) { type in
                            Button {
                                selectedPieceType = type
                            } label: {
                                Label(type.rawValue, systemImage: selectedPieceType == type ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                            .symbolVariant(selectedPieceType == nil ? .none : .fill)
                    }
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
        
        addPlayTip.invalidate(reason: .actionPerformed)
        
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
                .textCase(.none)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

private struct SongPickerRowView: View {
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
        HStack {
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
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .font(.headline.bold())
            }
        }
        .padding(.vertical, 6)
    }
}
