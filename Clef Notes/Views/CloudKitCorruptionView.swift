import SwiftUI
import CoreData

struct CloudKitCorruptionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var corruptedObjects: [CloudKitCorruptionDetector.CorruptedObject] = []
    @State private var isScanning = false
    @State private var showingDeleteConfirmation = false
    @State private var deletionResult: String?
    @State private var objectUriToDelete = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("CloudKit sync has detected objects assigned to multiple zones, which causes corruption. You can scan for and remove these objects.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Quick Fix") {
                    Text("Based on the error logs, there's a corrupted PlayCD object. You can delete it directly using its URI.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Object URI", text: $objectUriToDelete)
                        .font(.caption)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Delete Object by URI") {
                        deleteObjectByUri()
                    }
                    .disabled(objectUriToDelete.isEmpty)

                    if let result = deletionResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("Deleted") ? .green : .red)
                    }
                }

                Section("Scan for Corrupted Objects") {
                    Button(action: scanForCorruption) {
                        HStack {
                            Text("Scan Database")
                            Spacer()
                            if isScanning {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isScanning)

                    if !corruptedObjects.isEmpty {
                        Text("\(corruptedObjects.count) corrupted object(s) found")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if !corruptedObjects.isEmpty {
                    Section("Corrupted Objects") {
                        ForEach(corruptedObjects) { obj in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(obj.entityName)
                                    .font(.headline)
                                Text(obj.displayInfo)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if !obj.zones.isEmpty {
                                    Text("Zones: \(obj.zones.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }

                    Section {
                        Button("Delete All Corrupted Objects", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }

                Section("Advanced") {
                    Text("If the above doesn't work, you may need to reset CloudKit development environment in the CloudKit Dashboard and reinstall the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("CloudKit Corruption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Corrupted Objects?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteCorruptedObjects()
                }
            } message: {
                Text("This will permanently delete \(corruptedObjects.count) corrupted object(s). This action cannot be undone.")
            }
        }
    }

    private func scanForCorruption() {
        isScanning = true
        deletionResult = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let detected = CloudKitCorruptionDetector.detectCorruptedObjects(in: viewContext)

            DispatchQueue.main.async {
                corruptedObjects = detected
                isScanning = false
            }
        }
    }

    private func deleteCorruptedObjects() {
        let result = CloudKitCorruptionDetector.deleteCorruptedObjects(
            corruptedObjects,
            from: viewContext
        )

        switch result {
        case .success(let count):
            deletionResult = "Successfully deleted \(count) object(s)"
            corruptedObjects.removeAll()
        case .failure(let error):
            deletionResult = "Error: \(error.localizedDescription)"
        }
    }

    private func deleteObjectByUri() {
        deletionResult = nil

        let result = CloudKitCorruptionDetector.findAndDeleteCorruptedObject(
            uri: objectUriToDelete.trimmingCharacters(in: .whitespacesAndNewlines),
            in: viewContext
        )

        switch result {
        case .success(let message):
            deletionResult = message
            objectUriToDelete = ""
        case .failure(let error):
            deletionResult = "Error: \(error.localizedDescription)"
        }
    }
}

#Preview {
    CloudKitCorruptionView()
        .environment(\.managedObjectContext, PersistenceController.preview.persistentContainer.viewContext)
}
