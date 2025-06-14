@Observable
class StudentDetailViewModel {
    let student: Student
    let context: ModelContext

    @ObservationIgnored var practiceVM: StudentPracticeViewModel

    var title = ""
    var goalPlays = ""
    var currentPlays = ""
    var youtubeLink = ""
    var appleMusicLink = ""
    var spotifyLink = ""
    var localFileLink = ""

    init(student: Student, context: ModelContext) {
        self.student = student
        self.context = context
        self.practiceVM = StudentPracticeViewModel(student: student, context: context)
    }

    var songs: [Song] { practiceVM.songs }
    var sessions: [PracticeSession] { practiceVM.sessions }

    func clearSongForm() {
        title = ""
        goalPlays = ""
        currentPlays = ""
        youtubeLink = ""
        appleMusicLink = ""
        spotifyLink = ""
        localFileLink = ""
    }

    func addSong() {
        let goal = Int(goalPlays)
        let current = Int(currentPlays) ?? 0

        let song = Song(title: title, goalPlays: goal, studentID: student.id)
        song.student = student

        if current > 0 {
            let play = Play(count: current)
            play.song = song
            song.plays.append(play)
        }

        [youtubeLink: MediaType.youtubeVideo,
         appleMusicLink: MediaType.appleMusicLink,
         spotifyLink: MediaType.spotifyLink,
         localFileLink: MediaType.audioRecording]
        .forEach { (urlString, type) in
            if let url = URL(string: urlString), !urlString.isEmpty {
                let media = MediaReference(type: type, url: url)
                media.song = song
                song.media.append(media)
            }
        }

        context.insert(song)
        try? context.save()
        practiceVM.reload()
    }

    func addSession() -> PracticeSession {
        let session = PracticeSession(day: .now, durationMinutes: 0, studentID: student.id)
        session.student = student
        context.insert(session)
        try? context.save()
        practiceVM.reload()
        return session
    }
}