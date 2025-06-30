//
//  PlaysSectionView.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/13/25.
//
import SwiftUI
import SwiftData


struct PlaysSectionView: View {
    @Bindable var session: PracticeSession
    
    @Binding var showingAddPlaySheet: Bool
    @Binding var showingAddSongSheet: Bool
    
    @Environment(\.modelContext) private var context
    
    @Query(sort: \Song.title) private var songs: [Song]

    var body: some View {
        Section("Session Plays") {
            if session.plays.isEmpty {
                Button {
                    showingAddPlaySheet = true
                } label: {
                    Label("Add a Play", systemImage: "music.note.list")
                        .font(.body)
                        .foregroundColor(.accentColor)
                }
            } else {
                ForEach(session.plays, id: \.persistentModelID) { play in
                    VStack(alignment: .leading) {
                        Text(play.song?.title ?? "Unknown Song")
                        Text("Count: \(play.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let play = session.plays[index]
                        context.delete(play)
                        session.plays.remove(at: index)
                    }
                    try? context.save()
                }
                Button {
                    showingAddPlaySheet = true
                } label: {
                    Label("Add a Play", systemImage: "plus")
                        .font(.body)
                        .foregroundColor(.accentColor)
                }

            }
            
        }
    }
    
    private func addPlaySheetView() -> some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingAddPlaySheet = false
                        showingAddSongSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add New Song")
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Create")
                }

                if !songs.isEmpty {
                    Section {
                        ForEach(songs, id: \.persistentModelID) { song in
                            Button(song.title) {
                                let play = Play(count: 1)
                                play.song = song
                                play.session = session
                                session.plays.append(play)
                                context.insert(play)
                                try? context.save()
                                showingAddPlaySheet = false
                            }
                        }
                    } header: {
                        Text("Existing Songs")
                    }
                }
            }
            .navigationTitle("Choose Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingAddPlaySheet = false
                    }
                }
            }
        }
    }

}

