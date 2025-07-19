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
        do {
            let objectIDs = [student.objectID]
            // Perform share fetching and creation on a background thread
            let shares: [NSManagedObjectID: CKShare] = try await withCheckedThrowingContinuation { continuation in
                container.performBackgroundTask { context in
                    do {
                        let shares = try container.fetchShares(matching: objectIDs)
                        continuation.resume(returning: shares)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            if let existingShare = shares[student.objectID] {
                share = existingShare
            } else {
                let (_, createdShare, _) = try await container.share([student], to: nil)
                createdShare[CKShare.SystemFieldKey.title] = student.name
                createdShare.publicPermission = .readWrite
                share = createdShare
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
