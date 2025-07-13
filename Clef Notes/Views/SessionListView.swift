import SwiftUI
import Foundation
import SwiftData

struct SessionListView: View {
    @Binding var viewModel: StudentDetailViewModel
    @EnvironmentObject var audioManager: AudioManager

    // --- NEW STATE ---
    // 1. To track which session is targeted for deletion.
    @State private var sessionToDelete: PracticeSession?
    // 2. To control the visibility of the confirmation alert.
    @State private var showingDeleteAlert = false

    var body: some View {
        List {
            ForEach(viewModel.sessions) { session in
                // --- THIS IS THE FIX ---
                // The SessionCardView is now the main content of the row.
                SessionCardView(session: session)
                    // The NavigationLink is placed in the background, making the whole
                    // card tappable without showing the arrow.
                    .background(
                        NavigationLink(destination: SessionDetailView(session: session, audioManager: audioManager)) {
                            EmptyView()
                        }
                        .opacity(0) // Make the link itself invisible
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            // --- MODIFIED .onDelete ---
            // Now, it sets state to show the alert instead of deleting directly.
            .onDelete { offsets in
                // Find the session to delete from the offsets.
                guard let index = offsets.first else { return }
                self.sessionToDelete = viewModel.sessions[index]
                self.showingDeleteAlert = true
            }
        }
        .listStyle(.plain)
        .navigationTitle("Sessions")
        // --- NEW .alert MODIFIER ---
        // 3. This alert is presented when showingDeleteAlert is true.
        .alert("Delete Session?", isPresented: $showingDeleteAlert, presenting: sessionToDelete) { session in
            Button("Delete", role: .destructive) {
                // The actual deletion happens here, only after confirmation.
                performDelete(session: session)
            }
            Button("Cancel", role: .cancel) { }
        } message: { session in
            Text("Are you sure you want to delete the session \"\(session.title ?? "Practice")\"? All of its plays, notes, and recordings will be permanently removed.")
        }
    }
    
    /// Performs the actual deletion of the session.
    private func performDelete(session: PracticeSession) {
        viewModel.context.delete(session)
        try? viewModel.context.save()
        viewModel.practiceVM.reload()
    }
}

// The card view itself remains mostly the same, but now lives inside a List row.
struct SessionCardView: View {
    let session: PracticeSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.title ?? "Practice")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(session.day.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                if let location = session.location {
                    Label(location.rawValue, systemImage: "mappin.and.ellipse")
                }
                Spacer()
                if let instructor = session.instructor {
                    Label(instructor.name, systemImage: "person.fill")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}
#Preview {
    PreviewWrapper()
        .environmentObject(AudioManager())
}

struct PreviewWrapper: View {
    @State var viewModel = StudentDetailViewModel.mock

    var body: some View {
        NavigationStack {
            SessionListView(viewModel: $viewModel)
        }
    }
}

extension StudentDetailViewModel {
    static var mock: StudentDetailViewModel {
        let container = try! ModelContainer(for: Student.self, PracticeSession.self, Instructor.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let student = Student(name: "Alice Example", instrument: "Cello")
        context.insert(student)

        let session1 = PracticeSession(day: Date(), durationMinutes: 45, studentID: student.id)
        session1.title = "Lesson 1"
        session1.location = LessonLocation.privateLesson
        session1.instructor = Instructor(name: "Mr. Smith")

        let session2 = PracticeSession(day: Date().addingTimeInterval(-86400), durationMinutes: 30, studentID: student.id)
        session2.title = "Practice"
        session2.location = LessonLocation.home

        context.insert(session1)
        context.insert(session2)

        return StudentDetailViewModel(student: student, context: context)
    }
}
