import SwiftUI
import CoreData
import TelemetryDeck

struct SessionListViewCD: View {
    @ObservedObject var student: StudentCD
    @EnvironmentObject var audioManager: AudioManager
    @State private var path = NavigationPath()
    @State private var sessionToEdit: PracticeSessionCD? = nil

    var onAddSession: () -> Void

    @State private var sessionToDelete: PracticeSessionCD? = nil
    @State private var searchText = ""
    

    private var filteredSessions: [PracticeSessionCD] {
        if searchText.isEmpty {
            return student.sessionsArray
        } else {
            return student.sessionsArray.filter { session in
                let searchTextLowercased = searchText.lowercased()

                // Check session title
                if let title = session.title, title.lowercased().contains(searchTextLowercased) {
                    return true
                }
                // Check instructor name
                if let instructor = session.instructor?.name, instructor.lowercased().contains(searchTextLowercased) {
                    return true
                }
                // Check location
                if let location = session.location?.rawValue, location.lowercased().contains(searchTextLowercased) {
                    return true
                }
                // Check songs played in the session
                for play in session.playsArray {
                    if let songTitle = play.song?.title, songTitle.lowercased().contains(searchTextLowercased) {
                        return true
                    }
                }
                return false
            }
        }
    }

    var body: some View {
            Group {
                if student.sessionsArray.isEmpty {
                    ContentUnavailableView {
                        Label("No Sessions Yet", systemImage: "calendar.badge.plus")
                    } description: {
                        Text("Tap the button to log your first practice session.")
                    } actions: {
                        Button("Add First Session", action: onAddSession)
                            .buttonStyle(.borderedProminent)
                    }
                } else if filteredSessions.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(filteredSessions) { session in
                            Section {
                                ZStack {
                                    SessionCardViewCD(session: session)
                                    NavigationLink(value: session) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        sessionToDelete = session
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        sessionToEdit = session
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .alert("Delete Session?", isPresented: Binding(get: { sessionToDelete != nil }, set: { if !$0 { sessionToDelete = nil } }), presenting: sessionToDelete) { session in
                        Button("Delete", role: .destructive) { deleteSession(session) }
                        Button("Cancel", role: .cancel) {}
                    } message: { _ in
                        Text("Are you sure you want to delete this session? All associated plays, notes, and recordings will also be permanently deleted.")
                    }
                    .sheet(item: $sessionToEdit) { session in
                        EditSessionSheetCD(session: session)
                    }
                }
            }
            .navigationTitle("Sessions")
            .navigationDestination(for: PracticeSessionCD.self) { session in
                SessionDetailViewCD(session: session, audioManager: audioManager)
            }
            .searchable(text: $searchText, prompt: "Search Sessions")
        
    }
    
    private func deleteSession(_ session: PracticeSessionCD) {
        guard let context = session.managedObjectContext else { return }
        context.delete(session)
        do {
            try context.save()
            TelemetryDeck.signal("session_deleted")
        } catch {
            print("Error deleting session: \(error)")
            TelemetryDeck.signal("session_delete_failed")
        }
        sessionToDelete = nil
    }
}

