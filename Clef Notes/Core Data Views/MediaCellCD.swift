// Clef Notes/Core Data Views/MediaCellCD.swift

import SwiftUI
import CoreData
import AVKit
import WebKit
import MusicKit
import PDFKit

// A new detail view for presenting sheet music full screen.
private struct SheetMusicDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let data: Data
    let title: String

    var body: some View {
        NavigationView {
            Group { // Use a Group to easily switch between views
                if let uiImage = UIImage(data: data) {
                    // Use the new ZoomableScrollView
                    ZoomableScrollView {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                    }
                } else {
                    PDFKitView(data: data)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
struct MediaCellCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var media: MediaReferenceCD
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    
    // State to control the presentation of the sheet music detail view.
    @State private var showingSheetMusicDetail = false

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
                if let videoData = media.data,
                   let tempURL = saveToTemporaryFile(data: videoData) {
                    VideoPlayer(player: AVPlayer(url: tempURL))
                        .frame(height: 200).cornerRadius(8)
                } else {
                    Text("Video data is missing.").foregroundColor(.red)
                }

            case .youtubeVideo, .spotifyLink, .appleMusicLink, .sheetMusic:
                
                // --- THIS IS THE FIX: Updated sheet music case ---
                if media.type == .sheetMusic {
                    if let data = media.data {
                        Button(action: { showingSheetMusicDetail = true }) {
                            SheetMusicPreview(data: data)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showingSheetMusicDetail) {
                            SheetMusicDetailView(data: data, title: media.title ?? "Sheet Music")
                        }
                    }
                } else if let url = media.url {
                    switch media.type {
                    case .youtubeVideo:
                        if let id = extractYouTubeID(from: url) {
                            YouTubePlayerView(videoID: id)
                        }
                    case .spotifyLink:
                        if let embedURL = URL(string: url.absoluteString.replacingOccurrences(of: "/track/", with: "/embed/track/")) {
                             WebView(url: embedURL).frame(height: 200).cornerRadius(8)
                        }
                    case .appleMusicLink:
                        if let songID = extractAppleMusicID(from: url) {
                            AppleMusicPlayerView(songID: songID)
                        }
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

// A new view for the sheet music preview in the list.
private struct SheetMusicPreview: View {
    let data: Data
    
    var body: some View {
        HStack {
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 40))
                    .frame(width: 80, height: 80)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
            }
            Text("Tap to view")
                .font(.headline)
            Spacer()
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
    func makeUIView(context: Context) -> WKWebView {
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(URLRequest(url: url))
    }
}

private struct YouTubePlayerView: View {
    let videoID: String
    var body: some View {
        if let url = URL(string: "https://www.youtube.com/embed/\(videoID)") {
            WebView(url: url)
                .frame(height: 200)
                .cornerRadius(8)
        }
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

private struct AppleMusicPlayerView: View {
    let songID: MusicItemID
    @State private var song: Song?
    @State private var isPlaying = false

    var body: some View {
        VStack {
            if let song = song {
                HStack(spacing: 15) {
                    AsyncImage(url: song.artwork?.url(width: 100, height: 100)) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "music.note").font(.largeTitle)
                    }
                    .frame(width: 100, height: 100)
                    .cornerRadius(8)

                    VStack(alignment: .leading) {
                        Text(song.title).font(.headline).lineLimit(2)
                        Text(song.artistName).font(.subheadline).foregroundColor(.secondary)
                        Spacer()
                        Button(action: togglePlayback) {
                            HStack {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                Text(isPlaying ? "Pause" : "Play")
                            }
                            .frame(maxWidth: 100)
                        }
                        .buttonStyle(.bordered)
                        .tint(.pink)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)

            } else {
                ProgressView().onAppear(perform: fetchSong)
            }
        }
        .onAppear(perform: requestAuthorization)
        .onReceive(SystemMusicPlayer.shared.state.objectWillChange) { _ in
            updatePlaybackState()
        }
    }

    private func requestAuthorization() {
        Task {
            await MusicAuthorization.request()
        }
    }
    
    private func fetchSong() {
        Task {
            do {
                let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: songID)
                let response = try await request.response()
                self.song = response.items.first
            } catch {
                print("Failed to fetch song: \(error)")
            }
        }
    }

    private func togglePlayback() {
        Task {
            if isPlaying {
                SystemMusicPlayer.shared.pause()
            } else {
                guard let song = song else { return }
                SystemMusicPlayer.shared.queue = [song]
                try await SystemMusicPlayer.shared.play()
            }
            isPlaying.toggle()
        }
    }
    
    private func updatePlaybackState() {
        self.isPlaying = SystemMusicPlayer.shared.state.playbackStatus == .playing
    }
}

private func extractAppleMusicID(from url: URL) -> MusicItemID? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let queryItems = components.queryItems,
          let idString = queryItems.first(where: { $0.name == "i" })?.value else {
        return nil
    }
    return MusicItemID(idString)
}

import SwiftUI

/// A view that wraps a `UIScrollView` to allow for zooming and panning of its content.
struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        // Set up the UIScrollView
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 20
        scrollView.minimumZoomScale = 1
        scrollView.bouncesZoom = true

        // Create a UIHostingController to hold the SwiftUI content
        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = true
        hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostedView.frame = scrollView.bounds
        scrollView.addSubview(hostedView)

        return scrollView
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(hostingController: UIHostingController(rootView: self.content))
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Update the SwiftUI content when it changes
        context.coordinator.hostingController.rootView = self.content
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>

        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            // Return the view that we want to zoom
            return hostingController.view
        }
    }
}
