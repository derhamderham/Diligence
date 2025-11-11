//
//  DiligenceApp.swift
//  Diligence
//
//  Created by derham on 10/24/25.
//

import SwiftUI
import SwiftData
import Combine

@main
struct DiligenceApp: App {
    // MARK: - State
    
    @StateObject private var container = DependencyContainer.shared
    @StateObject private var errorHandler = ErrorHandler.shared
    
    // MARK: - Initialization
    
    init() {
        // Initialize Core Data migration fixes and secure transformers
        CoreDataMigrationHelper.initializeOnAppLaunch()
        
        // Check if we need to force reset due to persistent CoreData errors
        if ProcessInfo.processInfo.arguments.contains("--reset-database") {
            print("🚨 Database reset requested via command line argument")
            _ = CoreDataMigrationHelper.emergencyDatabaseReset()
        }
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DiligenceTask.self,
            TaskSection.self,
        ])
        
        // Try with standard configuration first
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ ModelContainer created successfully")
            return container
        } catch {
            print("❌ Initial ModelContainer creation failed: \(error)")
            
            // Handle error using centralized error handler
            _Concurrency.Task { @MainActor in
                ErrorHandler.shared.handleSilently(
                    AppError.database(.contextCreationFailed),
                    context: ErrorContext(
                        operation: "Initial ModelContainer creation",
                        additionalInfo: ["error": error.localizedDescription]
                    )
                )
            }
            
            // Check if this is a SQLite corruption error
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("sqlite") || 
               errorDescription.contains("cannot open file") ||
               errorDescription.contains("database disk image is malformed") ||
               errorDescription.contains("file is not a database") {
                print("🚨 Detected SQLite corruption error")
                
                let sqliteRecovered = CoreDataMigrationHelper.handleSQLiteCorruption()
                
                if sqliteRecovered {
                    print("🔄 Attempting to create ModelContainer after SQLite recovery...")
                    do {
                        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                        print("✅ ModelContainer created successfully after SQLite recovery")
                        return container
                    } catch {
                        print("❌ ModelContainer creation failed even after SQLite recovery: \(error)")
                        _Concurrency.Task { @MainActor in
                            ErrorHandler.shared.handleSilently(
                                AppError.database(.corruptedDatabase),
                                context: ErrorContext(operation: "ModelContainer creation after SQLite recovery")
                            )
                        }
                    }
                }
            }
            
            // If it's a schema migration issue, try emergency reset
            if error.localizedDescription.contains("SwiftDataError") || 
               error.localizedDescription.contains("loadIssueModelContainer") ||
               error.localizedDescription.contains("migration") {
                print("🔄 Detected schema migration issue, attempting emergency reset...")
                
                let resetSuccess = CoreDataMigrationHelper.emergencyDatabaseReset()
                
                if resetSuccess {
                    print("🔄 Attempting to create ModelContainer after reset...")
                    do {
                        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                        print("✅ ModelContainer created successfully after reset")
                        return container
                    } catch {
                        print("❌ ModelContainer creation failed even after reset: \(error)")
                        _Concurrency.Task { @MainActor in
                            ErrorHandler.shared.handleSilently(
                                AppError.database(.migrationFailed),
                                context: ErrorContext(operation: "ModelContainer creation after reset")
                            )
                        }
                    }
                }
            }
            
            // Last resort: in-memory container for this session
            print("🚨 Creating in-memory ModelContainer as fallback...")
            let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            
            do {
                let container = try ModelContainer(for: schema, configurations: [memoryConfiguration])
                print("⚠️ Using in-memory database - data will not persist!")
                
                // Notify user about in-memory fallback
                _Concurrency.Task { @MainActor in
                    ErrorHandler.shared.handle(
                        AppError.database(.corruptedDatabase),
                        context: ErrorContext(operation: "Database initialization"),
                        shouldPresent: true,
                        presentationStyle: .banner
                    )
                }
                
                return container
            } catch {
                print("❌ Even in-memory ModelContainer creation failed: \(error)")
                
                // Critical failure - report and crash
                _Concurrency.Task { @MainActor in
                    ErrorHandler.shared.handle(
                        AppError.database(.contextCreationFailed),
                        context: ErrorContext(
                            operation: "In-memory ModelContainer creation",
                            additionalInfo: ["error": error.localizedDescription]
                        ),
                        shouldPresent: true
                    )
                }
                
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup(makeContent: {
            ContentView()
                .environment(\.dependencyContainer, container)
                .withErrorHandling()
                .withErrorBanner()
                .task {
                    // Configure DI container with ModelContext
                    container.configure(modelContext: sharedModelContainer.mainContext)
                    
                    // Initialize recurring task maintenance on app launch
                    do {
                        let recurringService = container.recurringTaskService
                        await recurringService?.startRecurringTaskMaintenance()
                    } catch {
                        handleError(
                            error,
                            context: ErrorContext(operation: "Initializing recurring tasks")
                        )
                    }
                    
                    // Initialize LLM service and detect current model
                    do {
                        let llmService = container.llmService
                        await llmService?.initialize()
                    } catch {
                        handleError(
                            error,
                            context: ErrorContext(operation: "Initializing LLM service"),
                            shouldPresent: false // Silent failure for optional service
                        )
                    }
                }
        })
        .modelContainer(sharedModelContainer)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        .commands {
            DiligenceCommands()
        }
        
        // Add settings window
        Settings {
            DiligenceSettingsView()
                .environment(\.dependencyContainer, container)
                .withErrorHandling()
        }
        .windowResizability(.contentSize)
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error, context: ErrorContext, shouldPresent: Bool = true) {
        // Convert to AppError if possible, otherwise convert from Error
        let appError: AppError
        if let err = error as? AppError {
            appError = err
        } else {
            appError = AppError.from(error as NSError)
        }
        
        errorHandler.handle(
            appError,
            context: context,
            shouldPresent: shouldPresent
        )
    }
}
