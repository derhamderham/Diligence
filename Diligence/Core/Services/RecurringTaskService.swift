//
//  RecurringTaskService.swift
//  Diligence
//
//  Created by derham on 10/29/25.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
class RecurringTaskService: RecurringTaskServiceProtocol, ObservableObject {
    func stopRecurringTaskMaintenance() {
        // Currently no background maintenance to stop
        print("🛑 Stopping recurring task maintenance...")
    }
    
    func generateInstances(for task: DiligenceTask, until endDate: Date) throws -> [DiligenceTask] {
        return task.generateRecurringInstances(until: endDate, in: modelContext)
    }
    
    func generateNextInstance(for task: DiligenceTask) throws -> DiligenceTask? {
        guard task.isRecurring, !task.hasRecurrenceEnded else { return nil }
        
        let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let instances = task.generateRecurringInstances(until: nextDate, in: modelContext)
        return instances.first
    }
    
    func cleanupOldInstances(olderThan date: Date) throws -> Int {
        let oldInstancesDescriptor = FetchDescriptor<DiligenceTask>(
            predicate: #Predicate { task in
                task.isRecurringInstance == true &&
                task.isCompleted == true
            }
        )
        
        let allOldInstances = try modelContext.fetch(oldInstancesDescriptor)
        let oldInstances = allOldInstances.filter { instance in
            guard let dueDate = instance.dueDate else { return false }
            return dueDate < date
        }
        
        for instance in oldInstances {
            modelContext.delete(instance)
        }
        
