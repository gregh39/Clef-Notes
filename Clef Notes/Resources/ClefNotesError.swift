//
//  ClefNotesError.swift
//  Clef Notes
//
//  Created by Greg Holland on 8/1/25.
//


import Foundation
import SwiftUI
import os.log
import SwiftUI
import CoreData

// Centralized error handling
enum ClefNotesError: LocalizedError {
    case coreDataError(NSError)
    case audioSessionError(String)
    case fileImportError(String)
    case subscriptionError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .coreDataError(let error):
            return "Database error: \(error.localizedDescription)"
        case .audioSessionError(let message):
            return "Audio error: \(message)"
        case .fileImportError(let message):
            return "File import error: \(message)"
        case .subscriptionError(let message):
            return "Subscription error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .coreDataError:
            return "Try restarting the app. If the problem persists, contact support."
        case .audioSessionError:
            return "Check your device's audio settings and try again."
        case .fileImportError:
            return "Make sure the file is accessible and try importing again."
        case .subscriptionError:
            return "Check your internet connection and try again."
        case .networkError:
            return "Check your internet connection and try again."
        }
    }
}

// Centralized logging
class AppLogger {
    static let shared = AppLogger()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ClefNotes", category: "general")
    
    private init() {}
    
    func log(_ message: String, level: OSLogType = .default) {
        logger.log(level: level, "\(message)")
    }
    
    func logError(_ error: Error, context: String = "") {
        logger.error("Error in \(context): \(error.localizedDescription)")
    }
    
    func logAudioEvent(_ event: String) {
        logger.info("Audio: \(event)")
    }
    
    func logCoreDataEvent(_ event: String) {
        logger.info("CoreData: \(event)")
    }
}

// Error handling view modifier
struct ErrorHandling: ViewModifier {
    @State private var errorWrapper: ErrorWrapper?
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: .constant(errorWrapper != nil)) {
                Button("OK") {
                    errorWrapper = nil
                }
                
                if let recovery = errorWrapper?.error.recoverySuggestion {
                    Button("Learn More") {
                        // Show more detailed error info
                    }
                }
            } message: {
                Text(errorWrapper?.error.localizedDescription ?? "An unknown error occurred")
            }
            .onReceive(NotificationCenter.default.publisher(for: .errorOccurred)) { notification in
                if let error = notification.object as? ClefNotesError {
                    errorWrapper = ErrorWrapper(error: error)
                    AppLogger.shared.logError(error)
                }
            }
    }
}

struct ErrorWrapper {
    let error: ClefNotesError
}

extension Notification.Name {
    static let errorOccurred = Notification.Name("errorOccurred")
}

extension View {
    func withErrorHandling() -> some View {
        self.modifier(ErrorHandling())
    }
}

// Usage in Core Data operations
extension NSManagedObjectContext {
    func saveWithErrorHandling() {
        do {
            if hasChanges {
                try save()
                AppLogger.shared.logCoreDataEvent("Context saved successfully")
            }
        } catch {
            let clefError = ClefNotesError.coreDataError(error as NSError)
            NotificationCenter.default.post(name: .errorOccurred, object: clefError)
        }
    }
}
