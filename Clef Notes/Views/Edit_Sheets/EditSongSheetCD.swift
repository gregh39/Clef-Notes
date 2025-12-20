import SwiftUI
import CoreData
import PhotosUI

struct EditSongSheetCD: View {
    // 1. Define an enum for your focusable fields
    private enum FocusField: Hashable, CaseIterable {
        case title, composer, goalPlays
    }
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var song: SongCD
    
    @FetchRequest(entity: CollectionCD.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \CollectionCD.name, ascending: true)]) var collections: FetchedResults<CollectionCD>
    @State private var archived: Bool = false
    @State private var selectedCollection: CollectionCD? = nil

    // 2. Add the @FocusState property wrapper
    @FocusState private var focusedField: FocusField?

    @State private var title: String = ""
    @State private var composer: String = ""
    @State private var songStatus: PlayType?
    @State private var pieceType: PieceType?
    @State private var goalPlays: String = ""
    @State private var selectedSuzukiBook: SuzukiBook? = nil
    
    // Image selection properties
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var imageData: Data?

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
                                if let imageData = imageData, let uiImage = UIImage(data: imageData) {
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
                                PhotosPicker("Change Image", selection: $selectedImageItem, matching: .images)
                                    .buttonStyle(.bordered)
                            }
                            Spacer()
                        }
                        .padding(.vertical)
                    }
                    
                    Section {
                        TextField("Title", text: $title)
                            .focused($focusedField, equals: .title) // 3. Apply .focused
                        
                        TextField("Composer", text: $composer)
                            .focused($focusedField, equals: .composer) // 3. Apply .focused
                    } header: {
                        Text("Song Details")
                    }

                    Section {
                        Picker(selection: $pieceType) {
                            Text("None").tag(PieceType?.none)
                            ForEach(PieceType.allCases, id: \.self) { type in
                                Text(type.rawValue.capitalized).tag(PieceType?(type))
                            }
                        } label: {
                            Label("Piece Type", systemImage: "music.note.list")
                        }
                        
                        Picker(selection: $songStatus) {
                            Text("None").tag(PlayType?.none)
                            ForEach(PlayType.allCases, id: \.self) { status in
                                Text(status.rawValue.capitalized).tag(PlayType?(status))
                            }
                        } label: {
                            Label("Status", systemImage: "tag.fill")
                        }
                    }
                    
                    if song.student?.suzukiStudent?.boolValue ?? false {
                        Section("Suzuki") {
                            Picker("Suzuki Book", selection: $selectedSuzukiBook) {
                                Text("Select a Book").tag(Optional<SuzukiBook>.none)
                                ForEach(SuzukiBook.allCases) { book in
                                    Text(book.rawValue).tag(Optional(book))
                                }
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
                    
                    Section("Practice Goals") {
                        TextField("Goal Plays", text: $goalPlays)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .goalPlays) // 3. Apply .focused
                    }
                }
                // 4. Apply the new navigation modifier
                .addKeyboardNavigation(for: FocusField.allCases, focus: $focusedField)
                .onChange(of: selectedImageItem) {
                    Task {
                        if let data = try? await selectedImageItem?.loadTransferable(type: Data.self) {
                            imageData = data
                        }
                    }
                }
                
                SaveButtonView(title: "Save", action: saveChanges, isDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("Edit Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                title = song.title ?? ""
                composer = song.composer ?? ""
                songStatus = song.songStatus
                pieceType = song.pieceType
                goalPlays = "\(song.goalPlays)"
                selectedSuzukiBook = song.suzukiBook
                imageData = song.image
                
                archived = song.value(forKey: "archived") as? Bool ?? false
                selectedCollection = song.collection
            }
            .sheet(isPresented: $showingAddCollectionSheet) {
                addCollectionSheet
            }
        }
    }

    private func saveChanges() {
        song.title = title
        song.composer = composer
        song.songStatus = songStatus
        song.pieceType = pieceType
        song.suzukiBook = selectedSuzukiBook
        song.goalPlays = Int64(goalPlays) ?? 0
        song.image = imageData
        
        song.setValue(archived, forKey: "archived")
        song.collection = selectedCollection
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save song changes: \(error)")
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
