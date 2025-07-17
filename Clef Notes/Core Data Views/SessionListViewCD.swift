import SwiftUI
import CoreData

private struct MonthSection: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let sessions: [PracticeSessionCD]

    var title: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

struct SessionListViewCD: View {
    @ObservedObject var student: StudentCD
    @EnvironmentObject var audioManager: AudioManager
    
    var onAddSession: () -> Void

    @State private var sessionToDelete: PracticeSessionCD? = nil
    @State private var expandedMonths: Set<Date> = []

    private var groupedSessions: [MonthSection] {
        let grouped = Dictionary(grouping: student.sessionsArray) { session in
            Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: session.day ?? .now)) ?? (session.day ?? .now)
        }
        return grouped.map { (date, sessions) in
            MonthSection(date: date, sessions: sessions)
        }.sorted { $0.date > $1.date }
    }

    var body: some View {
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
                ForEach(groupedSessions) { section in
                    DisclosureGroup(isExpanded: Binding(
                        get: { expandedMonths.contains(section.id) },
                        set: { isExpanded in
                            if isExpanded { expandedMonths.insert(section.id) }
                            else { expandedMonths.remove(section.id) }
                        }
                    )) {
                        ForEach(section.sessions) { session in
                            // --- THIS IS THE FIX: Use value-based NavigationLink ---
                            NavigationLink(value: session) {
                                SessionCardViewCD(session: session)
                            }
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
                    } label: {
                        Text(section.title)
                            .font(.headline).fontWeight(.bold).padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Sessions")
            .alert("Delete Session?", isPresented: Binding(get: { sessionToDelete != nil }, set: { if !$0 { sessionToDelete = nil } }), presenting: sessionToDelete) { session in
                Button("Delete", role: .destructive) { deleteSession(session) }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.title ?? "Practice").font(.headline).fontWeight(.bold)
                Spacer()
                Text((session.day ?? .now).formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                if let location = session.location {
                    Label(location.rawValue, systemImage: "mappin.and.ellipse")
                }
                Spacer()
                if let instructor = session.instructor {
                    Label(instructor.name ?? "Unknown", systemImage: "person.fill")
                }
            }
            .font(.subheadline).foregroundColor(.secondary)
        }
        .padding().background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}
