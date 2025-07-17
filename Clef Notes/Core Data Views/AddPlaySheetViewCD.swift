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
    // --- CHANGE 1: Add state to hold the selected play type ---
    @State private var selectedPlayType: PlayType? = nil
    
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
    
    var body: some View {
        NavigationStack {
            List {
                Section("Create") {
                    Button {
                        // Dismiss this sheet and show the add song sheet
                        showingAddPlaySheet = false
                        showingAddSongSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill").foregroundColor(.green)
                            Text("Add New Song")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                }
                
                if !songs.isEmpty {
                    Section("Existing Songs") {
                        ForEach(songs) { song in
                            Button {
                                selectedSong = song
                                // --- CHANGE 2: When a song is selected, update the play type ---
                                selectedPlayType = song.songStatus
                            } label: {
                                HStack {
                                    Text(song.title ?? "Unknown")
                                    Spacer()
                                    if selectedSong == song {
                                        Image(systemName: "checkmark").foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .listRowBackground(selectedSong == song ? Color.accentColor.opacity(0.2) : Color.clear)
                        }
                    }
                }
                
                // --- CHANGE 3: Add the Play Type section ---
                Section("Play Type") {
                    Picker("Play Type", selection: $selectedPlayType) {
                        Text("None").tag(PlayType?.none)
                        ForEach(PlayType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(Optional(type))
                        }
                    }
                    .disabled(selectedSong == nil)
                    
                    if selectedPlayType == .learning {
                        Text("When learning a song, new plays will not be counted toward the number of plays goal.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                    }
                }
            }
            .navigationTitle("Choose Song")
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
        // --- CHANGE 4: Assign the selected play type ---
        play.playType = selectedPlayType
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save play: \(error)")
        }
    }
}
