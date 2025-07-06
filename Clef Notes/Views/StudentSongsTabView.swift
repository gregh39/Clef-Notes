import SwiftUI
import SwiftData

struct StudentSongsTabView: View {
    @Binding var viewModel: StudentDetailViewModel
    @Binding var selectedSort: StudentDetailView.SongSortOption

    var body: some View {
        var sortedSongs: [Song] {
            switch selectedSort {
            case .title:
                return viewModel.songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .playCount:
                return viewModel.songs.sorted { $0.totalPlayCount > $1.totalPlayCount }
            case .recentlyPlayed:
                return viewModel.songs.sorted {
                    ($0.lastPlayedDate ?? .distantPast) > ($1.lastPlayedDate ?? .distantPast)
                }
            }
        }

        List {
            Section("Songs") {
                Picker("Sort by", selection: $selectedSort) {
                    ForEach(StudentDetailView.SongSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                ForEach(sortedSongs, id: \.persistentModelID) { song in
                    NavigationLink(destination: SongDetailView(song: song)) {
                        SongRowView(song: song, progress: viewModel.practiceVM.progress(for: song))
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let song = sortedSongs[index]
                        viewModel.deleteSong(song)
                    }
                    try? viewModel.context.save()
                    viewModel.practiceVM.reload()
                }
            }
        }
    }
}
