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

    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        /**
         Prepare the containing folder for the Core Data stores.
         A Core Data store has companion files, so it's a good practice to put a store under a folder.
         */
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

        let container = NSPersistentCloudKitContainer(name: "ClefNotesCD")
        
        /**
         Grab the default (first) store and associate it with the CloudKit private database.
         Set up the store description by:
         - Specifying a filename for the store.
         - Enabling history tracking and remote notifications.
         - Specifying the iCloud container and database scope.
        */
        guard let privateStoreDescription = container.persistentStoreDescriptions.first else {
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
                
        /**
         Similarly, add a second store and associate it with the CloudKit shared database.
         */
        guard let sharedStoreDescription = privateStoreDescription.copy() as? NSPersistentStoreDescription else {
            fatalError("#\(#function): Copying the private store description returned an unexpected value.")
        }
        sharedStoreDescription.url = sharedStoreFolderURL.appendingPathComponent("shared.sqlite")
        
        // --- THIS IS THE FIX: Enable lightweight migration for the shared store ---
        sharedStoreDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        sharedStoreDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        let sharedStoreOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: gCloudKitContainerIdentifier)
        sharedStoreOptions.databaseScope = .shared
        sharedStoreDescription.cloudKitContainerOptions = sharedStoreOptions

        /**
         Load the persistent stores.
         */
        container.persistentStoreDescriptions.append(sharedStoreDescription)
        container.loadPersistentStores(completionHandler: { (loadedStoreDescription, error) in
            guard error == nil else {
                fatalError("#\(#function): Failed to load persistent stores:\(error!)")
            }
            guard let cloudKitContainerOptions = loadedStoreDescription.cloudKitContainerOptions else {
                return
            }
            if cloudKitContainerOptions.databaseScope == .private {
                self._privatePersistentStore = container.persistentStoreCoordinator.persistentStore(for: loadedStoreDescription.url!)
            } else if cloudKitContainerOptions.databaseScope  == .shared {
                self._sharedPersistentStore = container.persistentStoreCoordinator.persistentStore(for: loadedStoreDescription.url!)
            }
        })

        /**
         Run initializeCloudKitSchema() once to update the CloudKit schema every time you change the Core Data model.
         Dispatch to the next runloop in the main queue to avoid blocking AppKit app life-cycle delegate methods.
         Don't call this code in the production environment.
         */
        #if InitializeCloudKitSchema
        DispatchQueue.main.async {
            do {
                try container.initializeCloudKitSchema()
                print("CloudKit Migration Complete")


            } catch {
                print("\(#function): initializeCloudKitSchema: \(error)")
            }
        }
        #else
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = TransactionAuthor.app

        /**
         Automatically merge the changes from other contexts.
         */
        container.viewContext.automaticallyMergesChangesFromParent = true

        /**
         Pin the viewContext to the current generation token and set it to keep itself up-to-date with local changes.
         */
        do {
            try container.viewContext.setQueryGenerationFrom(.current)
        } catch {
            fatalError("#\(#function): Failed to pin viewContext to the current generation:\(error)")
        }
        
        #endif
        return container
    }()
    
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
}

/*
struct PersistenceController2 {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "ClefNotesCD")
        
        guard let privateStoreDescription = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        let storesURL = privateStoreDescription.url?.deletingLastPathComponent()
        
        let sharedStoreURL = storesURL?.appendingPathComponent("shared.sqlite")
        guard let sharedStoreDescription = privateStoreDescription.copy() as? NSPersistentStoreDescription else {
            fatalError("Copying the private store description failed.")
        }
        sharedStoreDescription.url = sharedStoreURL
        
        guard let containerIdentifier = privateStoreDescription.cloudKitContainerOptions?.containerIdentifier else {
            fatalError("Could not get container identifier.")
        }
        let sharedStoreOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
        sharedStoreOptions.databaseScope = .shared
        sharedStoreDescription.cloudKitContainerOptions = sharedStoreOptions
        
        container.persistentStoreDescriptions.append(sharedStoreDescription)

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    private var _sharedPersistentStore: NSPersistentStore?
    var sharedPersistentStore: NSPersistentStore {
        return _sharedPersistentStore!
    }

}
*/
