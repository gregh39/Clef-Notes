import SwiftUI
import CoreData
import CloudKit

struct TimerBarView: View {
    @EnvironmentObject var sessionTimerManager: SessionTimerManager
    @AppStorage("selectedAccentColor") private var accentColor: AccentColor = .blue

    var body: some View {
        if let session = sessionTimerManager.activeSession {
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text(session.title ?? "Practice Session")
                        .font(.headline)
                        .lineLimit(1)
                    Text(sessionTimerManager.elapsedTimeString)
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    if sessionTimerManager.isPaused {
                        sessionTimerManager.resume()
                    } else {
                        sessionTimerManager.pause()
                    }
                } label: {
                    Image(systemName: sessionTimerManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(accentColor.color.opacity(0.2))
                        .foregroundColor(accentColor.color)
                        .cornerRadius(10)
                }
                
                Button {
                    sessionTimerManager.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                }
            }
            .padding()
            .background(.bar)
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(), value: sessionTimerManager.activeSession)
        }
    }
}
