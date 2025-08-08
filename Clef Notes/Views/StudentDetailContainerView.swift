import SwiftUI
import CoreData

// (Your StudentDetailSection enum remains the same)
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
        case .songs: "music.note"
        case .stats: "chart.bar"
        case .awards: "rosette"
        case .notes: "note.text"
        }
    }
}


struct StudentDetailNavigationView: View {
    @ObservedObject var student: StudentCD
    @Binding var showingSideMenu: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @State private var selectedSection: StudentDetailSection = .sessions
    @State private var showingAddSongSheet = false
    @State private var showingAddSessionSheet = false
    @State private var showingEditStudentSheet = false
    @State private var isSharePresented = false
    @State private var showingPaywall = false
    @State private var triggerAddNote = false

    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            if #available(iOS 18.0, *) {
                VStack {
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
                .navigationTitle(student.name ?? "Student")
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        Button(action: {
                            showingSideMenu = true
                        }) {
                            Label("Menu", systemImage: "line.3.horizontal")
                        }
                    }
                    // ... (The rest of your toolbar remains the same)
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
                                Label("Add Note", systemImage: "note.text.badge.plus")
                            }
                        }
                    }
                }
                
                .sheet(isPresented: $showingAddSessionSheet) { AddSessionSheetCD(student: student) { session in path.append(session) } }
                .sheet(isPresented: $showingAddSongSheet) { AddSongSheetCD(student: student) }
                .sheet(isPresented: $showingEditStudentSheet) { EditStudentSheetCD(student: student) }
                .sheet(isPresented: $isSharePresented) { CloudSharingView(student: student) }
                .sheet(isPresented: $showingPaywall) {
                    PaywallView()
                }
                .presentationSizing(.page)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        TimerBarView()
                        BottomNavBar(selectedSection: $selectedSection)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            } else {
                VStack {
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
                .navigationTitle(student.name ?? "Student")
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        Button(action: {
                            showingSideMenu = true
                        }) {
                            Label("Menu", systemImage: "line.3.horizontal")
                        }
                    }
                    // ... (The rest of your toolbar remains the same)
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
                                Label("Add Note", systemImage: "note.text.badge.plus")
                            }
                        }
                    }
                }
                
                .sheet(isPresented: $showingAddSessionSheet) { AddSessionSheetCD(student: student) { session in path.append(session) } }
                .sheet(isPresented: $showingAddSongSheet) { AddSongSheetCD(student: student) }
                .sheet(isPresented: $showingEditStudentSheet) { EditStudentSheetCD(student: student) }
                .sheet(isPresented: $isSharePresented) { CloudSharingView(student: student) }
                .sheet(isPresented: $showingPaywall) {
                    PaywallView()
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        TimerBarView()
                        BottomNavBar(selectedSection: $selectedSection)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

// ... (Your BottomNavBar and FloatingBottomNavBar structs remain the same)
struct BottomNavBar: View {
    @Binding var selectedSection: StudentDetailSection
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
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
                                .font(.system(size: 10))
                        }
                        .foregroundColor(selectedSection == section ? .accentColor : .gray)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.top, 5)
            .padding(.bottom, 35)
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
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
