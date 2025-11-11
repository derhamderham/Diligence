//
//  TaskServiceProtocol.swift
//  Diligence
//
//  Protocol definitions for task service implementations
//

import Foundation
import SwiftData

// MARK: - Task Service Protocol

/// Protocol defining the contract for task service implementations
///
/// Task services manage task operations, including creation, updates,
/// deletion, and synchronization with external services.
///
/// ## Topics
///
/// ### CRUD Operations
/// - ``createTask(_:in:)``
/// - ``updateTask(_:in:)``
/// - ``deleteTask(_:in:)``
/// - ``fetchTasks(matching:in:)``
///
/// ### Specialized Operations
/// - ``duplicateTask(_:in:)``
/// - ``toggleCompletion(for:in:)``
/// - ``bulkComplete(_:in:)``
/// - ``bulkDelete(_:in:)``
protocol TaskServiceProtocol: AnyObject {
    /// Creates a new task
    ///
    /// - Parameters:
    ///   - task: The task to create
    ///   - context: The model context
    /// - Throws: ``TaskServiceError`` if creation fails
    func createTask(_ task: DiligenceTask, in context: ModelContext) throws
    
    /// Updates an existing task
    ///
    /// - Parameters:
    ///   - task: The task to update
    ///   - context: The model context
    /// - Throws: ``TaskServiceError`` if update fails
    func updateTask(_ task: DiligenceTask, in context: ModelContext) throws
    
    /// Deletes a task
    ///
    /// - Parameters:
    ///   - task: The task to delete
    ///   - context: The model context
    /// - Throws: ``TaskServiceError`` if deletion fails
    func deleteTask(_ task: DiligenceTask, in context: ModelContext) throws
    
    /// Fetches tasks matching a predicate
    ///
    /// - Parameters:
    ///   - predicate: Optional predicate to filter tasks
    ///   - context: The model context
    /// - Returns: Array of matching tasks
    /// - Throws: ``TaskServiceError`` if fetch fails
    func fetchTasks(
        matching predicate: Predicate<DiligenceTask>?,
        in context: ModelContext
    ) throws -> [DiligenceTask]
    
    /// Duplicates a task
    ///
    /// - Parameters:
    ///   - task: The task to duplicate
    ///   - context: The model context
    /// - Returns: The duplicated task
    /// - Throws: ``TaskServiceError`` if duplication fails
    func duplicateTask(_ task: DiligenceTask, in context: ModelContext) throws -> DiligenceTask
    
    /// Toggles the completion status of a task
    ///
    /// - Parameters:
    ///   - task: The task to toggle
    ///   - context: The model context
    /// - Throws: ``TaskServiceError`` if toggle fails
    func toggleCompletion(for task: DiligenceTask, in context: ModelContext) throws
    
    /// Marks multiple tasks as complete
    ///
    /// - Parameters:
    ///   - tasks: The tasks to complete
    ///   - context: The model context
    /// - Throws: ``TaskServiceError`` if operation fails
    func bulkComplete(_ tasks: [DiligenceTask], in context: ModelContext) throws
    
    /// Deletes multiple tasks
    ///
    /// - Parameters:
    ///   - tasks: The tasks to delete
    ///   - context: The model context
    /// - Throws: ``TaskServiceError`` if deletion fails
    func bulkDelete(_ tasks: [DiligenceTask], in context: ModelContext) throws
}

// MARK: - Recurring Task Service Protocol

/// Protocol for managing recurring task operations
///
/// Recurring task services handle the creation and management of
/// recurring task instances based on recurrence patterns.
@MainActor
protocol RecurringTaskServiceProtocol: AnyObject {
    /// The model context for persistence
    var modelContext: ModelContext { get }
    
    /// Starts automatic recurring task maintenance
    ///
    /// This should be called on app launch to begin monitoring for
    /// recurring tasks that need new instances generated.
    func startRecurringTaskMaintenance() async
    
    /// Stops automatic recurring task maintenance
    func stopRecurringTaskMaintenance()
    
    /// Generates recurring instances for a task up to a date
    ///
    /// - Parameters:
    ///   - task: The recurring task
    ///   - endDate: Generate instances up to this date
    /// - Returns: Array of generated task instances
    /// - Throws: ``TaskServiceError`` if generation fails
    func generateInstances(for task: DiligenceTask, until endDate: Date) throws -> [DiligenceTask]
    
