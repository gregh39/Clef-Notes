import SwiftUI
import CoreData
import CloudKit

struct CloudSharingView: View {
    let student: StudentCD
    @State private var share: CKShare?
    @State private var isPreparing = false
    @State private var isSharing = false
    @State private var error: Error?
    private let container = PersistenceController.shared.persistentContainer
    
    @State private var selectedDetent: PresentationDetent = .medium
    
    var body: some View {
        VStack {
            // --- THIS IS THE FIX: Check if the student is already shared ---
            if student.isShared {
                AlreadySharedView()
            } else {
                GroupBox {
                    VStack(spacing: 20) {
                        if isPreparing {
                            ProgressView {
                                Text("Generating Secure Share Link...")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .scaleEffect(1.5)
                            .padding()
                        } else if let share = share {
                            ShareReadyView(isSharing: $isSharing)
                        } else if let error = error {
                            ShareErrorView(error: error) {
                                Task { await prepareShare() }
                            }
                        } else {
                            ShareInitialView {
                                Task { await prepareShare() }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding()
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .task {
            // Only prepare the share if the student is not already shared.
            if !student.isShared, share == nil, !isPreparing, error == nil {
                await prepareShare()
            }
        }
        .sheet(isPresented: $isSharing) {
            if let share = share {
                CloudSharingControllerView(share: share, container: container)
            }
        }
        .navigationTitle("Share Student")
    }

    @MainActor
    private func prepareShare() async {
        
        isPreparing = true
        error = nil
        defer { isPreparing = false }

        let backgroundContext = container.newBackgroundContext()

        do {
            let studentObjectID = student.objectID
            
            let shares = try await backgroundContext.perform {
                try self.container.fetchShares(matching: [studentObjectID])
            }

            if let existingShare = shares[studentObjectID] {
                self.share = existingShare
            } else {
                guard let studentInContext = backgroundContext.object(with: studentObjectID) as? StudentCD else {
                    self.error = NSError(domain: "ClefNotes", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find the student to share."])
                    return
                }

                let (_, newShare, _) = try await container.share([studentInContext], to: nil)
                
                newShare[CKShare.SystemFieldKey.title] = student.name
                newShare.publicPermission = .readWrite
                
                try await backgroundContext.perform {
                    try backgroundContext.save()
                }
                
                self.share = newShare
            }
        } catch {
            self.error = error
        }
    }
}

// Subviews for different states
private struct ShareInitialView: View {
    var onPrepare: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            Text("Share Student")
                .font(.title2.bold())
            Text("Collaborate with another Clef Notes user by sharing this student's profile. This will allow them to view and edit the student's data.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onPrepare) {
                Label("Generate Secure Share Link", systemImage: "link")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

private struct ShareReadyView: View {
    @Binding var isSharing: Bool
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            Text("Share Link Ready!")
                .font(.title2.bold())
            Text("You can now share this student's profile with another Clef Notes user.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(action: { isSharing = true }) {
                Label("Share Student Profile", systemImage: "square.and.arrow.up")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

private struct ShareErrorView: View {
    let error: Error
    var onRetry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("Sharing Error")
                .font(.title2.bold())
            Text("Something went wrong while preparing the share. Please check your internet connection and try again.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            Button(action: onRetry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .fontWeight(.bold)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
    }
}

// --- THIS IS THE FIX: A new view for when the student is already shared ---
private struct AlreadySharedView: View {
    var body: some View {
        GroupBox {
            VStack(spacing: 16) {
                Image(systemName: "person.2.slash.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                Text("Cannot Be Shared")
                    .font(.title2.bold())
                Text("This student's profile was shared with you by its original owner. Only the original owner can share this profile with other users.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .padding()
    }
}


struct CloudSharingControllerView: UIViewControllerRepresentable {
    let share: CKShare
    let container: NSPersistentCloudKitContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let ckContainer: CKContainer
        if let description = container.persistentStoreDescriptions.first,
           let options = description.cloudKitContainerOptions {
            ckContainer = CKContainer(identifier: options.containerIdentifier)
        } else {
            ckContainer = CKContainer.default()
        }
        let controller = UICloudSharingController(
            share: share,
            container: ckContainer
        )
        controller.modalPresentationStyle = UIModalPresentationStyle.formSheet
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}
