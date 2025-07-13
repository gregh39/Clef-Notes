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
    @State private var notesForSong: [Note] = []
    
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
        .onAppear(perform: fetchNotesForSong)
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
                    // --- THIS IS THE FIX ---
                    // Add the onDelete modifier to enable swipe-to-delete
                    .onDelete(perform: deleteMedia)
                }
            }
        }
    }
    
    private var notesTab: some View {
        List {
            Section("Notes") {
                if notesForSong.isEmpty {
                    Text("No notes yet.").foregroundColor(.secondary)
                } else {
                    ForEach(notesForSong) { note in
                        NoteCell(note: note)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Logic
    
    private func fetchNotesForSong() {
        let allNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        notesForSong = allNotes.filter { note in
            (note.songs ?? []).contains { $0.id == song.id }
        }.sorted { ($0.session?.day ?? .distantPast) > ($1.session?.day ?? .distantPast) }
    }
    
    // --- THIS IS THE FIX ---
    // A new function to handle the deletion of media items.
    private func deleteMedia(at offsets: IndexSet) {
        // Create a temporary array of items to delete to avoid modifying the collection while iterating
        var mediaToDelete: [MediaReference] = []
        for index in offsets {
            if let media = song.media?[index] {
                mediaToDelete.append(media)
            }
        }

        // Delete the items from the SwiftData context
        for media in mediaToDelete {
            context.delete(media)
        }

        // Remove the items from the song's array to update the UI
        song.media?.remove(atOffsets: offsets)

        // Save the changes to the database
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
                // For audio recordings, use the unified playback cell.
                if let audioData = media.data {
                    AudioPlaybackCell(
                        title: media.title ?? "Local Audio",
                        subtitle: media.type.rawValue,
                        data: audioData,
                        duration: media.duration,
                        id: media.persistentModelID,
                        audioPlayerManager: audioPlayerManager
                    )
                } else {
                    Text("Audio data is missing.").foregroundColor(.red)
                }
                
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

// A helper struct to make audio data transferable for the ShareLink.
private struct AudioFile: Transferable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .mpeg4Audio) { audio in
            audio.data
        } importing: { data in
            AudioFile(data: data, filename: "imported.m4a")
        }
        .suggestedFileName { audio in
            audio.filename
        }
    }
}

// A unified view for playing ANY audio, whether from an AudioRecording or a MediaReference.
private struct AudioPlaybackCell: View {
    let title: String
    let subtitle: String
    let data: Data
    let duration: TimeInterval?
    let id: PersistentIdentifier
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    
    @State private var isScrubbing = false
    
    var isPlaying: Bool {
        audioPlayerManager.currentlyPlayingID == id
    }
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                    if let duration = duration {
                        Text("Duration: \(Int(duration))s").font(.caption2).foregroundColor(.gray)
                    }
                }
                Spacer()
                
                ShareLink(
                    item: AudioFile(data: data, filename: "\(title).m4a"),
                    preview: SharePreview(title, image: Image(systemName: "waveform"))
                ) {
                    Image(systemName: "square.and.arrow.up").foregroundColor(.accentColor)
                }
                
                Button(action: {
                    if isPlaying {
                        audioPlayerManager.stop()
                    } else {
                        audioPlayerManager.play(data: data, id: id)
                    }
                }) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill").foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 4)
            
            if isPlaying, let duration = duration {
                Slider(
                    value: Binding(
                        get: { isScrubbing ? audioPlayerManager.currentTime : min(audioPlayerManager.currentTime, duration) },
                        set: { isScrubbing = true; audioPlayerManager.currentTime = $0 }
                    ),
                    in: 0...duration,
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing {
                            audioPlayerManager.seek(to: audioPlayerManager.currentTime)
                        }
                    }
                )
                .accentColor(.accentColor)
                .padding(.horizontal, 8)
                HStack {
                    Text(String(format: "%02d:%02d", Int(audioPlayerManager.currentTime) / 60, Int(audioPlayerManager.currentTime) % 60))
                        .font(.caption2).foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%02d:%02d", Int(duration) / 60, Int(duration) % 60))
                        .font(.caption2).foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
            }
        }
    }
}

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
