import SwiftUI
import SwiftData

struct StudentSongsTabView: View {
    @Binding var viewModel: StudentDetailViewModel
    @Binding var selectedSort: StudentDetailView.SongSortOption

    // Helper to group and sort songs by status
    private var groupedSortedSongs: [(key: PlayType?, value: [Song])]
    {
        // 1. Group by songStatus
        let grouped = Dictionary(grouping: viewModel.songs, by: { $0.songStatus })
        // 2. Sort each group as per selectedSort
        let sortedKeys = PlayType.allCases.map { Optional($0) } + [nil] // All statuses, nil last
        
        return sortedKeys.compactMap { status in
            guard let group = grouped[status] else { return nil }
            let sortedGroup: [Song]
            switch selectedSort {
            case .title:
                sortedGroup = group.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .playCount:
                sortedGroup = group.sorted { $0.totalPlayCount > $1.totalPlayCount }
            case .recentlyPlayed:
                sortedGroup = group.sorted { ($0.lastPlayedDate ?? .distantPast) > ($1.lastPlayedDate ?? .distantPast) }
            }
            return (key: status, value: sortedGroup)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // The sort picker (segmented) above the list
            
            List {
                Section() {
                    Picker("Sort by", selection: $selectedSort) {
                        ForEach(StudentDetailView.SongSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                    
                ForEach(groupedSortedSongs, id: \.key) { section in
                    Section(header: Text(section.key?.rawValue ?? "No Status")) {
                        ForEach(section.value, id: \.persistentModelID) { song in
                            NavigationLink(destination: SongDetailView(song: song)) {
                                SongRowView(song: song, progress: viewModel.practiceVM.progress(for: song))
                            }
                        }
                        .onDelete { indexSet in
                            // Delete the correct songs from this group
                            let toDelete = indexSet.map { section.value[$0] }
                            for song in toDelete {
                                viewModel.deleteSong(song)
                            }
                            try? viewModel.context.save()
                            viewModel.practiceVM.reload()
                        }
                    }
                }
            }
        }
    }
}

