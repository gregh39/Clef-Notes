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
    @State private var selectedSuzukiBook: SuzukiBook? = nil
    
    // Image selection properties
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    
    @FetchRequest(entity: CollectionCD.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \CollectionCD.name, ascending: true)]) var collections: FetchedResults<CollectionCD>
    
    @State private var archived: Bool = false
    @State private var selectedCollection: CollectionCD? = nil

    @State private var showingAddCollectionSheet = false
    @State private var newCollectionName = ""

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section("Song Image") {
                        HStack {
                            Spacer()
                            VStack {
                                if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                        .frame(width: 100, height: 100)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                PhotosPicker("Choose Image", selection: $selectedImageItem, matching: .images)
                                    .buttonStyle(.bordered)
                            }
                            Spacer()
                        }
                        .padding(.vertical)
                    }
                    
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
                    
                    if student.suzukiStudent?.boolValue ?? false {
                        Section("Suzuki") {
                            Picker("Suzuki Book", selection: $selectedSuzukiBook) {
                                Text("Select a Book").tag(Optional<SuzukiBook>.none)
                                ForEach(SuzukiBook.allCases) { book in
                                    Text(book.rawValue).tag(Optional(book))
                                }
                            }
                        }
                        Section("Song Options") {
                            Toggle("Archived", isOn: $archived)
                            Picker("Collection Tag", selection: $selectedCollection) {
                                Text("None").tag(Optional<CollectionCD>(nil))
                                ForEach(collections, id: \.self) { collection in
                                    Text(collection.name ?? "Unnamed").tag(Optional(collection))
                                }
                            }
                            Button("Add New Collection") { showingAddCollectionSheet = true }
                        }
                    } else {
                        Section("Song Options") {
                            Toggle("Archived", isOn: $archived)
                            Picker("Collection Tag", selection: $selectedCollection) {
                                Text("None").tag(Optional<CollectionCD>(nil))
                                ForEach(collections, id: \.self) { collection in
                                    Text(collection.name ?? "Unnamed").tag(Optional(collection))
                                }
                            }
                            Button("Add New Collection") { showingAddCollectionSheet = true }
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
                .onChange(of: selectedImageItem) {
                    Task {
                        if let data = try? await selectedImageItem?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                        }
                    }
                }

                SaveButtonView(title: "Add Song", action: addSong, isDisabled: title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .navigationTitle("New Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingAddCollectionSheet) {
            addCollectionSheet
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
        newSong.suzukiBook = selectedSuzukiBook
        newSong.image = selectedImageData

        newSong.setValue(archived, forKey: "archived")
        newSong.collection = selectedCollection
        
        usageManager.incrementSongCreations()

        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    private var addCollectionSheet: some View {
        NavigationStack {
            VStack {
                Form {
                    TextField("Collection Name", text: $newCollectionName)
                }
                SaveButtonView(title: "Add Collection", action: {
                    let newCollection = CollectionCD(context: viewContext)
                    newCollection.name = newCollectionName
                    try? viewContext.save()
                    selectedCollection = newCollection
                    showingAddCollectionSheet = false
                    newCollectionName = ""
                }, isDisabled: newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("New Collection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddCollectionSheet = false
                        newCollectionName = ""
                    }
                }
            }
        }
    }
}