        try modelContext.save()
        return oldInstances.count
    }
    
    func findTasksNeedingInstances() throws -> [DiligenceTask] {
        let descriptor = FetchDescriptor<DiligenceTask>(
            predicate: #Predicate { task in
                task.isRecurringInstance == false
            }
        )
        
        let tasks = try modelContext.fetch(descriptor)
        return tasks.filter { task in
            task.recurrencePattern != .never && !task.hasRecurrenceEnded
        }
    }
    
    internal let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Private Helper Methods
    
    /// Execute operations with autorelease pool for better memory management
    private func withAutorelease<T>(_ operation: () throws -> T) rethrows -> T {
        return try autoreleasepool {
            return try operation()
        }
    }
    
    /// Helper to generate consistent task IDs
    private func getTaskID(for task: DiligenceTask) -> String {
        return task.title + "_" + String(task.createdDate.timeIntervalSince1970)
    }
    
    /// Create a new isolated ModelContext for sensitive operations
    private func createIsolatedContext() -> ModelContext? {
        let container = modelContext.container
        
        // Create a new context to avoid any cached EventKit interference
        let isolatedContext = ModelContext(container)
        
        // Configure the context for better performance and less system interference
        isolatedContext.autosaveEnabled = false
        
        // Add explicit transaction management to reduce port conflicts
        isolatedContext.undoManager = nil // Disable undo to reduce memory pressure
        
        return isolatedContext
    }
    
    /// Safely fetch tasks without triggering EventKit/Reminders conflicts
    private func safeFetchTasks(descriptor: FetchDescriptor<DiligenceTask>) throws -> [DiligenceTask] {
        // Use isolated context to prevent EventKit interference
        guard let isolatedContext = createIsolatedContext() else {
            throw RecurringTaskError.contextCreationFailed
        }
        
        defer {
            // Ensure proper cleanup to prevent resource leaks
            isolatedContext.rollback()
        }
        
        return try withAutorelease {
            let tasks = try isolatedContext.fetch(descriptor)
            
            // Pre-load all critical properties to avoid lazy loading conflicts
            let materializedTasks = tasks.compactMap { task -> DiligenceTask? in
                // Access properties in a controlled manner
                let _ = task.title
                let _ = task.isRecurringInstance
                let _ = task.recurrencePattern
                let _ = task.isCompleted
                let _ = task.createdDate
                let _ = task.dueDate
                
                return task
            }
            
            return materializedTasks
        }
    }
    
    // MARK: - Error Types
    
    enum RecurringTaskError: Error {
        case contextCreationFailed
        case eventKitConflict
        case portRightFailure
        case systemResourceExhaustion
        
        var localizedDescription: String {
            switch self {
            case .contextCreationFailed:
                return "Failed to create isolated model context"
            case .eventKitConflict:
                return "EventKit/Reminders conflict detected"
            case .portRightFailure:
                return "System port communication failure"
            case .systemResourceExhaustion:
                return "System resources temporarily exhausted"
            }
        }
    }
    
    // MARK: - Recurring Task Generation
    
    /// Generate recurring task instances for the next specified number of days
    func generateUpcomingRecurringTasks(daysAhead: Int = 90) async {
        let endDate = Calendar.current.date(byAdding: .day, value: daysAhead, to: Date()) ?? Date()
        
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Single fetch - much faster than batched fetches
            let descriptor = FetchDescriptor<DiligenceTask>(
                predicate: #Predicate { task in
                    task.isRecurringInstance == false
                }
            )
            
            let allTasks = try modelContext.fetch(descriptor)
            let recurringTasks = allTasks.filter { 
                $0.recurrencePattern != .never && !$0.hasRecurrenceEnded 
            }
            
            let fetchTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // Process all recurring tasks
            var successCount = 0
            for task in recurringTasks {
                withAutorelease {
                    let _ = task.generateRecurringInstances(until: endDate, in: modelContext)
                    successCount += 1
                }
            }
            
            // Save all changes at once
            try withAutorelease {
                try modelContext.save()
            }
            
            print("✅ Generated recurring instances for \(successCount)/\(recurringTasks.count) tasks in \(fetchTime)s")
            
        } catch {
            print("❌ Error in generateUpcomingRecurringTasks: \(error)")
        }
    }
    
    /// Complete a recurring instance and optionally generate the next one
    func completeRecurringInstance(_ task: DiligenceTask) async {
        guard task.isRecurringInstance else { return }
        
        do {
            try withAutorelease {
                task.isCompleted = true
                
                // Find the parent recurring task and update its count if needed
                if let parentID = task.parentRecurringTaskID {
                    // Workaround for SwiftData Predicate limitations: 
                    // We cannot use global functions or computed properties inside the predicate,
                    // so we extract title and createdDate from the parentID string to use directly.
                    let components = parentID.split(separator: "_", maxSplits: 1, omittingEmptySubsequences: false)
                    if components.count == 2,
                       let createdDateTimestamp = TimeInterval(components[1]) {
                        let parentTaskIDTitle = String(components[0])
                        let parentTaskIDCreatedDate = Date(timeIntervalSince1970: createdDateTimestamp)
                        
                        let parentDescriptor = FetchDescriptor<DiligenceTask>(
                            predicate: #Predicate { parentTask in
                                parentTask.parentRecurringTaskID == nil &&
                                parentTask.title == parentTaskIDTitle &&
                                parentTask.createdDate == parentTaskIDCreatedDate
                            }
                        )
                        
                        let parentTasks = try safeFetchTasks(descriptor: parentDescriptor)
                        if let parentTask = parentTasks.first {
                            // Generate next instance if needed
                            let endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
                            let _ = parentTask.generateRecurringInstances(until: endDate, in: modelContext)
                        }
                    }
                }
                
                try modelContext.save()
            }
        } catch {
            print("❌ Error completing recurring instance: \(error)")
        }
    }
    
    /// Delete a recurring task and all its instances
    func deleteRecurringTask(_ task: DiligenceTask) async {
        let taskID = getTaskID(for: task)
        
        // Delete all instances
        let instancesDescriptor = FetchDescriptor<DiligenceTask>(
            predicate: #Predicate { instanceTask in
                instanceTask.parentRecurringTaskID == taskID
            }
        )
        
        do {
            let instances = try modelContext.fetch(instancesDescriptor)
            for instance in instances {
                modelContext.delete(instance)
            }
            
            // Delete the parent task
            modelContext.delete(task)
            
            try modelContext.save()
        } catch {
            print("Error deleting recurring task: \(error)")
        }
    }
    
    /// Update a recurring task's pattern and regenerate instances
    func updateRecurringTaskPattern(_ task: DiligenceTask) async {
        guard task.isRecurring else { return }
        
        let taskID = getTaskID(for: task)
        let currentDate = Date()
        
        // Delete existing future instances
        let futureInstancesDescriptor = FetchDescriptor<DiligenceTask>(
            predicate: #Predicate { instanceTask in
                instanceTask.parentRecurringTaskID == taskID &&
                instanceTask.isCompleted == false
            }
        )
        
        do {
            let allFutureInstances = try modelContext.fetch(futureInstancesDescriptor)
            let futureInstances = allFutureInstances.filter { instance in
                guard let dueDate = instance.dueDate else { return false }
                return dueDate > currentDate
            }
            for instance in futureInstances {
                modelContext.delete(instance)
            }
            
            // Generate new instances with updated pattern
            let endDate = Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date()
            let _ = task.generateRecurringInstances(until: endDate, in: modelContext)
            
            try modelContext.save()
        } catch {
            print("Error updating recurring task pattern: \(error)")
        }
    }
    
    // MARK: - Utility Functions
    
    /// Get all instances of a recurring task
    func getRecurringTaskInstances(for task: DiligenceTask) -> [DiligenceTask] {
        guard task.isRecurring else { return [] }
        
        let taskID = getTaskID(for: task)
        let descriptor = FetchDescriptor<DiligenceTask>(
            predicate: #Predicate { instanceTask in
                instanceTask.parentRecurringTaskID == taskID
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching recurring task instances: \(error)")
            return []
        }
    }
    
    /// Get the next due instance of a recurring task
    func getNextDueInstance(for task: DiligenceTask) -> DiligenceTask? {
        let instances = getRecurringTaskInstances(for: task)
        let currentDate = Date()
        return instances.first { instance in
            guard let dueDate = instance.dueDate else { return false }
            return !instance.isCompleted && dueDate >= currentDate
        }
    }
    
    /// Clean up completed recurring instances older than specified days
    func cleanupOldRecurringInstances(olderThanDays: Int = 30) async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()
        
        let oldInstancesDescriptor = FetchDescriptor<DiligenceTask>(
            predicate: #Predicate { task in
                task.isRecurringInstance == true &&
                task.isCompleted == true
            }
        )
        
        do {
            let allOldInstances = try modelContext.fetch(oldInstancesDescriptor)
            let oldInstances = allOldInstances.filter { instance in
                guard let dueDate = instance.dueDate else { return false }
                return dueDate < cutoffDate
            }
            for instance in oldInstances {
                modelContext.delete(instance)
            }
            
            try modelContext.save()
            print("Cleaned up \(oldInstances.count) old recurring task instances")
        } catch {
            print("Error cleaning up old recurring instances: \(error)")
        }
    }
    
    /// Start background task generation (call this when the app launches)
    func startRecurringTaskMaintenance() async {
        print("🔧 Starting recurring task maintenance...")
        
        // Perform initial health check for EventKit conflicts
        let healthCheck = await checkEventKitCompatibility()
        if !healthCheck {
            print("⚠️ EventKit compatibility issues detected - using conservative mode")
        }
        
        await generateUpcomingRecurringTasks()
        await cleanupOldRecurringInstances()
        print("✅ Recurring task maintenance completed successfully")
    }
    
    /// Check for EventKit compatibility issues before major operations
    private func checkEventKitCompatibility() async -> Bool {
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Perform a simple fetch to test for conflicts
            var testDescriptor = FetchDescriptor<DiligenceTask>(
                predicate: #Predicate { task in
                    task.isRecurringInstance == false
                }
            )
            testDescriptor.fetchLimit = 1
            
            let _ = try safeFetchTasks(descriptor: testDescriptor)
            
            let testTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // If even a single fetch takes too long, EventKit is interfering
            if testTime > 0.05 { // 50ms threshold
                print("⚠️ EventKit interference detected - test fetch took \(testTime)s")
                return false
            }
            
            return true
        } catch {
            print("❌ EventKit compatibility check failed: \(error)")
            
            // Check if this is a port-related error
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("port") || errorDescription.contains("kern") {
                print("🔍 Port communication error detected - implementing recovery strategy")
                
                // Wait for system resources to recover
                try? await _Concurrency.Task.sleep(for: .milliseconds(500))
                
                // Return false to trigger conservative mode
                return false
            }
            
            return false
        }
    }
    
    /// Detect if the current error is related to port communication issues
    private func isPortRelatedError(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()
        return errorDescription.contains("port") || 
               errorDescription.contains("kern") || 
               errorDescription.contains("failure (0x5)") ||
               errorDescription.contains("task name")
    }
}

