import SwiftUI
import CoreData

struct SessionListViewCD: View {
    @ObservedObject var student: StudentCD
    @EnvironmentObject var audioManager: AudioManager
    @State private var path = NavigationPath()

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
        NavigationStack(path: $path) {
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
                }
            }
            .navigationTitle("Sessions")
            .navigationDestination(for: PracticeSessionCD.self) { session in
                SessionDetailViewCD(session: session, audioManager: audioManager)
            }
            .searchable(text: $searchText, prompt: "Search Sessions")
        }
    }
    
    private func deleteSession(_ session: PracticeSessionCD) {
        guard let context = session.managedObjectContext else { return }
        context.delete(session)
        do {
            try context.save()
        } catch {
            print("Error deleting session: \(error)")
        }
        sessionToDelete = nil
    }
}

struct SessionCardViewCD: View {
    @ObservedObject var session: PracticeSessionCD
    
    private var totalPlays: Int {
        session.playsArray.reduce(0) { $0 + Int($1.count) }
    }
    private var noteCount: Int {
        session.notesArray.count
    }
    private var recordingCount: Int {
        session.recordingsArray.count
    }
    private var durationString: String {
        let totalMinutes = session.durationMinutes
        guard totalMinutes > 0 else { return "" }
        let hours = Int(totalMinutes) / 60
        let minutes = Int(totalMinutes) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.title ?? "Practice").font(.headline).fontWeight(.bold)
                Spacer()
                Text((session.day ?? .now).formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                if let location = session.location {
                    HStack{
                        Image(systemName: "mappin.and.ellipse")
                        Text(location.rawValue)
                    }
                }
                Spacer()
                if let instructor = session.instructor {
                    HStack{
                        Image(systemName: "person.fill")
                        Text(instructor.name ?? "Unknown")
                    }
                }
            }
            .font(.subheadline).foregroundColor(.secondary)
            
            if totalPlays > 0 || noteCount > 0 || recordingCount > 0 || session.durationMinutes > 0 {
                Divider()
                HStack(spacing: 16) {
                    if totalPlays > 0 {
                        HStack{
                            Image(systemName: "music.note.list")
                            Text("\(totalPlays)")
                        }
                        .foregroundStyle(.blue)
                    }
                    if noteCount > 0 {
                        HStack{
                            Image(systemName: "note.text")
                            Text("\(noteCount)")
                        }
                        .foregroundStyle(.orange)
                    }
                    if recordingCount > 0 {
                        HStack{
                            Image(systemName: "mic.fill")
                            Text("\(recordingCount)")
                        }
                        .foregroundStyle(.red)
                    }
                    Spacer()
                    if session.durationMinutes > 0 {
                        HStack{
                            Image(systemName: "clock.fill")
                            Text("\(durationString)")
                        }
                        .foregroundStyle(.purple)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
