import SwiftUI
import CoreData
import CloudKit

struct StudentDetailViewCD: View {
    @ObservedObject var student: StudentCD
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager
    
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showingPaywall = false
    
    @State private var path = NavigationPath()
    
    @State private var showingAddSongSheet = false
    @State private var showingAddSessionSheet = false
    @State private var showingEditStudentSheet = false
    
    @State private var isSharePresented = false
    @State private var showingSideMenu = false
    
    @State private var selectedTab: Int = 0
    @State private var triggerAddNote = false

    private var navigationTitle: String {
        switch selectedTab {
            case 0: return "Sessions"
            case 1: return "Songs"
            case 2: return "Stats"
            case 3: return "Awards" // Add this case
            case 4: return "All Notes" // Update this to 4
            default: return student.name ?? "Student"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
                TabView(selection: $selectedTab) {
                    SessionListViewCD(student: student) {
                        showingAddSessionSheet = true
                    }
                    .tabItem { Label("Sessions", systemImage: "calendar") }
                    .tag(0)
                    
                    StudentSongsTabViewCD(student: student) {
                        showingAddSongSheet = true
                    }
                    .tabItem { Label("Songs", systemImage: "music.note.list") }
                    .tag(1)

                    StatsTabViewCD(student: student)
                        .tabItem { Label("Stats", systemImage: "chart.bar") }
                        .tag(2)

                    // Add the new AwardsView tab
                    AwardsView(student: student, context: viewContext)
                        .tabItem { Label("Awards", systemImage: "rosette") }
                        .tag(3)
                    
                    StudentNotesView(student: student, triggerAddNote: $triggerAddNote)
                        .tabItem { Label("Notes", systemImage: "note.text") }
                        .tag(4) // Update this tag to 4
                }
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        if selectedTab <= 1 {
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
                        } else if selectedTab == 3 {
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
            
            TimerBarView()
        }
    }
    
}

struct TimerBarView: View {
    @EnvironmentObject var sessionTimerManager: SessionTimerManager
    @AppStorage("selectedAccentColor") private var accentColor: AccentColor = .blue

    var body: some View {
        if let session = sessionTimerManager.activeSession {
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text(session.title ?? "Practice Session")
                        .font(.headline)
                        .lineLimit(1)
                    Text(sessionTimerManager.elapsedTimeString)
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    if sessionTimerManager.isPaused {
                        sessionTimerManager.resume()
                    } else {
                        sessionTimerManager.pause()
                    }
                } label: {
                    Image(systemName: sessionTimerManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(accentColor.color.opacity(0.2))
                        .foregroundColor(accentColor.color)
                        .cornerRadius(10)
                }
                
                Button {
                    sessionTimerManager.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                }
            }
            .padding()
            .background(.bar)
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(), value: sessionTimerManager.activeSession)
        }
    }
}
