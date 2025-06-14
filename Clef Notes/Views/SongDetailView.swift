//
//  SongDetailView.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/11/25.
//

import Swift
import SwiftUI
import SwiftData

struct SongDetailView: View {
    @Environment(\.modelContext) private var context
    let song: Song

    @State private var editedTitle: String
    @State private var newMediaURL: String = ""
    @State private var newMediaType: MediaType = .youtubeVideo
    @State private var showingEditSheet = false

    @Query private var allNotes: [Note]

    init(song: Song) {
        self.song = song
        _editedTitle = State(initialValue: song.title)
        let songID = song.id
        let predicate = #Predicate<Note> {
            $0.song?.id == songID
        }
        _allNotes = Query(filter: predicate, sort: \.session?.day, order: .reverse)
    }

    var sortedPlays: [Play] {
        song.plays.sorted {
            ($0.session?.day ?? .distantPast) > ($1.session?.day ?? .distantPast)
        }
    }

    var body: some View {
        TabView {
            // Plays Tab
            List {
                ForEach(Array(Dictionary(grouping: sortedPlays, by: { $0.session })), id: \.key?.persistentModelID) { session, plays in
                    Section(header: Text(session?.day.formatted(date: .abbreviated, time: .omitted) ?? "Unknown Session")) {
                        ForEach(plays, id: \.persistentModelID) { play in
                            VStack(alignment: .leading) {
                                Text("Count: \(play.count)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
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

                            switch media.type {
                            case .youtubeVideo:
                                if let id = extractYouTubeID(from: media.url) {
                                    YouTubePlayerView(videoID: id)
                                } else {
                                    Text(media.url.absoluteString)
                                        .foregroundColor(.blue)
                                }
                            case .spotifyLink:
                                if let embedURL = URL(string: media.url.absoluteString.replacingOccurrences(of: "open.spotify.com/", with: "open.spotify.com/embed/")) {
                                    WebView(url: embedURL)
                                        .frame(height: 80)
                                        .cornerRadius(8)
                                } else {
                                    Text(media.url.absoluteString)
                                        .foregroundColor(.blue)
                                }
                            case .appleMusicLink:
                                Link("Open in Apple Music", destination: media.url)
                            default:
                                Text(media.url.absoluteString)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .tabItem {
                Label("Media", systemImage: "link")
            }

            // Notes Tab
            List {
                Section("Notes") {
                    if allNotes.isEmpty {
                        Text("No notes yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(allNotes, id: \.persistentModelID) { note in
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
                                Text(type.rawValue.capitalized).tag(type)
                            }
                        }

                        TextField("Enter media URL", text: $newMediaURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)

                        Button("Add Media") {
                            guard let url = URL(string: newMediaURL), !newMediaURL.isEmpty else { return }
                            let media = MediaReference(type: newMediaType, url: url)
                            media.song = song
                            song.media.append(media)
                            context.insert(media)
                            try? context.save()
                            newMediaURL = ""
                            newMediaType = .youtubeVideo
                        }
                        .disabled(newMediaURL.trimmingCharacters(in: .whitespaces).isEmpty)
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
        }
    }
}

import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

struct YouTubePlayerView: View {
    let videoID: String

    var body: some View {
        WebView(url: URL(string: "https://www.youtube.com/embed/\(videoID)")!)
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
