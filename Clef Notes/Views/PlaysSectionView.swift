
struct PlaysSectionView: View {
    @Bindable var session: PracticeSession
    @Environment(\.modelContext) private var context

    var body: some View {
        Section("Associated Plays") {
            if session.plays.isEmpty {
                Text("No plays recorded")
                    .foregroundColor(.secondary)
            } else {
                ForEach(session.plays, id: \.persistentModelID) { play in
                    VStack(alignment: .leading) {
                        Text(play.song?.title ?? "Unknown Song")
                        Text("Count: \(play.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let play = session.plays[index]
                        context.delete(play)
                        session.plays.remove(at: index)
                    }
                    try? context.save()
                }
            }
        }
    }
}
