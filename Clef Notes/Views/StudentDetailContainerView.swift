import SwiftUI
import CoreData

// Enum to represent the different sections in the student detail view.
enum StudentDetailSection: String, CaseIterable, Identifiable {
    case sessions = "Sessions"
    case songs = "Songs"
    case stats = "Stats"
    case awards = "Awards"
    case notes = "Notes"

    var id: String { self.rawValue }

    var systemImageName: String {
        switch self {
        case .sessions: "calendar"
        case .songs: "music.note.list"
        case .stats: "chart.bar"
        case .awards: "rosette"
        case .notes: "note.text"
        }
    }
}

struct StudentDetailNavigationView: View {
    @ObservedObject var student: StudentCD
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @State private var selectedSection: StudentDetailSection = .sessions
    @State private var showingAddSongSheet = false
    @State private var showingAddSessionSheet = false
    @State private var showingEditStudentSheet = false
    @State private var isSharePresented = false
    @State private var showingSideMenu = false
    @State private var showingPaywall = false
    @State private var triggerAddNote = false

    @State private var path = NavigationPath()


    var body: some View {
        VStack {
            // Content view based on the selected section
            switch selectedSection {
            case .sessions:
                SessionListViewCD(student: student) {
                    showingAddSessionSheet = true
                }
            case .songs:
                StudentSongsTabViewCD(student: student) {
                    showingAddSongSheet = true
                }
            case .stats:
                StatsTabViewCD(student: student)
            case .awards:
                AwardsView(student: student, context: viewContext)
            case .notes:
                StudentNotesView(student: student, triggerAddNote: $triggerAddNote)
            }
        }
        .navigationTitle(selectedSection.rawValue)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if selectedSection == .sessions || selectedSection == .songs {
                    Button {
                        if subscriptionManager.isAllowedToCreateSong() {
                            showingAddSongSheet = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Label("Add Song", image: "add.song")
                    }
                    Button {
                        if subscriptionManager.isAllowedToCreateSession() {
                            showingAddSessionSheet = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Label("Add Session", systemImage: "calendar.badge.plus")
                    }
                } else if selectedSection == .notes {
                    Button(action: { triggerAddNote = true }) {
                        Label("Add Note", systemImage: "plus")
                    }
                }

                Button(action: {
                    showingSideMenu = true
                }) {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddSessionSheet) { AddSessionSheetCD(student: student) { session in path.append(session) } }
        .sheet(isPresented: $showingAddSongSheet) { AddSongSheetCD(student: student) }
        .sheet(isPresented: $showingEditStudentSheet) { EditStudentSheetCD(student: student) }
        .sheet(isPresented: $isSharePresented) { CloudSharingView(student: student) }
        .sheet(isPresented: $showingSideMenu) {
            SideMenuView(
                student: student,
                isPresented: $showingSideMenu,
                showingEditStudentSheet: $showingEditStudentSheet,
                isSharePresented: $isSharePresented
            )
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                TimerBarView()
                
                if #available(iOS 26.0, *) {
                    FloatingBottomNavBar(selectedSection: $selectedSection)
                } else {
                    BottomNavBar(selectedSection: $selectedSection)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct BottomNavBar: View {
    @Binding var selectedSection: StudentDetailSection
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if #available(iOS 26.0, *) {
            HStack {
                ForEach(StudentDetailSection.allCases) { section in
                    Button(action: {
                        withAnimation {
                            selectedSection = section
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: section.systemImageName)
                                .font(.system(size: 22))
                            Text(section.rawValue)
                                .font(.caption2)
                        }
                        .foregroundColor(selectedSection == section ? .accentColor : .gray)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 30)
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: -5)
            .glassEffect()
        } else {
            HStack {
                ForEach(StudentDetailSection.allCases) { section in
                    Button(action: {
                        withAnimation {
                            selectedSection = section
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: section.systemImageName)
                                .font(.system(size: 22))
                            Text(section.rawValue)
                                .font(.caption2)
                        }
                        .foregroundColor(selectedSection == section ? .accentColor : .gray)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 30)
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: -5)
        }
    }
}

struct FloatingBottomNavBar: View {
    @Binding var selectedSection: StudentDetailSection

    var body: some View {
        HStack {
            ForEach(StudentDetailSection.allCases) { section in
                Button(action: {
                    withAnimation(.spring()) {
                        selectedSection = section
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: section.systemImageName)
                            .font(.system(size: 22))
                        Text(section.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedSection == section ? .accentColor : .gray)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(
            Capsule()
                .fill(Material.bar)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
