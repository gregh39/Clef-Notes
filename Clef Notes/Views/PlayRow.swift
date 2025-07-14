import SwiftUI
import Foundation

struct PlayRow: View {
    @Bindable var play: Play
    
    let cumulativeTotal: Int

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(play.song?.title ?? "Unknown Song")
                    .fontWeight(.medium)
                
                // --- THIS IS THE FIX ---
                // The label now dynamically includes the play type for clarity.
                Text("Total \(play.playType?.rawValue ?? "") Plays: \(cumulativeTotal)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    if play.count > 1 {
                        play.count -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .font(.title2)
                .disabled(play.count <= 1)
                
                Text("\(play.count)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .frame(minWidth: 25)

                Button {
                    play.count += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var previewPlay: Play = {
            let p = Play(count: 5)
            p.playType = .practice
            p.song = Song(title: "Canon in D", studentID: UUID())
            return p
        }()
        
        var body: some View {
            PlayRow(play: previewPlay, cumulativeTotal: 25)
                .padding()
        }
    }
    return PreviewWrapper()
}
