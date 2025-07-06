// Create a new view to encapsulate the addPlaySheetView logic that was previously in SessionDetailView
import SwiftUI
import SwiftData

struct AddPlaySheetView: View {
    @Binding var showingAddPlaySheet: Bool
    @Binding var showingAddSongSheet: Bool
    var session: PracticeSession
    @Query(sort: \Song.title) private var songs: [Song]
    @Environment(\.modelContext) private var context
    @State private var selectedSong: Song? = nil
    
    private var addNewSongSection: some View {
        Section {
            Button {
                showingAddPlaySheet = false
                showingAddSongSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    Text("Add New Song")
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        } header: {
            Text("Create")
        }
    }

    private var existingSongsSection: some View {
        Group {
            if !songs.isEmpty {
                Section {
                    ForEach(songs, id: \.persistentModelID) { song in
                        Button {
                            selectedSong = song
                        } label: {
                            HStack {
                                Text(song.title)
                                Spacer()
                                if selectedSong == song {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .listRowBackground(selectedSong == song ? Color.accentColor.opacity(0.2) : Color.clear)
                    }
                } header: {
                    Text("Existing Songs")
                }
            }
        }
    }

    private var playTypeSection: some View {
        Group {
                Section {
                    Picker("Play Type", selection: Binding(
                        get: { selectedSong?.songStatus },
                        set: { newValue in self.selectedSong?.songStatus = newValue }
                    )) {
                        Text("None").tag(PlayType?.none)
                        ForEach(PlayType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(Optional(type))
                        }
                    }
                    .disabled(self.selectedSong == nil)
                    if selectedSong?.songStatus == .learning {
                        Text("When learning a song, new plays will not be counted toward the number of plays goal.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                    }
                } header: {
                    Text("Play Type")
                }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                addNewSongSection
                existingSongsSection
                playTypeSection
            }
            .navigationTitle("Choose Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingAddPlaySheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard let selectedSong = selectedSong else { return }
                        let play = Play(count: 1)
                        play.song = selectedSong
                        play.session = session
                        play.playType = selectedSong.songStatus
                        if session.plays == nil {
                            session.plays = []
                        }
                        session.plays?.append(play)
                        context.insert(play)
                        try? context.save()
                        self.selectedSong = nil
                        showingAddPlaySheet = false
                    }
                    .disabled(selectedSong == nil)
                }
            }
        }
    }
}
