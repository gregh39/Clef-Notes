import SwiftUI
import CoreData

/// A student's song collections, with swipe to delete. Deleting a collection keeps its songs;
/// the relationship's Nullify rule just clears each song's `collection`.
struct CollectionsListView: View {
    @ObservedObject var student: StudentCD
    @Environment(\.managedObjectContext) private var viewContext

    /// The student's collections, plus older collections with no student (from before model v5)
    /// that hold this student's songs, so they can still be cleaned up.
    @FetchRequest private var collections: FetchedResults<CollectionCD>

    @State private var collectionToDelete: CollectionCD?

    init(student: StudentCD) {
        self.student = student
        _collections = FetchRequest<CollectionCD>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CollectionCD.name, ascending: true)],
            predicate: NSPredicate(format: "student == %@ OR (student == nil AND ANY songs.student == %@)", student, student)
        )
    }

    private var ownedCollections: [CollectionCD] {
        collections.filter { $0.student != nil }
    }

    private var legacyCollections: [CollectionCD] {
        collections.filter { $0.student == nil }
    }

    var body: some View {
        Group {
            if collections.isEmpty {
                ContentUnavailableView {
                    Label("No Collections Yet", systemImage: "rectangle.stack")
                } description: {
                    Text("Add a collection when you add or edit a song.")
                }
            } else {
                List {
                    if !ownedCollections.isEmpty {
                        Section {
                            ForEach(ownedCollections) { collection in
                                row(for: collection)
                            }
                        } footer: {
                            Text("Swipe to delete a collection. Its songs are kept. They just won't be in a collection anymore.")
                        }
                    }

                    if !legacyCollections.isEmpty {
                        Section {
                            ForEach(legacyCollections) { collection in
                                row(for: collection)
                            }
                        } header: {
                            Text("Older Collections")
                        } footer: {
                            Text("Created before collections belonged to a student, and shared with other students' songs. They can't be picked for new songs.")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Collections")
        .confirmationDialog(
            "Delete “\(collectionToDelete?.name ?? "Unnamed")”?",
            isPresented: Binding(get: { collectionToDelete != nil }, set: { if !$0 { collectionToDelete = nil } }),
            titleVisibility: .visible,
            presenting: collectionToDelete
        ) { collection in
            Button("Delete Collection", role: .destructive) {
                delete(collection)
            }
            Button("Cancel", role: .cancel) {}
        } message: { collection in
            let count = collection.songs?.count ?? 0
            Text(count == 0
                 ? "This collection has no songs."
                 : "\(count) song(s) will be kept and removed from this collection.")
        }
    }

    private func row(for collection: CollectionCD) -> some View {
        CollectionRow(collection: collection)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    collectionToDelete = collection
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
    }

    private func delete(_ collection: CollectionCD) {
        viewContext.delete(collection)
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete collection: \(error)")
            viewContext.rollback()
        }
    }
}

private struct CollectionRow: View {
    @ObservedObject var collection: CollectionCD

    private var songCount: Int {
        collection.songs?.count ?? 0
    }

    var body: some View {
        HStack {
            Image(systemName: "rectangle.stack.fill")
                .font(.title)
                .foregroundColor(.accentColor)
                .frame(width: 40)
            VStack(alignment: .leading) {
                Text(collection.name ?? "Unnamed")
                    .font(.headline)
                Text(songCount == 0 ? "No songs" : "\(songCount) song(s)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