    /// Generates the next instance for a recurring task
    ///
    /// - Parameter task: The recurring task
    /// - Returns: The next task instance, or `nil` if recurrence has ended
    /// - Throws: ``TaskServiceError`` if generation fails
    func generateNextInstance(for task: DiligenceTask) throws -> DiligenceTask?
    
    /// Cleans up old completed recurring instances
    ///
    /// - Parameter olderThan: Delete instances completed before this date
    /// - Returns: Number of instances deleted
    /// - Throws: ``TaskServiceError`` if cleanup fails
    func cleanupOldInstances(olderThan date: Date) throws -> Int
    
    /// Finds all recurring tasks that need new instances
    ///
    /// - Returns: Array of tasks needing instances
    /// - Throws: ``TaskServiceError`` if fetch fails
    func findTasksNeedingInstances() throws -> [DiligenceTask]
}

// MARK: - Reminders Sync Service Protocol

/// Protocol for synchronizing tasks with Apple Reminders
///
/// Reminders services handle bidirectional sync between Diligence tasks
/// and the system Reminders app.
@MainActor
protocol RemindersSyncServiceProtocol: AnyObject {
    /// Whether the service has been authorized to access Reminders
    var isAuthorized: Bool { get }
    
    /// Current synchronization status
    var syncStatus: SyncStatus { get }
    
    /// Requests authorization to access Reminders
    ///
    /// - Returns: `true` if authorization was granted
    func requestAuthorization() async -> Bool
    
    /// Synchronizes all tasks with Reminders
    ///
    /// - Parameter context: The model context
    /// - Throws: ``TaskServiceError`` if sync fails
    func syncAllTasks(in context: ModelContext) async throws
    
    /// Synchronizes a single task with Reminders
    ///
    /// - Parameters:
    ///   - task: The task to sync
    ///   - context: The model context
    /// - Throws: ``TaskServiceError`` if sync fails
    func syncTask(_ task: DiligenceTask, in context: ModelContext) async throws
    
    /// Imports a reminder as a task
    ///
    /// - Parameters:
    ///   - reminderId: The reminder identifier
    ///   - context: The model context
    /// - Returns: The imported task
    /// - Throws: ``TaskServiceError`` if import fails
    func importReminder(_ reminderId: String, in context: ModelContext) async throws -> DiligenceTask
    
    /// Deletes a task from Reminders
    ///
    /// - Parameter task: The task whose reminder should be deleted
    /// - Throws: ``TaskServiceError`` if deletion fails
    func deleteReminder(for task: DiligenceTask) async throws
    
    /// Fetches all available reminder lists
    ///
    /// - Returns: Array of reminder lists
    /// - Throws: ``TaskServiceError`` if fetch fails
    func fetchReminderLists() async throws -> [ReminderList]
    
    /// Creates a new reminder list
    ///
    /// - Parameter title: The list title
    /// - Returns: The created list
    /// - Throws: ``TaskServiceError`` if creation fails
    func createReminderList(title: String) async throws -> ReminderList
}

// MARK: - Task Service Error

/// Errors that can occur during task service operations
enum TaskServiceError: LocalizedError {
    /// Task not found
    case taskNotFound(String)
    
    /// Invalid task data
    case invalidTaskData(String)
    
    /// Context is not available
    case contextUnavailable
    
    /// Save operation failed
    case saveFailed(Error)
    
    /// Fetch operation failed
    case fetchFailed(Error)
    
    /// Delete operation failed
    case deleteFailed(Error)
    
    /// Task validation failed
    case validationFailed(String)
    
    /// Recurring task error
    case recurringTaskError(String)
    
    /// Reminders authorization denied
    case authorizationDenied
    
    /// Reminders sync failed
    case syncFailed(Error)
    
    /// Reminder not found
    case reminderNotFound(String)
    
    /// Cannot create reminder
    case cannotCreateReminder(String)
    
