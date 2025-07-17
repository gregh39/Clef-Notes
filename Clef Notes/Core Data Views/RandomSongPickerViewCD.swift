//
//  RandomSongPickerViewCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/16/25.
//


import SwiftUI
import CoreData

struct RandomSongPickerViewCD: View {
    let songs: [SongCD]
    @State private var selectedSong: SongCD? = nil
    @State private var wheelRotation: Double = 0
    @State private var isSpinning: Bool = false
    @State private var selectedStatuses: Set<PlayType> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // UI is identical to the original, just uses SongCD
                Spacer()
                Text("Spin to Decide!").font(.largeTitle.bold())
                // ... Filter UI ...
                Spacer()
                ZStack(alignment: .top) {
                    WheelViewCD(songs: filteredSongs, rotation: $wheelRotation)
                        .frame(width: 320, height: 320)
                    Image(systemName: "arrowtriangle.down.fill").font(.system(size: 50)).foregroundColor(.red)
                        .offset(y: -25)
                }
                Spacer()
                if let song = selectedSong {
                    Text("Next up: \(song.title ?? "Song")").font(.title2.bold())
                } else {
                    Text("Spin the wheel...").font(.headline).foregroundColor(.gray)
                }
                Spacer()
                Button(isSpinning ? "Spinning..." : "SPIN") { spinWheel() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(isSpinning)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var filteredSongs: [SongCD] {
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
        
        withAnimation(.timingCurve(0.1, 0.9, 0.2, 1, duration: 4.0)) {
            self.wheelRotation += finalTargetRotation
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.1) {
            self.selectedSong = winner
            self.isSpinning = false
        }
    }
}

private struct WheelViewCD: View {
    let songs: [SongCD]
    @Binding var rotation: Double
    private let colors: [Color] = [.red,.orange,.yellow,.green,.blue,.indigo,.purple]

    var body: some View {
        ZStack {
            ForEach(songs.indices, id: \.self) { index in
                WheelSliceCD(
                    index: index,
                    totalSlices: songs.count,
                    songTitle: songs[index].title ?? "Song",
                    color: colors[index % colors.count]
                )
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

private struct WheelSliceCD: View {
    let index: Int
    let totalSlices: Int
    let songTitle: String
    let color: Color

    var body: some View {
        // This view's drawing logic is identical to the original
        let sliceAngle = 360.0 / Double(totalSlices)
        let startAngle = sliceAngle * Double(index)
        let middleAngle = startAngle + (sliceAngle / 2.0)

        return ZStack {
            Path { path in
                let center = CGPoint(x: 160, y: 160)
                path.move(to: center)
                path.addArc(center: center, radius: 160, startAngle: .degrees(startAngle), endAngle: .degrees(startAngle + sliceAngle), clockwise: false)
            }
            .fill(color)
            
            Text(songTitle)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .shadow(radius: 1)
                .frame(width: 150, height: 45)
                .offset(x: 80)
                .rotationEffect(.degrees(middleAngle))
        }
    }
}
