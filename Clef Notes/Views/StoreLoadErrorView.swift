import SwiftUI

/// Shown instead of the main UI when the Core Data store could not be opened
/// (for example, a failed model migration). The store files are left untouched.
struct StoreLoadErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("Couldn't Open Your Data")
                .font(.title2.bold())
            Text("Clef Notes wasn't able to load your practice data. Your data has not been deleted. Try closing and reopening the app, or make sure you have the latest update installed. If the problem continues, please contact support.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Button {
                contactSupport()
            } label: {
                Label("Contact Support", systemImage: "envelope.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
    }

    private func contactSupport() {
        let subject = "ClefNotes data could not be loaded"
        let body = "Error: \(error.localizedDescription)"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:feedback@clefnotes.app?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }
}
