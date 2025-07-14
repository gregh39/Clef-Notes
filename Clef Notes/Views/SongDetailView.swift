import Swift
import SwiftUI
import SwiftData
import PhotosUI
import AVKit
import WebKit
import UniformTypeIdentifiers

struct SongDetailView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var audioManager: AudioManager
    @Bindable var song: Song

    @State private var showingEditSheet = false
    @State private var showingAddNoteSheet = false
    @State private var editingNote: Note? = nil
    
    @StateObject private var audioPlayerManager: AudioPlayerManager

    init(song: Song, audioManager: AudioManager) {
        self.song = song
        self._audioPlayerManager = StateObject(wrappedValue: AudioPlayerManager(audioManager: audioManager))
    }

    private var groupedPlaysBySession: [(key: PracticeSession?, value: [Play])] {
        let grouped = Dictionary(grouping: song.plays ?? [], by: { $0.session })
        let sortedGroups = grouped.sorted { ($0.key?.day ?? .distantPast) > ($1.key?.day ?? .distantPast) }
        
        let cumulativeTotals = song.cumulativeTotalsByType
        
        return sortedGroups.map { (session, plays) in
            let sortedPlays = plays.sorted {
                (cumulativeTotals[$0] ?? 0) > (cumulativeTotals[$1] ?? 0)
            }
            return (key: session, value: sortedPlays)
        }
    }

    var body: some View {
        TabView {
            playsTab
                .tabItem { Label("Plays", systemImage: "music.note.list") }
            
            mediaTab
                .tabItem { Label("Media", systemImage: "link") }

            notesTab
                .tabItem { Label("Notes", systemImage: "note.text") }
        }
        .navigationTitle(song.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showingEditSheet = true }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditSongSheet(song: song)
        }
        .sheet(item: $editingNote) { note in
            AddNoteSheet(note: note)
        }
    }

    // MARK: - Extracted Tab Views

    private var playsTab: some View {
        PlaysListView(groupedPlays: groupedPlaysBySession)
    }

    private var mediaTab: some View {
        List {
            Section("Media") {
                if (song.media ?? []).isEmpty {
                    Text("No media has been added to this song.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(song.media ?? []) { media in
                        MediaCell(media: media, audioPlayerManager: audioPlayerManager)
                            .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteMedia)
                }
            }
        }
    }
    
    private var notesTab: some View {
        List {
            Section {
                let sortedNotes = (song.notes ?? []).sorted { ($0.session?.day ?? .distantPast) > ($1.session?.day ?? .distantPast) }
                ForEach(sortedNotes) { note in
                    NoteCell(note: note)
                }
                .onDelete { indexSet in
                    deleteNote(at: indexSet, from: sortedNotes)
                }
            } header: {
                Text("Notes")
            }
        }
    }
    
    // MARK: - Helper Logic
    
    private func deleteMedia(at offsets: IndexSet) {
        var mediaToDelete: [MediaReference] = []
        for index in offsets {
            if let media = song.media?[index] {
                mediaToDelete.append(media)
            }
        }

        for media in mediaToDelete {
            context.delete(media)
        }

        song.media?.remove(atOffsets: offsets)

        try? context.save()
    }
    
    private func deleteNote(at offsets: IndexSet, from notes: [Note]) {
        var notesToDelete: [Note] = []
        for index in offsets {
            notesToDelete.append(notes[index])
        }

        for note in notesToDelete {
            song.notes?.removeAll { $0.id == note.id }
            context.delete(note)
        }
        try? context.save()
    }
}

// MARK: - Reusable Cell Views

private struct MediaCell: View {
    let media: MediaReference
    @ObservedObject var audioPlayerManager: AudioPlayerManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch media.type {
            case .audioRecording:
                // --- THIS IS THE FIX ---
                // Use the new, reusable AudioPlaybackCell here as well.
                AudioPlaybackCell(
                    title: media.title ?? "Local Audio",
                    subtitle: media.type.rawValue,
                    data: media.data,
                    duration: media.duration,
                    id: media.persistentModelID,
                    audioPlayerManager: audioPlayerManager
                )
                
            case .localVideo:
                Text(media.type.rawValue.capitalized).font(.headline)
                if let videoData = media.data,
                   let tempURL = saveToTemporaryFile(data: videoData) {
                    VideoPlayer(player: AVPlayer(url: tempURL))
                        .frame(height: 200).cornerRadius(8)
                } else {
                    Text("Video data is missing.").foregroundColor(.red)
                }

            case .youtubeVideo, .spotifyLink, .appleMusicLink, .sheetMusic:
                Text(media.type.rawValue.capitalized).font(.headline)
                if let url = media.url {
                    switch media.type {
                    case .youtubeVideo:
                        if let id = extractYouTubeID(from: url) {
                            YouTubePlayerView(videoID: id)
                        }
                    case .spotifyLink:
                        if let embedURL = URL(string: url.absoluteString.replacingOccurrences(of: "/track/", with: "/embed/track/")) {
                             WebView(url: embedURL).frame(height: 80).cornerRadius(8)
                        }
                    case .appleMusicLink:
                        Link("Open in Apple Music", destination: url)
                    case .sheetMusic:
                        Link("Open Sheet Music", destination: url)
                    default: EmptyView()
                    }
                }
            }
        }
    }
    
    private func saveToTemporaryFile(data: Data) -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Failed to write video data to temporary file: \(error)")
            return nil
        }
    }
}

// The private AudioFile and AudioPlaybackCell structs are no longer needed here.

private struct NoteCell: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.text)
            if let sessionDate = note.session?.day {
                Text(sessionDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Web and YouTube Views

private struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(URLRequest(url: url))
    }
}

private struct YouTubePlayerView: View {
    let videoID: String
    var body: some View {
        WebView(url: URL(string: "https://www.youtube.com/embed/\(videoID)")!)
            .frame(height: 200)
            .cornerRadius(8)
    }
}

private func extractYouTubeID(from url: URL) -> String? {
    let host = url.host?.lowercased()
    let path = url.path
    
    if host?.contains("youtube.com") == true,
       let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
       let v = queryItems.first(where: { $0.name == "v" })?.value {
        return v
    } else if host?.contains("youtu.be") == true {
        return String(path.dropFirst())
    }
    return nil
}