    /// Unknown error
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .taskNotFound(let id):
            return "Task not found: \(id)"
        case .invalidTaskData(let message):
            return "Invalid task data: \(message)"
        case .contextUnavailable:
            return "Model context is not available."
        case .saveFailed(let error):
            return "Failed to save task: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch tasks: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete task: \(error.localizedDescription)"
        case .validationFailed(let message):
            return "Task validation failed: \(message)"
        case .recurringTaskError(let message):
            return "Recurring task error: \(message)"
        case .authorizationDenied:
            return "Access to Reminders was denied. Please enable access in System Settings."
        case .syncFailed(let error):
            return "Failed to sync with Reminders: \(error.localizedDescription)"
        case .reminderNotFound(let id):
            return "Reminder not found: \(id)"
        case .cannotCreateReminder(let reason):
            return "Cannot create reminder: \(reason)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .taskNotFound:
            return "The task may have been deleted. Try refreshing the list."
        case .invalidTaskData:
            return "Check that all required fields are filled in correctly."
        case .contextUnavailable:
            return "Restart the app and try again."
        case .authorizationDenied:
            return "Go to System Settings > Privacy & Security > Reminders and enable access for Diligence."
        case .syncFailed:
            return "Check that the Reminders app is working and try again."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
}

// MARK: - Supporting Types

/// Represents a reminder list from Apple Reminders
struct ReminderList: Identifiable {
    /// Unique identifier
    let id: String
    
    /// List title
    let title: String
    
    /// List color (if available)
    let color: String?
    
    /// Number of reminders in the list
    let reminderCount: Int
}

/// Synchronization status for Reminders integration
enum SyncStatus: Equatable {
    /// Not syncing
    case idle
    
    /// Currently syncing
    case syncing
    
    /// Sync completed successfully
    case success(taskCount: Int)
    
    /// Sync failed with error
    case failure(message: String)
    
    /// Human-readable text
    var displayText: String {
        switch self {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing..."
        case .success(let count):
            return "Synced \(count) task\(count == 1 ? "" : "s")"
        case .failure(let message):
            return "Sync failed: \(message)"
        }
    }
}

// MARK: - Task Validation Protocol

/// Protocol for validating task data
protocol TaskValidationProtocol {
    /// Validates a task before saving
    ///
    /// - Parameter task: The task to validate
    /// - Returns: `true` if valid
    /// - Throws: ``TaskServiceError.validationFailed`` if invalid
    func validate(_ task: DiligenceTask) throws -> Bool
    
    /// Validates recurrence settings
    ///
    /// - Parameter task: The task with recurrence settings
    /// - Returns: `true` if valid
    /// - Throws: ``TaskServiceError.validationFailed`` if invalid
    func validateRecurrence(for task: DiligenceTask) throws -> Bool
}

/// Default task validator
struct TaskValidator: TaskValidationProtocol {
    func validate(_ task: DiligenceTask) throws -> Bool {
        // Title is required
        guard !task.title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw TaskServiceError.validationFailed("Task title is required")
        }
        
        // Title should not be too long
        guard task.title.count <= 500 else {
            throw TaskServiceError.validationFailed("Task title is too long (max 500 characters)")
        }
        
        // If has amount, it should be valid
        if let amount = task.amount {
            guard amount >= 0 else {
                throw TaskServiceError.validationFailed("Amount cannot be negative")
            }
        }
        
        // Validate recurrence if set
        if task.isRecurring {
            try validateRecurrence(for: task)
        }
        
        return true
    }
    
    func validateRecurrence(for task: DiligenceTask) throws -> Bool {
        // Must have a due date for recurring tasks
        guard task.dueDate != nil else {
            throw TaskServiceError.validationFailed("Recurring tasks must have a due date")
        }
        
        // Interval must be positive
        guard task.recurrenceInterval > 0 else {
            throw TaskServiceError.validationFailed("Recurrence interval must be positive")
        }
        
        // Validate end conditions
        switch task.recurrenceEndType {
        case .afterCount:
            guard let count = task.recurrenceEndCount, count > 0 else {
                throw TaskServiceError.validationFailed("Recurrence count must be positive")
            }
        case .onDate:
            guard let endDate = task.recurrenceEndDate else {
                throw TaskServiceError.validationFailed("Recurrence end date is required")
            }
            guard endDate > Date() else {
                throw TaskServiceError.validationFailed("Recurrence end date must be in the future")
            }
        case .never:
            break
        }
        
        // Validate custom weekdays
        if task.recurrencePattern == .weekly && !task.recurrenceWeekdays.isEmpty {
            let validWeekdays = task.recurrenceWeekdays.allSatisfy { (1...7).contains($0) }
            guard validWeekdays else {
                throw TaskServiceError.validationFailed("Invalid weekday values (must be 1-7)")
            }
        }
        
        return true
    }
}
