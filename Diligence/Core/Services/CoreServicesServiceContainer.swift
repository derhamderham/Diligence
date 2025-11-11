//
//  ServiceContainer.swift
//  Diligence
//
//  Central service container for dependency injection
//

import Foundation
import SwiftData

/// Service container providing centralized access to all app services
///
/// This singleton provides lazy-loaded instances of all app services,
/// enabling dependency injection and testability across the app.
///
/// ## Usage
///
/// ```swift
/// // Access services
/// let emailService = ServiceContainer.shared.emailService
/// let taskService = ServiceContainer.shared.taskService
///
/// // Inject into view models
/// let viewModel = GmailViewModel(
///     emailService: ServiceContainer.shared.emailService,
///     modelContext: context
/// )
/// ```
///
/// ## Topics
///
/// ### Services
/// - ``emailService``
/// - ``taskService``
/// - ``aiService``
/// - ``remindersService``
/// - ``recurringService``
///
/// ### Configuration
/// - ``shared``
/// - ``reset()``
@MainActor
final class ServiceContainer {
    
    // MARK: - Singleton
    
    /// Shared service container instance
    static let shared = ServiceContainer()
    
    // MARK: - Services
    
    /// Email service for Gmail integration
    ///
    /// Provides:
    /// - Gmail authentication
    /// - Email fetching and pagination
    /// - Message details and attachments
    lazy var emailService: EmailServiceProtocol = {
        // TODO: Replace with actual GmailService implementation
        // For now, return a mock or placeholder
        fatalError("GmailService not yet implemented. Please implement GmailService conforming to EmailServiceProtocol")
    }()
    
    /// Task service for CRUD operations
    ///
    /// Provides:
    /// - Task creation, reading, updating, deletion
    /// - Bulk operations
    /// - Validation
    lazy var taskService: TaskServiceProtocol = {
        // TODO: Replace with actual TaskService implementation
        fatalError("TaskService not yet implemented. Please implement TaskService conforming to TaskServiceProtocol")
    }()
    
    /// AI service for intelligent task generation
    ///
    /// Provides:
    /// - Task generation from emails
    /// - Email summarization
    /// - Action extraction
    lazy var aiService: AIServiceProtocol = {
        // TODO: Replace with actual AIService implementation
        fatalError("AIService not yet implemented. Please implement AIService conforming to AIServiceProtocol")
    }()
    
    /// Reminders service for EventKit synchronization
    ///
    /// Provides:
    /// - Bidirectional sync with Apple Reminders
    /// - Authorization handling
    /// - Import/export functionality
    lazy var remindersService: RemindersSyncServiceProtocol = {
        // TODO: Replace with actual RemindersService implementation
        fatalError("RemindersService not yet implemented. Please implement RemindersService conforming to RemindersSyncServiceProtocol")
    }()
    
    /// Recurring task service for automated task generation
    ///
    /// Provides:
    /// - Recurring task instance generation
    /// - Maintenance and cleanup
    /// - Schedule management
    lazy var recurringService: RecurringTaskServiceProtocol = {
        // TODO: Replace with actual RecurringTaskService implementation
        fatalError("RecurringTaskService not yet implemented. Please implement RecurringTaskService conforming to RecurringTaskServiceProtocol")
    }()
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern
    private init() {
        print("✅ ServiceContainer initialized")
    }
    
    // MARK: - Configuration
    
    /// Resets all services (useful for testing)
    ///
    /// This will force all lazy properties to reinitialize on next access
    func reset() {
        print("🔄 ServiceContainer reset")
        // Note: In Swift, we can't easily reset lazy properties
        // For testing, create a new ServiceContainer instance instead
    }
}

// MARK: - Testing Support

extension ServiceContainer {
    /// Creates a test container with mock services
    ///
    /// - Parameters:
    ///   - emailService: Mock email service
    ///   - taskService: Mock task service
    ///   - aiService: Mock AI service
    ///   - remindersService: Mock reminders service
    ///   - recurringService: Mock recurring task service
    /// - Returns: Configured service container for testing
    @MainActor
    static func mock(
        emailService: EmailServiceProtocol? = nil,
        taskService: TaskServiceProtocol? = nil,
        aiService: AIServiceProtocol? = nil,
        remindersService: RemindersSyncServiceProtocol? = nil,
        recurringService: RecurringTaskServiceProtocol? = nil
    ) -> ServiceContainer {
        // For testing, you would create a TestServiceContainer
        // that allows injecting mock services
        fatalError("Mock service container not yet implemented")
    }
}
