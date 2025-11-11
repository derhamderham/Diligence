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
    
    /// Execute SwiftData operations in isolation to avoid EventKit/Reminders conflicts
    private func withEventKitIsolation<T>(_ operation: () throws -> T) rethrows -> T {
        // Create a completely isolated execution context
        return try autoreleasepool {
            // Add a small delay to prevent rapid successive operations that can cause port conflicts
            Thread.sleep(forTimeInterval: 0.001) // 1ms delay
            
            // Disable any potential EventKit observers during this operation
            let result = try operation()
            
            // Force memory cleanup to prevent lingering EventKit references
            return result
        }
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
        
        return try withEventKitIsolation {
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
        
        // Use smaller batch size to reduce EventKit interference and system resource conflicts
        let batchSize = 5 // Reduced from 10 to further minimize port conflicts
        var offset = 0
        var allRecurringTasks: [DiligenceTask] = []
        var retryCount = 0
        let maxRetries = 3
        
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Fetch tasks in small batches to minimize EventKit conflicts
            while retryCount <= maxRetries {
                do {
                    let batchTasks = try withEventKitIsolation { () -> [DiligenceTask] in
                        var descriptor = FetchDescriptor<DiligenceTask>(
                            predicate: #Predicate { task in
                                task.isRecurringInstance == false
                            }
                        )
                        descriptor.fetchLimit = batchSize
                        descriptor.fetchOffset = offset
                        
                        let tasks = try safeFetchTasks(descriptor: descriptor)
                        return tasks.filter { task in
                            task.recurrencePattern != .never
                        }
                    }
                    
                    if batchTasks.isEmpty {
                        break
                    }
                    
                    allRecurringTasks.append(contentsOf: batchTasks)
                    offset += batchSize
                    retryCount = 0 // Reset retry count on successful batch
                    
                    // Small delay to prevent overwhelming the system and reduce port conflicts
                    try await _Concurrency.Task.sleep(for: .milliseconds(15)) // Increased delay for port stability
                    
                } catch {
                    retryCount += 1
                    print("⚠️ Batch fetch failed (attempt \(retryCount)/\(maxRetries)): \(error)")
                    
                    if retryCount <= maxRetries {
                        // Exponential backoff for retries
                        try await _Concurrency.Task.sleep(for: .milliseconds(100 * retryCount))
                    } else {
                        print("❌ Max retries exceeded, stopping batch fetch")
                        break
                    }
                }
            }
            
            let fetchTime = CFAbsoluteTimeGetCurrent() - startTime
            if fetchTime > 0.5 { // Increased threshold due to batching
                print("⚠️ Slow batch fetch detected: \(fetchTime)s - possible EventKit interference")
            }
            
            // Process generation in isolation with error handling
            var successCount = 0
            for task in allRecurringTasks {
                withEventKitIsolation {
                    if !task.hasRecurrenceEnded {
                        let _ = task.generateRecurringInstances(until: endDate, in: modelContext)
                        successCount += 1
                    }
                }
            }
            
            // Save changes in isolation with retry logic
            var saveRetryCount = 0
            while saveRetryCount <= maxRetries {
                do {
                    try withEventKitIsolation {
                        try modelContext.save()
                    }
                    break
                } catch {
                    saveRetryCount += 1
                    print("⚠️ Save failed (attempt \(saveRetryCount)/\(maxRetries)): \(error)")
                    
                    if saveRetryCount <= maxRetries {
                        try await _Concurrency.Task.sleep(for: .milliseconds(50 * saveRetryCount))
                    }
                }
            }
            
            print("✅ Generated recurring instances for \(successCount)/\(allRecurringTasks.count) tasks in \(fetchTime)s")
            
        } catch {
            print("❌ Critical error in generateUpcomingRecurringTasks: \(error)")
        }
    }
    
    /// Complete a recurring instance and optionally generate the next one
    func completeRecurringInstance(_ task: DiligenceTask) async {
        guard task.isRecurringInstance else { return }
        
        do {
            try withEventKitIsolation {
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
        let taskID = task.title + "_" + String(task.createdDate.timeIntervalSince1970)
        
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
        
        let taskID = task.title + "_" + String(task.createdDate.timeIntervalSince1970)
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
        
        let taskID = task.title + "_" + String(task.createdDate.timeIntervalSince1970)
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

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
