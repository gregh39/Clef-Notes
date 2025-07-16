//
//  SongDetailViewCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//


import SwiftUI
import CoreData

struct SongDetailViewCD: View {
    @ObservedObject var song: SongCD
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        // The content for this view will be refactored next
        Text("Detail view for \(song.title ?? "Unknown Song")")
            .navigationTitle(song.title ?? "Song")
    }
}
