import SwiftUI
import Foundation
import SwiftData

// A helper struct to represent a unique month and year for sectioning.
private struct MonthSection: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let sessions: [PracticeSession]

    var title: String {
        // Formatter to display the month and year (e.g., "July 2025")
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

struct SessionListView: View {
    @Binding var viewModel: StudentDetailViewModel
    @EnvironmentObject var audioManager: AudioManager
    
    // --- THIS IS THE FIX ---
    // 1. Add a closure to handle the add action.
    var onAddSession: () -> Void

    // State to hold the session that is a candidate for deletion.
    @State private var sessionToDelete: PracticeSession? = nil
    @State private var expandedMonths: Set<Date> = []

    // A computed property to group sessions by month.
    private var groupedSessions: [MonthSection] {
        let grouped = Dictionary(grouping: viewModel.sessions) { session in
            // Group by the first day of the month.
            Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: session.day)) ?? session.day
        }

        // Sort the groups so the most recent month is first.
        return grouped.map { (date, sessions) in
            MonthSection(date: date, sessions: sessions)
        }.sorted { $0.date > $1.date }
    }

    var body: some View {
        // --- THIS IS THE FIX ---
        // 2. Check if the sessions list is empty.
        if viewModel.sessions.isEmpty {
            // 3. Display a helpful empty state view.
            ContentUnavailableView {
                Label("No Sessions Yet", systemImage: "calendar.badge.plus")
            } description: {
                Text("Tap the button to log your first practice session.")
            } actions: {
                Button("Add First Session", action: onAddSession)
                    .buttonStyle(.borderedProminent)
            }
        } else {
            // If not empty, show the list as before.
            List {
                ForEach(groupedSessions) { section in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedMonths.contains(section.id) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedMonths.insert(section.id)
                                } else {
                                    expandedMonths.remove(section.id)
                                }
                            }
                        ),
                        content: {
                            ForEach(section.sessions) { session in
                                SessionCardView(session: session)
                                    .background(
                                        NavigationLink(destination: SessionDetailView(session: session, audioManager: audioManager)) {
                                            EmptyView()
                                        }
                                        .opacity(0)
                                    )
                                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            sessionToDelete = session
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        },
                        label: {
                            Text(section.title)
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.vertical, 4)
                        }
                    )
                }
            }
            .listStyle(.plain)
            .navigationTitle("Sessions")
            .alert(
                "Delete Session?",
                isPresented: Binding(
                    get: { sessionToDelete != nil },
                    set: { if !$0 { sessionToDelete = nil } }
                ),
                presenting: sessionToDelete
            ) { session in
                Button("Delete", role: .destructive) {
                    deleteSession(session)
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Are you sure you want to delete this session? All associated plays, notes, and recordings will also be permanently deleted.")
            }
            .onAppear {
                if let firstMonthID = groupedSessions.first?.id {
                    expandedMonths.insert(firstMonthID)
                }
            }
        }
    }
    
    /// Deletes a specific session.
    private func deleteSession(_ session: PracticeSession) {
        viewModel.context.delete(session)
        try? viewModel.context.save()
        viewModel.practiceVM.reload()
        sessionToDelete = nil // Reset the state after deletion
    }
}

// The card view itself remains the same.
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
    // Wrapper to provide the necessary environment for the preview
    struct PreviewWrapper: View {
        @State private var showingSheet = false
        @State var viewModel = StudentDetailViewModel.mockEmpty
        
        var body: some View {
            NavigationStack {
                SessionListView(viewModel: $viewModel) {
                    showingSheet = true
                }
            }
            .environmentObject(AudioManager())
        }
    }
    return PreviewWrapper()
}

// An extension to provide mock data for previews
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

        let session2 = PracticeSession(day: Date().addingTimeInterval(-86400 * 3), durationMinutes: 30, studentID: student.id)
        session2.title = "Practice"
        session2.location = LessonLocation.home
        
        let session3 = PracticeSession(day: Date().addingTimeInterval(-86400 * 45), durationMinutes: 60, studentID: student.id)
        session3.title = "June Practice"
        session3.location = LessonLocation.school

        context.insert(session1)
        context.insert(session2)
        context.insert(session3)

        return StudentDetailViewModel(student: student, context: context)
    }
    
    static var mockEmpty: StudentDetailViewModel {
        let container = try! ModelContainer(for: Student.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let student = Student(name: "Bob Beginner", instrument: "Piano")
        context.insert(student)
        return StudentDetailViewModel(student: student, context: context)
    }
}
