import CoreData
import SwiftData
import os.log
import CloudKit // Import CloudKit


/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A class that sets up the Core Data stack.
*/

import Foundation
import CoreData
import CloudKit
import SwiftUI

let gCloudKitContainerIdentifier = "iCloud.com.ClefNotesApp"

/**
 This app doesn't necessarily post notifications from the main queue.
 */
extension Notification.Name {
    static let cdcksStoreDidChange = Notification.Name("cdcksStoreDidChange")
}

struct UserInfoKey {
    static let storeUUID = "storeUUID"
    static let transactions = "transactions"
}

struct TransactionAuthor {
    static let app = "app"
}

class PersistenceController: NSObject {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.persistentContainer.viewContext
        // Create sample data
        let student1 = StudentCD(context: viewContext)
        student1.name = "Alice"
        student1.instrument = "Violin"
        
        let student2 = StudentCD(context: viewContext)
        student2.name = "Bob"
        student2.instrument = "Piano"
        
        let student3 = StudentCD(context: viewContext)
        student3.name = "Charlie"
        student3.instrument = "Flute"
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let persistentContainer: NSPersistentCloudKitContainer
    
    private var _privatePersistentStore: NSPersistentStore?
    var privatePersistentStore: NSPersistentStore {
        return _privatePersistentStore!
    }

    private var _sharedPersistentStore: NSPersistentStore?
    var sharedPersistentStore: NSPersistentStore {
        return _sharedPersistentStore!
    }
    
    lazy var cloudKitContainer: CKContainer = {
        return CKContainer(identifier: gCloudKitContainerIdentifier)
    }()
    
    /**
     An operation queue for handling history-processing tasks: watching changes, deduplicating tags, and triggering UI updates, if needed.
     */
    lazy var historyQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private init(inMemory: Bool = false) {
        persistentContainer = NSPersistentCloudKitContainer(name: "ClefNotesCD")
        
        if inMemory {
            persistentContainer.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            let baseURL = NSPersistentContainer.defaultDirectoryURL()
            let storeFolderURL = baseURL.appendingPathComponent("CoreDataStores")
            let privateStoreFolderURL = storeFolderURL.appendingPathComponent("Private")
            let sharedStoreFolderURL = storeFolderURL.appendingPathComponent("Shared")

            let fileManager = FileManager.default
            for folderURL in [privateStoreFolderURL, sharedStoreFolderURL] where !fileManager.fileExists(atPath: folderURL.path) {
                do {
                    try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    fatalError("#\(#function): Failed to create the store folder: \(error)")
                }
            }

            guard let privateStoreDescription = persistentContainer.persistentStoreDescriptions.first else {
                fatalError("#\(#function): Failed to retrieve a persistent store description.")
            }
            privateStoreDescription.url = privateStoreFolderURL.appendingPathComponent("private.sqlite")
            
            privateStoreDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            privateStoreDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

            privateStoreDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            privateStoreDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: gCloudKitContainerIdentifier)

            cloudKitContainerOptions.databaseScope = .private
            privateStoreDescription.cloudKitContainerOptions = cloudKitContainerOptions
                    
            guard let sharedStoreDescription = privateStoreDescription.copy() as? NSPersistentStoreDescription else {
                fatalError("#\(#function): Copying the private store description returned an unexpected value.")
            }
            sharedStoreDescription.url = sharedStoreFolderURL.appendingPathComponent("shared.sqlite")
            
            sharedStoreDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            sharedStoreDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

            let sharedStoreOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: gCloudKitContainerIdentifier)
            sharedStoreOptions.databaseScope = .shared
            sharedStoreDescription.cloudKitContainerOptions = sharedStoreOptions

            persistentContainer.persistentStoreDescriptions.append(sharedStoreDescription)
        }

        super.init()

        persistentContainer.loadPersistentStores(completionHandler: { (loadedStoreDescription, error) in
            guard error == nil else {
                fatalError("#\(#function): Failed to load persistent stores:\(error!)")
            }
            if !inMemory {
                guard let cloudKitContainerOptions = loadedStoreDescription.cloudKitContainerOptions else {
                    return
                }
                if cloudKitContainerOptions.databaseScope == .private {
                    self._privatePersistentStore = self.persistentContainer.persistentStoreCoordinator.persistentStore(for: loadedStoreDescription.url!)
                } else if cloudKitContainerOptions.databaseScope  == .shared {
                    self._sharedPersistentStore = self.persistentContainer.persistentStoreCoordinator.persistentStore(for: loadedStoreDescription.url!)
                }
                UsageManager.cleanupDuplicateTrackersIfNeeded(context: self.persistentContainer.viewContext)
            }
        })

        if !inMemory {
            persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            persistentContainer.viewContext.transactionAuthor = TransactionAuthor.app
            persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
            do {
                try persistentContainer.viewContext.setQueryGenerationFrom(.current)
            } catch {
                fatalError("#\(#function): Failed to pin viewContext to the current generation:\(error)")
            }
        }
    }
}
