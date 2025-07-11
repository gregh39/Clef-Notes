//
//  AddSongSheet.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/13/25.
//
import SwiftUI
import SwiftData

struct AddSongSheet: View {
    @Binding var isPresented: Bool
    @Binding var title: String
    @Binding var goalPlays: String
    @Binding var currentPlays: String
    @Binding var youtubeLink: String
    @Binding var appleMusicLink: String
    @Binding var spotifyLink: String
    @Binding var localFileLink: String
    @Binding var songStatus: PlayType?
    @Binding var pieceType: PieceType?
    var addAction: () -> Void
    var clearAction: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Song Info") {
                    TextField("Title", text: $title)
                    TextField("Goal Plays", text: $goalPlays)
                        .keyboardType(.numberPad)
                    TextField("Current Plays", text: $currentPlays)
                        .keyboardType(.numberPad)
                    Picker("Piece Type", selection: $pieceType) {
                        Text("None").tag(PieceType?.none)
                        ForEach(PieceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(Optional(type))
                        }
                    }
                    Picker("Status", selection: $songStatus) {
                        Text("None").tag(Optional<PlayType>(nil))
                        ForEach(PlayType.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(Optional(status))
                        }
                    }
                }

                Section("Links") {
                    TextField("YouTube", text: $youtubeLink)
                    TextField("Apple Music", text: $appleMusicLink)
                    TextField("Spotify", text: $spotifyLink)
                    TextField("Local File", text: $localFileLink)
                }
            }
            .navigationTitle("New Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                        clearAction()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAction()
                        isPresented = false
                        clearAction()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

