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
    }

    var sortedPlays: [Play] {
        song.plays.sorted {
            $0.totalPlaysIncludingThis < $1.totalPlaysIncludingThis
        }
    }

    var taggedRecordings: [AudioRecording] {
        let allRecordings = (try? context.fetch(FetchDescriptor<AudioRecording>())) ?? []
        return allRecordings.filter { $0.songs.contains(where: { $0.id == song.id }) }
            .sorted { ($0.dateRecorded) > ($1.dateRecorded) }
    }

    var body: some View {
        TabView {
            // Plays Tab
            List {
                ForEach(Array(Dictionary(grouping: sortedPlays, by: { $0.session })), id: \.key?.persistentModelID) { session, plays in
                    Section(header: Text(session?.day.formatted(date: .abbreviated, time: .omitted) ?? "Unknown Session")) {
                        ForEach(plays, id: \.persistentModelID) { play in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Count: \(play.count)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Total: \(play.totalPlaysIncludingThis)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .tabItem {
                Label("Plays", systemImage: "music.note.list")
            }

            // Media Tab
            List {
                Section("Media") {
                    ForEach(song.media, id: \.persistentModelID) { media in
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
                let allNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
                notesForSong = allNotes.filter { note in
                    note.songs.contains(where: { $0.id == song.id })
                }.sorted {
                    ($0.session?.day ?? .distantPast) > ($1.session?.day ?? .distantPast)
                }
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
                        Button("Save Title") {
                            song.title = editedTitle
                            try? context.save()
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
                            song.media.append(media)
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
                        Button("Done") {
                            showingEditSheet = false
                        }
                    }
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
