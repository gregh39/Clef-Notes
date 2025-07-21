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
    
    var body: some View {
        VStack {
            if isPreparing {
                ProgressView("Preparing Share...")
            } else if let share = share {
                Button(action: { isSharing = true }) {
                    Label("Share Student", systemImage: "square.and.arrow.up")
                }
                .onAppear { error = nil }
            } else if let error = error {
                VStack(spacing: 12) {
                    Text("Failed to prepare share: \(error.localizedDescription)")
                        .foregroundStyle(.red)
                    Button("Try Again") {
                        Task { await prepareShare() }
                    }
                }
            } else {
                Button(action: {
                    Task { await prepareShare() }
                }) {
                    Label("Prepare Share", systemImage: "link")
                }
            }
        }
        .task {
            if share == nil && !isPreparing && error == nil {
                await prepareShare()
            }
        }
        .sheet(isPresented: $isSharing) {
            if let share = share {
                CloudSharingControllerView(share: share, container: container)
            }
        }
    }
    
    @MainActor
    private func prepareShare() async {
        isPreparing = true
        error = nil
        defer { isPreparing = false }

        let backgroundContext = container.newBackgroundContext()

        do {
            // Use the specific student's object ID from the main context
            let studentObjectID = student.objectID
            
            // Fetch existing shares using the background context
            let shares = try await backgroundContext.perform {
                try self.container.fetchShares(matching: [studentObjectID])
            }

            if let existingShare = shares[studentObjectID] {
                self.share = existingShare
            } else {
                // Fetch the student in the background context before sharing
                guard let studentInContext = backgroundContext.object(with: studentObjectID) as? StudentCD else {
                    // Handle error if student is not found in the new context
                    self.error = NSError(domain: "ClefNotes", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find the student to share."])
                    return
                }

                // Create the share using the object from the background context
                let (_, newShare, _) = try await container.share([studentInContext], to: nil)
                
                // Set share properties
                newShare[CKShare.SystemFieldKey.title] = student.name
                newShare.publicPermission = .readWrite
                
                // **THE FIX**: Save the background context to persist the share
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
