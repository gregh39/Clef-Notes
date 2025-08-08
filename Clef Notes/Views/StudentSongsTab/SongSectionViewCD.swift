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
                    ZStack {
                        SongCardView(song: song)
                        NavigationLink(value: song) {
                            EmptyView()
                        }
                        .opacity(0)
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
