//
//  SongDetailView.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/11/25.
//

import Swift
import SwiftUI
import SwiftData
import PhotosUI
import AVKit

struct SongDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var song: Song

    // State for the edit sheet
    @State private var showingEditSheet = false

    // State for the notes display
    @State private var notesForSong: [Note] = []

    // State for audio playback
    @StateObject private var audioPlayerManager = AudioPlayerManager()
    
    // Use the @Transient property from the Song model
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
                .tabItem {
                    Label("Plays", systemImage: "music.note.list")
                }
            
            mediaTab
                .tabItem {
                    Label("Media", systemImage: "link")
                }

            notesTab
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
        }
        .navigationTitle(song.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditSongSheet(song: song)
        }
        .onAppear(perform: fetchNotesForSong)
    }

    // MARK: - Extracted Tab Views

    /// The content for the "Plays" tab.
    private var playsTab: some View {
        PlaysListView(
            groupedPlays: groupedPlaysBySession
        )
    }

    /// The content for the "Media" tab.
    private var mediaTab: some View {
        List {
            Section("Audio Recordings") {
                if taggedRecordings.isEmpty {
                    Text("No audio recordings tagged with this song.").foregroundColor(.secondary)
                } else {
                    ForEach(taggedRecordings) { recording in
                        AudioRecordingCell(recording: recording, audioPlayerManager: audioPlayerManager, onDelete: nil)
                    }
                }
            }

            Section("Other Media") {
                ForEach(song.media ?? []) { media in
                    MediaCell(media: media)
                        .padding(.vertical, 4)
                }
            }
        }
    }
    
    /// The content for the "Notes" tab.
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

    // MARK: - Helper Logic & Views
    
    private var taggedRecordings: [AudioRecording] {
        let allRecordings = (try? context.fetch(FetchDescriptor<AudioRecording>())) ?? []
        return allRecordings.filter { ($0.songs ?? []).contains(where: { $0.id == song.id }) }
            .sorted { $0.dateRecorded > $1.dateRecorded }
    }
    
    private func fetchNotesForSong() {
        let allNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        notesForSong = allNotes.filter { note in
            (note.songs ?? []).contains { $0.id == song.id }
        }.sorted { ($0.session?.day ?? .distantPast) > ($1.session?.day ?? .distantPast) }
    }
}


// MARK: - Subviews for Cells
// By creating smaller, dedicated views for your cells, you further simplify the main view.

private struct MediaCell: View {
    let media: MediaReference

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(media.type.rawValue.capitalized).font(.headline)
            if let murl = media.url {
                switch media.type {
                case .youtubeVideo:
                    if let id = extractYouTubeID(from: murl) {
                        YouTubePlayerView(videoID: id)
                    }
                case .spotifyLink:
                    // Note: You may need to adjust the URL for embedding
                    if let embedURL = URL(string: murl.absoluteString.replacingOccurrences(of: "/track/", with: "/embed/track/")) {
                         WebView(url: embedURL).frame(height: 80).cornerRadius(8)
                    }
                case .appleMusicLink:
                    Link("Open in Apple Music", destination: murl)
                case .localVideo:
                    VideoPlayer(player: AVPlayer(url: murl)).frame(height: 200).cornerRadius(8)
                default:
                    Link(murl.absoluteString, destination: murl).foregroundColor(.blue)
                }
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
// (These helpers remain the same)
import WebKit

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
