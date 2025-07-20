import SwiftUI
import CoreData
import CloudKit

struct StudentDetailViewCD: View {
    @ObservedObject var student: StudentCD
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var audioManager: AudioManager
    
    @State private var path = NavigationPath()
    
    @State private var showingAddSongSheet = false
    @State private var showingAddSessionSheet = false
    @State private var showingEditStudentSheet = false
    
    @State private var showingSettingsSheet = false
    @State private var showingMetronome = false
    @State private var showingTuner = false
    
    @State private var isSharePresented = false
    @State private var cloudSharingController: UICloudSharingController?
    
    func populateStudentReferences() {
        // This function remains the same.
        // It ensures data integrity by checking and fixing relationships
        // between the student and their related data like songs, sessions, etc.
        if let songs = student.songs as? Set<SongCD> {
            for song in songs {
                if song.student !== student {
                    song.student = student
                }
                if !(student.songs?.contains(song) ?? false) {
                    student.addToSongs(song)
                }
            }
        }
        if let sessions = student.sessions as? Set<PracticeSessionCD> {
            for session in sessions {
                if session.student !== student {
                    session.student = student
                }
                if !(student.sessions?.contains(session) ?? false) {
                    student.addToSessions(session)
                }
            }
        }
        if let plays = student.plays as? Set<PlayCD> {
            for play in plays {
                if play.student !== student {
                    play.student = student
                }
                if !(student.plays?.contains(play) ?? false) {
                    student.mutableSetValue(forKey: "plays").add(play)
                }
            }
        }
        if let notes = student.notes as? Set<NoteCD> {
            for note in notes {
                if note.student !== student {
                    note.student = student
                }
                if !(student.notes?.contains(note) ?? false) {
                    student.mutableSetValue(forKey: "notes").add(note)
                }
            }
        }
        if let mediaRefs = student.mediaReferences as? Set<MediaReferenceCD> {
            for mediaRef in mediaRefs {
                if mediaRef.student !== student {
                    mediaRef.student = student
                }
                if !(student.mediaReferences?.contains(mediaRef) ?? false) {
                    student.mutableSetValue(forKey: "mediaReferences").add(mediaRef)
                }
            }
        }
        if let recordings = student.audioRecordings as? Set<AudioRecordingCD> {
            for recording in recordings {
                if recording.student !== student {
                    recording.student = student
                }
                if !(student.audioRecordings?.contains(recording) ?? false) {
                    student.mutableSetValue(forKey: "audioRecordings").add(recording)
                }
            }
        }
        if let instructors = student.instructors as? Set<InstructorCD> {
            for instructor in instructors {
                if let iStudent = instructor.value(forKey: "student") as? StudentCD, iStudent !== student {
                    instructor.setValue(student, forKey: "student")
                }
                if let students = instructor.value(forKey: "student") as? NSSet, !students.contains(student) {
                    instructor.mutableSetValue(forKey: "student").add(student)
                }
                if !(student.instructors?.contains(instructor) ?? false) {
                    student.mutableSetValue(forKey: "instructors").add(instructor)
                }
            }
        }
        do {
            try viewContext.save()
        } catch {
            print("Failed to save context after populating student references: \(error)")
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            TabView {
                SessionListViewCD(student: student) {
                    showingAddSessionSheet = true
                }
                .tabItem {
                    Label("Sessions", systemImage: "calendar")
                }
                
                StudentSongsTabViewCD(student: student) {
                    showingAddSongSheet = true
                }
                .tabItem { Label("Songs", systemImage: "music.note.list") }

                StatsTabViewCD(student: student)
                    .tabItem { Label("Stats", systemImage: "chart.bar") }
            }
            .navigationTitle(student.name ?? "Student")
            .navigationBarTitleDisplayMode(.large)
            // --- THIS IS THE FIX: The toolbar is re-organized ---
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // "Add Song" and "Add Session" are now top-level buttons
                    Button {
                        showingAddSongSheet = true
                    } label: {
                        Label("Add Song", image: "add.song")
                    }
                    
                    Button {
                        showingAddSessionSheet = true
                    } label: {
                        Label("Add Session", systemImage: "calendar.badge.plus")
                    }
                    
                    // The remaining actions are in the "More" menu
                    Menu {
                        Section("Student Actions") {
                            Button {
                                showingEditStudentSheet = true
                            } label: {
                                Label("Edit Student", systemImage: "pencil")
                            }
                            
                            Button {
                                isSharePresented = true
                            } label: {
                                Label("Share Student", systemImage: "square.and.arrow.up")
                            }
                        }
                        
                        Section("Tools") {
                            Button {
                                showingMetronome = true
                            } label: {
                                Label("Metronome", systemImage: "metronome")
                            }
                            
                            Button {
                                showingTuner = true
                            } label: {
                                Label("Tuner", systemImage: "tuningfork")
                            }
                            
                            Divider()
                            
                            Button {
                                showingSettingsSheet = true
                            } label: {
                                Label("Settings", systemImage: "gearshape")
                            }
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .withGlobalTools(
                showingSettings: $showingSettingsSheet,
                showingMetronome: $showingMetronome,
                showingTuner: $showingTuner
            )
            .navigationDestination(for: PracticeSessionCD.self) { session in
                SessionDetailViewCD(session: session, audioManager: audioManager)
            }
            .navigationDestination(for: SongCD.self) { song in
                SongDetailViewCD(song: song, audioManager: audioManager)
            }
        }
        .sheet(isPresented: $showingAddSessionSheet) {
            AddSessionSheetCD(student: student) { session in
                path.append(session)
            }
        }
        .sheet(isPresented: $showingAddSongSheet) {
            AddSongSheetCD(student: student)
        }
        .sheet(isPresented: $showingEditStudentSheet) {
            EditStudentSheetCD(student: student)
        }
        .sheet(isPresented: $isSharePresented) {
            CloudSharingView(student: student)
        }
    }
}
