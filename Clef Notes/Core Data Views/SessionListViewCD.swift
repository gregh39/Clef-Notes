import SwiftUI
import CoreData

struct SessionListViewCD: View {
    @Binding var student: StudentCD
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showingPaywall = false
    
    @State private var showingAddSongSheet = false
    @State private var showingAddSessionSheet = false
    @State private var showingEditStudentSheet = false
    
    @State private var isSharePresented = false
    @State private var showingSideMenu = false
    
    @State private var selectedTab: Int = 0
    @State private var triggerAddNote = false

    @State private var path = NavigationPath()

    var onAddSession: () -> Void

    @State private var sessionToDelete: PracticeSessionCD? = nil

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
                } else {
                    List {
                        ForEach(student.sessionsArray) { session in
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
            .withGlobalToolbar(
                selectedTab: $selectedTab,
                showingAddSongSheet: $showingAddSongSheet,
                showingAddSessionSheet: $showingAddSessionSheet,
                showingPaywall: $showingPaywall,
                triggerAddNote: $triggerAddNote,
                showingSideMenu: $showingSideMenu
            )

            .navigationTitle("Sessions")
            .navigationDestination(for: PracticeSessionCD.self) { session in
                SessionDetailViewCD(session: session, audioManager: audioManager)
            }
            .sheet(isPresented: $showingAddSessionSheet) { AddSessionSheetCD(student: student) { _ in } }
            .sheet(isPresented: $showingAddSongSheet) { AddSongSheetCD(student: student) }
            .sheet(isPresented: $showingSideMenu) {
                SideMenuView(
                    student: $student,
                    isPresented: $showingSideMenu,
                    showingEditStudentSheet: $showingEditStudentSheet,
                    isSharePresented: $isSharePresented
                )
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }


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
                        //Label("\(totalPlays)", systemImage: "music.note.list")
                          //  .foregroundStyle(.blue)
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
