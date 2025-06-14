struct AddSongSheet: View {
    @Binding var isPresented: Bool
    @Binding var title: String
    @Binding var goalPlays: String
    @Binding var currentPlays: String
    @Binding var youtubeLink: String
    @Binding var appleMusicLink: String
    @Binding var spotifyLink: String
    @Binding var localFileLink: String
    var addAction: () -> Void
    var clearAction: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Song Info") {
                    TextField("Title", text: $title)
                    TextField("Goal Plays", text: $goalPlays)
                        .keyboardType(.numberPad)
                    TextField("Current Plays", text: $currentPlays)
                        .keyboardType(.numberPad)
                }

                Section("Links") {
                    TextField("YouTube", text: $youtubeLink)
                    TextField("Apple Music", text: $appleMusicLink)
                    TextField("Spotify", text: $spotifyLink)
                    TextField("Local File", text: $localFileLink)
                }
            }
            .navigationTitle("New Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                        clearAction()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAction()
                        isPresented = false
                        clearAction()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
