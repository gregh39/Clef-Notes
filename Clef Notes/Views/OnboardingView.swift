import SwiftUI

struct OnboardingView: View {
    // This binding will be connected to an @AppStorage property
    // to ensure the onboarding screen is only shown once.
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        VStack {
            TabView {
                OnboardingPage(
                    imageName: "person.badge.plus",
                    title: "Welcome to Clef Notes",
                    description: "Your personal music practice companion. Start by creating a student profile to track progress."
                )
                
                OnboardingPage(
                    imageName: "calendar.badge.plus",
                    title: "Log Your Sessions",
                    description: "Easily log practice sessions, including duration, songs played, and notes for each student."
                )
                
                OnboardingPage(
                    imageName: "music.note.list",
                    title: "Manage Your Repertoire",
                    description: "Keep a detailed list of all the songs, scales, and exercises you're working on."
                )
                
                OnboardingPage(
                    imageName: "chart.bar.fill",
                    title: "Visualize Your Progress",
                    description: "Track your practice streaks, see your most played songs, and watch your skills grow over time."
                )
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))

            Button(action: {
                // When tapped, this sets the flag to true, permanently hiding the onboarding screen.
                hasCompletedOnboarding = true
            }) {
                Text("Get Started")
                    .font(.headline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
        // This line adds an opaque background that respects light/dark mode.
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
    }
}

// A helper view for the content of each individual onboarding page
private struct OnboardingPage: View {
    let imageName: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: imageName)
                .font(.system(size: 100))
                .foregroundColor(.accentColor)
            
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text(description)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
}
