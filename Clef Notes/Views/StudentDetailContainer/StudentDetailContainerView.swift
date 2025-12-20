import SwiftUI
import CoreData

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
    @State private var selectedTab: Int = 0

    var titleForSelectedSection: String {
        switch selectedTab {
        case 0: return "Sessions"
        case 1: return "Songs"
        case 2: return "Stats"
        case 3: return "Awards"
        case 4: return "Notes"
        default: return ""
        }
    }

    @State private var sessionsPath = NavigationPath()
    @State private var songsPath = NavigationPath()
    @State private var statsPath = NavigationPath()
    @State private var awardsPath = NavigationPath()
    @State private var notesPath = NavigationPath()

    // Helper function to get navigation title based on selected tab
    private func getNavigationTitle(for tab: Int) -> String {
        switch tab {
        case 0:
            return "Practice Sessions"
        case 1:
            return "Songs"
        case 2:
            return "Stats"
        case 3:
            return "Awards"
        case 4:
            return "Notes"
        default:
            return "Practice Sessions"
        }
    }
    
    let sample: [Int] = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
    
    var body: some View {
            if #available(iOS 26.0, *) {
                TabView(selection: $selectedTab) {
                    // SESSIONS
                    NavigationStack(path: $sessionsPath) {
                        SessionListViewCD(student: student) {
                            showingAddSessionSheet = true
                        }
                        .navigationTitle("Sessions")
                        .navigationBarTitleDisplayMode(.large)
                        .navigationDestination(for: PracticeSessionCD.self) { session in
                            SessionDetailViewCD(session: session, audioManager: audioManager)
                        }
                        .toolbar {
                            CommonToolbar(
                                context: .sessions,
                                onMenu: { showingSideMenu = true },
                                onAddSong: { showingAddSongSheet = true },
                                onAddSession: { showingAddSessionSheet = true },
                                onAddNote: { triggerAddNote = true },
                                canCreateSong: { subscriptionManager.isAllowedToCreateSong() },
                                canCreateSession: { subscriptionManager.isAllowedToCreateSession() },
                                showPaywall: { showingPaywall = true }
                            )
                        }
                    }
                    .tabItem { Label("Sessions", systemImage: "person.crop.circle") }
                    .tag(0)

                    // SONGS
                    NavigationStack(path: $songsPath) {
                        StudentSongsTabViewCD(student: student) {
                            showingAddSongSheet = true
                        }
                        .navigationTitle("Songs")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            CommonToolbar(
                                context: .songs,
                                onMenu: { showingSideMenu = true },
                                onAddSong: { showingAddSongSheet = true },
                                onAddSession: { showingAddSessionSheet = true },
                                onAddNote: { triggerAddNote = true },
                                canCreateSong: { subscriptionManager.isAllowedToCreateSong() },
                                canCreateSession: { subscriptionManager.isAllowedToCreateSession() },
                                showPaywall: { showingPaywall = true }
                            )
                        }
                    }
                    .tabItem { Label("Songs", systemImage: "music.note") }
                    .tag(1)

                    // STATS
                    NavigationStack(path: $statsPath) {
                        StatsTabViewCD(student: student)
                            .navigationTitle("Stats")
                            .navigationBarTitleDisplayMode(.large)
                            .toolbar {
                                CommonToolbar(
                                    context: .stats,
                                    onMenu: { showingSideMenu = true },
                                    onAddSong: {},
                                    onAddSession: {},
                                    onAddNote: {},
                                    canCreateSong: { false },
                                    canCreateSession: { false },
                                    showPaywall: {}
                                )
                            }
                    }
                    .tabItem { Label("Stats", systemImage: "barometer") }
                    .tag(2)

                    // AWARDS
                    NavigationStack(path: $awardsPath) {
                        AwardsView(student: student, context: viewContext)
                            .navigationTitle("Awards")
                            .navigationBarTitleDisplayMode(.large)
                            .toolbar {
                                CommonToolbar(
                                    context: .awards,
                                    onMenu: { showingSideMenu = true },
                                    onAddSong: {},
                                    onAddSession: {},
                                    onAddNote: {},
                                    canCreateSong: { false },
                                    canCreateSession: { false },
                                    showPaywall: {}
                                )
                            }
                    }
                    .tabItem { Label("Awards", systemImage: "trophy") }
                    .tag(3)

                    // NOTES
                    NavigationStack(path: $notesPath) {
                        StudentNotesView(student: student, triggerAddNote: $triggerAddNote)
                            .navigationTitle("Notes")
                            .navigationBarTitleDisplayMode(.large)
                            .toolbar {
                                CommonToolbar(
                                    context: .notes,
                                    onMenu: { showingSideMenu = true },
                                    onAddSong: {},
                                    onAddSession: {},
                                    onAddNote: { triggerAddNote = true },
                                    canCreateSong: { false },
                                    canCreateSession: { false },
                                    showPaywall: {}
                                )
                            }
                    }
                    .tabItem { Label("Notes", systemImage: "note.text") }
                    .tag(4)
                }
                // Shared sheets
                .sheet(isPresented: $showingAddSessionSheet) {
                    AddSessionSheetCD(student: student) { session in
                        sessionsPath.append(session)
                    }
                }
                .sheet(isPresented: $showingAddSongSheet) { AddSongSheetCD(student: student) }
                .sheet(isPresented: $showingEditStudentSheet) { EditStudentSheetCD(student: student) }
                .sheet(isPresented: $isSharePresented) { CloudSharingView(student: student) }
                .sheet(isPresented: $showingPaywall) { PaywallView() }
                .presentationSizing(.page)
                //.safeAreaInset(edge: .bottom) { VStack(spacing: 0) { TimerBarView() } }
                .ignoresSafeArea(edges: .bottom)
            } else if #available(iOS 18.0, *) {
                NavigationStack(path: $path) {
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
                    .navigationDestination(for: PracticeSessionCD.self) { session in
                        SessionDetailViewCD(session: session, audioManager: audioManager)
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
                }
            } else {
                NavigationStack(path: $path) {
                    
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

