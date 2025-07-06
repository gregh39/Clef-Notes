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
import AVFoundation

struct SongDetailView: View {
    @Environment(\.modelContext) private var context
    let song: Song

    @State private var editedTitle: String
    @State private var editedSongStatus: PlayType?
    @State private var newMediaURL: String = ""
    @State private var newMediaType: MediaType = .youtubeVideo
    @State private var showingEditSheet = false

    @State private var notesForSong: [Note] = []

    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var videoFileURL: URL? = nil

    @State private var audioPlayerManager = AudioPlayerManager()
    
    init(song: Song) {
        self.song = song
        _editedTitle = State(initialValue: song.title)
        _editedSongStatus = State(initialValue: song.songStatus)
    }

    var taggedRecordings: [AudioRecording] {
        let allRecordings = (try? context.fetch(FetchDescriptor<AudioRecording>())) ?? []
        return allRecordings.filter { ($0.songs ?? []).contains(where: { $0.id == song.id }) }
            .sorted { ($0.dateRecorded) > ($1.dateRecorded) }
    }
    
    // 1. NEW: A property to pre-calculate all totals at once.
    private var cumulativePlayTotals: [Play: Int] {
        guard let plays = song.plays else { return [:] }

        // Sort the plays chronologically just ONCE.
        let sortedPlays = plays.sorted {
            ($0.session?.day ?? .distantPast) < ($1.session?.day ?? .distantPast)
        }
        
        var totals: [Play: Int] = [:]
        var runningTotal = 0
        
        // Loop through the sorted plays ONCE to calculate totals.
        for play in sortedPlays {
            runningTotal += play.count
            totals[play] = runningTotal
        }
        
        return totals
    }
    
    // 2. MODIFIED: Use the pre-calculated totals for sorting.
    var groupedPlaysBySession: [(key: PracticeSession?, value: [Play])] {
        let grouped = Dictionary(grouping: song.plays ?? [], by: { $0.session })
        
        let sortedGroups = grouped.sorted { lhs, rhs in
            let lhsDate = lhs.key?.day ?? .distantPast
            let rhsDate = rhs.key?.day ?? .distantPast
            return lhsDate > rhsDate
        }
        
        return sortedGroups.map { (session, plays) in
            // Use the dictionary for a super-fast lookup.
            let sortedPlays = plays.sorted {
                // Default to 0 if a play isn't in the dictionary.
                (cumulativePlayTotals[$0] ?? 0) > (cumulativePlayTotals[$1] ?? 0)
            }
            return (key: session, value: sortedPlays)
        }
    }

