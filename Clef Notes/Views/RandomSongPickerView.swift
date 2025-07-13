import SwiftUI
import SwiftData


// MARK: - Main View
struct RandomSongPickerView: View {
    let songs: [Song]
    @State private var selectedSong: Song? = nil
    @State private var wheelRotation: Double = 0
    @State private var isSpinning: Bool = false
    @State private var selectedStatuses: Set<PlayType> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Text("Spin to Decide!")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Spacer()
                VStack() {
                    Text("Filter by Status:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(PlayType.allCases, id: \.self) { status in
                                let isSelected = selectedStatuses.contains(status)
                                Button(action: {
                                    if isSelected {
                                        selectedStatuses.remove(status)
                                    } else {
                                        selectedStatuses.insert(status)
                                    }
                                }) {
                                    Text(status.rawValue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .clipShape(Capsule())
                                        .animation(.easeInOut, value: isSelected)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    
                }
                Spacer()
                // MARK: - Wheel and Pointer
                ZStack(alignment: .top) {
                    WheelView(songs: filteredSongs, rotation: $wheelRotation)
                        .frame(width: 320, height: 320)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 3)
                        .offset(y: -25)
                }

                Spacer()

                // MARK: - Result Display
                VStack {
                    if let song = selectedSong {
                        Text("Next up:")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(song.title)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.accentColor)
                            .transition(.opacity.combined(with: .scale))
                    } else {
                        Text("Spin the wheel...")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
                .frame(height: 60)

                // MARK: - Spin Button
                Button(action: spinWheel) {
                    HStack {
                        if isSpinning {
                            ProgressView().tint(.white)
                        }
                        Text(isSpinning ? "Spinning..." : "SPIN")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSpinning ? .gray : .accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .animation(.default, value: isSpinning)
                }
                .disabled(isSpinning)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .animation(.spring(), value: selectedSong)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var filteredSongs: [Song] {
        if selectedStatuses.isEmpty {
            return songs
        } else {
            return songs.filter { song in
                guard let status = song.songStatus else { return false }
                return selectedStatuses.contains(status)
            }
        }
    }

    private func spinWheel() {
        guard !filteredSongs.isEmpty else { return }
        
        isSpinning = true
        selectedSong = nil
        
        let randomIndex = Int.random(in: 0..<filteredSongs.count)
        let winner = filteredSongs[randomIndex]
        
        let sliceAngle = 360.0 / Double(filteredSongs.count)
        let winningSliceCenter = (sliceAngle * Double(randomIndex)) + (sliceAngle / 2.0)
        
        let targetAngle = 270.0 - winningSliceCenter
        
        let currentRotation = wheelRotation.truncatingRemainder(dividingBy: 360)
        let extraSpins = Double(Int.random(in: 4...6)) * 360
        let finalTargetRotation = targetAngle - currentRotation + extraSpins
        
        let animation = Animation.timingCurve(0.1, 0.9, 0.2, 1, duration: 4.0)
        withAnimation(animation) {
            self.wheelRotation += finalTargetRotation
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.1) {
            self.selectedSong = winner
            self.isSpinning = false
        }
    }
}

// MARK: - Wheel Component Views
private struct WheelView: View {
    let songs: [Song]
    @Binding var rotation: Double
    
    // Define the colors here as the source of truth
    private let colors: [Color] = [.red,.orange,.yellow,.green,.blue,.indigo,.purple]

    var body: some View {
        ZStack {
            ForEach(songs.indices, id: \.self) { index in
                // The view now passes the correct, pre-calculated color to the slice.
                WheelSlice(
                    index: index,
                    totalSlices: songs.count,
                    songTitle: songs[index].title,
                    color: colors[index % colors.count] // Logic is now here
                )
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

private struct WheelSlice: View {
    let index: Int
    let totalSlices: Int
    let songTitle: String
    let color: Color // Accepts a color instead of calculating it

    var body: some View {
        let sliceAngle = 360.0 / Double(totalSlices)
        let startAngle = sliceAngle * Double(index)
        let middleAngle = startAngle + (sliceAngle / 2.0)

        GeometryReader { geo in
            let radius = geo.size.width / 2
            let center = CGPoint(x: radius, y: radius)

            // MARK: - Slice Path
            Path { path in
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(startAngle + sliceAngle),
                    clockwise: false
                )
                path.closeSubpath()
            }
            // The slice is filled with the color passed from WheelView.
            .fill(color)
            .overlay(
                Path { path in
                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(startAngle + sliceAngle),
                        clockwise: false
                    )
                }.stroke(.white.opacity(0.5), lineWidth: 1)
            )

            // MARK: - Text Label
            Text(songTitle)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.1), radius: 1)
                .frame(width: radius * 0.95, height: 45)
                .multilineTextAlignment(.center)
                .allowsTightening(true)
                .minimumScaleFactor(0.8)
                .offset(x: radius * 0.6)
                .rotationEffect(.degrees(middleAngle))
                .position(center)
        }
    }
}
// MARK: - Preview
#Preview {
    // Note: The preview uses your actual Song class initializer now.
    let previewSongs = [
        Song(title: "Ode to Joy", studentID: UUID()),
        Song(title: "Clair de Lune", studentID: UUID()),
        Song(title: "Für Elise", studentID: UUID()),
        Song(title: "Canon in D Major", studentID: UUID()),
        Song(title: "Gymnopédie No. 1", studentID: UUID()),
        Song(title: "The Entertainer", studentID: UUID()),
        Song(title: "Maple Leaf Rag", studentID: UUID()),
        Song(title: "Moonlight Sonata", studentID: UUID())
    ]
    RandomSongPickerView(songs: previewSongs)
}
