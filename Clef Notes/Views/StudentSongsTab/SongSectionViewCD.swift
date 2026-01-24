//
//  SongSectionViewCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/7/25.
//
import SwiftUI

struct SongSectionViewCD: View {
    let title: String
    let songs: [SongCD]
    @Binding var editingSong: SongCD?
    @Binding var songToDelete: SongCD?
    @Binding var showingDeleteAlert: Bool
    
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        if !songs.isEmpty {
            Section(header: Text(title)) {
                ForEach(songs) { song in
                    NavigationLink {
                        SongDetailViewCD(song: song, audioManager: audioManager)
                    } label: {
                        SongCardView(song: song)
                            .contentShape(Rectangle())   // ensures full row is tappable
                    }
                    .swipeActions(edge: .leading) {
                        Button { editingSong = song } label: { Label("Edit", systemImage: "pencil") }.tint(.orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            songToDelete = song
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
    }
}