    var body: some View {
        TabView {
            // Plays Tab
            PlaysListView(
                groupedPlays: groupedPlaysBySession
            )
            .tabItem {
                Label("Plays", systemImage: "music.note.list")
            }
            // Media Tab
            List {
                Section("Media") {
                    ForEach(song.media ?? [], id: \.persistentModelID) { media in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(media.type.rawValue.capitalized)
                                .font(.headline)
                            if let murl = media.url{
                                switch media.type {
                                case .youtubeVideo:
                                    if let id = extractYouTubeID(from: murl) {
                                        YouTubePlayerView(videoID: id)
                                    } else {
                                        Text(murl.absoluteString)
                                            .foregroundColor(.blue)
                                    }
                                case .spotifyLink:
                                    if let embedURL = URL(string: murl.absoluteString.replacingOccurrences(of: "open.spotify.com/", with: "open.spotify.com/embed/")) {
                                        WebView(url: embedURL)
                                            .frame(height: 80)
                                            .cornerRadius(8)
                                    } else {
                                        Text(murl.absoluteString)
                                            .foregroundColor(.blue)
                                    }
                                case .appleMusicLink:
                                    Link("Open in Apple Music", destination: murl)
                                case .localVideo:
                                    VideoPlayer(player: AVPlayer(url: murl))
                                        .frame(height: 200)
                                        .cornerRadius(8)
                                default:
                                    Text(murl.absoluteString)
                                        .foregroundColor(.blue)
                                    
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button(role: .destructive) {
                                context.delete(media)
                                try? context.save()
                                notesForSong = notesForSong.filter { $0.id != media.id }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                

                Section("Audio Recordings") {
                    if taggedRecordings.isEmpty {
                        Text("No audio recordings tagged with this song.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(taggedRecordings, id: \.persistentModelID) { recording in
                            AudioRecordingCell(
                                recording: recording,
                                audioPlayerManager: audioPlayerManager,
                                onDelete: nil
                            )
                            .id(audioPlayerManager.currentlyPlayingID)
                        }
                        .onDelete { indices in
                            let toDelete = indices.map { taggedRecordings[$0] }
                            for recording in toDelete {
                                context.delete(recording)
                            }
                            try? context.save()
                        }
                    }
                }
            }
            .tabItem {
                Label("Media", systemImage: "link")
            }

            // Notes Tab
            List {
                Section("Notes") {
                    if notesForSong.isEmpty {
                        Text("No notes yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(notesForSong, id: \.persistentModelID) { note in
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
                }
            }
            .tabItem {
                Label("Notes", systemImage: "note.text")
            }
            .onAppear {
                print("Just making sure shit is printing")
                let allNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
                notesForSong = fetchNotesForSong(from: allNotes)
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
            NavigationStack {
                Form {
                    Section("Song Title") {
                        TextField("Title", text: $editedTitle)
                        Picker("Status", selection: $editedSongStatus) {
                            Text("None").tag(Optional<PlayType>(nil))
                            ForEach(PlayType.allCases, id: \.self) { status in
                                Text(status.rawValue).tag(Optional(status))
                            }
                        }
                    }

                    Section("Add Media") {
                        Picker("Type", selection: $newMediaType) {
                            ForEach(MediaType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }

                        if newMediaType == .localVideo {
                            PhotosPicker("Select Video", selection: $selectedVideoItem, matching: .videos)

                            if let videoFileURL = videoFileURL {
                                Text(videoFileURL.lastPathComponent)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            TextField("Enter media URL", text: $newMediaURL)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                        }

                        Button("Add Media") {
                            let url: URL?
                            if newMediaType == .localVideo {
                                url = videoFileURL
                            } else {
                                url = URL(string: newMediaURL)
                            }

                            guard let finalURL = url else { return }
                            let media = MediaReference(type: newMediaType, url: finalURL)
                            media.song = song
                            if song.media == nil { song.media = [] }
                            song.media?.append(media)
                            context.insert(media)
                            try? context.save()
                            newMediaURL = ""
                            newMediaType = .youtubeVideo
                        }
                        .disabled(newMediaType != .localVideo && newMediaURL.trimmingCharacters(in: .whitespaces).isEmpty)
 
                    }
                }
                .navigationTitle("Edit Song")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingEditSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            song.title = editedTitle
                            song.songStatus = editedSongStatus
                            try? context.save()
                            showingEditSheet = false

                        }

                    }
                }
                .onAppear {
                    editedSongStatus = song.songStatus
                }
            }
            .onChange(of: selectedVideoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                        try? data.write(to: tempURL)
                        videoFileURL = tempURL
                    }
                }
            }
        }
        
    }
    
    func fetchNotesForSong(from allNotes: [Note]) -> [Note] {
        allNotes
            .filter { note in
                note.songs?.contains(where: { $0.id == song.id }) == true
            }
            .sorted {
                ($0.session?.day ?? .distantPast) > ($1.session?.day ?? .distantPast)
            }
    }
}


import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        return WKWebView(frame: .zero, configuration: config)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

struct YouTubePlayerView: View {
    let videoID: String

    var body: some View {
        WebView(url: URL(string: "https://www.youtube.com/embed/\(videoID)?playsinline=1&fs=0")!)
            .frame(height: 200)
            .cornerRadius(8)
    }
}

func extractYouTubeID(from url: URL) -> String? {
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       components.host?.contains("youtube.com") == true,
       let queryItems = components.queryItems,
       let v = queryItems.first(where: { $0.name == "v" })?.value {
        return v
    } else if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host?.contains("youtu.be") == true {
        return components.path.dropFirst().description
    }
    return nil
}

