//
//  MediaCellCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/16/25.
//


import SwiftUI
import CoreData
import AVKit
import WebKit

struct MediaCellCD: View {
    @ObservedObject var media: MediaReferenceCD
    @ObservedObject var audioPlayerManager: AudioPlayerManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch media.type {
            case .audioRecording:
                AudioPlaybackCellCD(
                    title: media.title ?? "Local Audio",
                    subtitle: media.type?.rawValue ?? "Audio",
                    data: media.data,
                    duration: media.duration,
                    id: media.objectID,
                    audioPlayerManager: audioPlayerManager
                )
                
            case .localVideo:
                Text(media.type?.rawValue.capitalized ?? "Video").font(.headline)
                if let videoData = media.data,
                   let tempURL = saveToTemporaryFile(data: videoData) {
                    VideoPlayer(player: AVPlayer(url: tempURL))
                        .frame(height: 200).cornerRadius(8)
                } else {
                    Text("Video data is missing.").foregroundColor(.red)
                }

            case .youtubeVideo, .spotifyLink, .appleMusicLink, .sheetMusic:
                Text(media.type?.rawValue.capitalized ?? "Media").font(.headline)
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
            default:
                 Text("Unsupported media type")
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

struct NoteCellCD: View {
    @ObservedObject var note: NoteCD
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.text ?? "")
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
