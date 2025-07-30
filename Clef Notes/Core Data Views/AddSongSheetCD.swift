//
//  AddSongSheetCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/15/25.
//


import SwiftUI
import CoreData
import PhotosUI

struct MediaEntry: Identifiable {
    let id = UUID()
    var urlString: String = ""
    var type: MediaType = .youtubeVideo
    
    // Properties for handling local file selections
    var photoPickerItem: PhotosPickerItem? = nil
    var audioFileURL: URL? = nil
}

import SwiftUI
import CoreData

struct AddSongSheetCD: View {
    // 1. Define an enum for the focusable fields
    private enum FocusField: Hashable, CaseIterable {
        case title, composer, goalPlays
    }

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var usageManager: UsageManager

    let student: StudentCD

    // 2. Add the @FocusState property wrapper
    @FocusState private var focusedField: FocusField?

    @State private var title: String = ""
    @State private var composer: String = ""
    @State private var goalPlays: String = ""
    @State private var songStatus: PlayType? = nil
    @State private var pieceType: PieceType? = nil

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section {
                        TextField("Title", text: $title)
                            .focused($focusedField, equals: .title) // 3. Apply .focused

                        TextField("Composer (Optional)", text: $composer)
                            .focused($focusedField, equals: .composer) // 3. Apply .focused
                    } header: {
                        Text("Song Info")
                    } footer: {
                        Text("Enter the title and composer of the piece.")
                    }

                    Section {
                        Picker(selection: $pieceType) {
                            Text("None").tag(PieceType?.none)
                            ForEach(PieceType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(Optional(type))
                            }
                        } label: {
                            Label("Piece Type", systemImage: "music.note.list")
                        }

                        Picker(selection: $songStatus) {
                            Text("None").tag(PlayType?.none)
                            ForEach(PlayType.allCases, id: \.self) { status in
                                Text(status.rawValue).tag(Optional(status))
                            }
                        } label: {
                            Label("Initial Status", systemImage: "tag.fill")
                        }
                    }

                    Section {
                        TextField("Goal Plays (Optional)", text: $goalPlays)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .goalPlays) // 3. Apply .focused
                    } footer: {
                        Text("Set a target number of plays for songs with a 'Practice' status.")
                    }
                }
                // 4. Apply the new navigation modifier
                .addKeyboardNavigation(for: FocusField.allCases, focus: $focusedField)

                SaveButtonView(title: "Add Song", action: addSong, isDisabled: title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .navigationTitle("New Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func addSong() {
        let newSong = SongCD(context: viewContext)
        newSong.title = title
        newSong.composer = composer
        newSong.studentID = student.id
        newSong.student = student
        newSong.goalPlays = Int64(goalPlays) ?? 0
        newSong.songStatus = songStatus
        newSong.pieceType = pieceType
        usageManager.incrementSongCreations()

        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}
