//
//  CreateTaskViewModel.swift
//  Diligence
//
//  ViewModel for creating new tasks - MVVM pattern
//

import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Create Task ViewModel

/// View model managing new task creation
///
/// Handles form state, validation, and task creation
@MainActor
final class CreateTaskViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    private let taskService: TaskServiceProtocol
    private let onTaskCreated: ((DiligenceTask) -> Void)?
    
    // MARK: - Published State
    
    /// Form fields
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var hasDueDate: Bool = false
    @Published var dueDate: Date = Date().addingTimeInterval(86400) // Tomorrow
    @Published var selectedSectionID: String? = nil
    @Published var hasAmount: Bool = false
    @Published var amount: String = ""
    @Published var priority: TaskPriority = .medium
    
    /// Recurrence fields
    @Published var recurrencePattern: RecurrencePattern = .never
    @Published var recurrenceInterval: Int = 1
    @Published var recurrenceEndType: RecurrenceEndType = .never
    @Published var recurrenceEndDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @Published var recurrenceEndCount: Int = 10
    @Published var recurrenceWeekdays: [Int] = []
    
    /// Email-related fields (for tasks created from emails)
    @Published var emailID: String?
    @Published var emailSubject: String?
    @Published var emailSender: String?
    @Published var gmailURL: String?
    
    /// UI State
    @Published var isCreating: Bool = false
    @Published var error: Error?
    @Published var validationErrors: [String] = []
    
    // MARK: - Computed Properties
    
    /// Whether the form is valid
    var isValid: Bool {
        validateForm()
        return validationErrors.isEmpty
    }
    
    /// Whether this task will be recurring
    var isRecurring: Bool {
        return recurrencePattern != .never
    }
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        taskService: TaskServiceProtocol? = nil,
        onTaskCreated: ((DiligenceTask) -> Void)? = nil
    ) {
        self.modelContext = modelContext
        self.taskService = taskService ?? ServiceContainer.shared.taskService
        self.onTaskCreated = onTaskCreated
    }
    
    /// Initializes with pre-filled data from an email
    ///
    /// - Parameters:
    ///   - email: The email to create a task from
    ///   - modelContext: Model context
    ///   - taskService: Task service
    ///   - onTaskCreated: Callback when task is created
    convenience init(
        email: ProcessedEmail,
        modelContext: ModelContext,
        taskService: TaskServiceProtocol? = nil,
        onTaskCreated: ((DiligenceTask) -> Void)? = nil
    ) {
        self.init(modelContext: modelContext, taskService: taskService, onTaskCreated: onTaskCreated)
        
        // Pre-fill from email
        self.title = email.subject
        self.description = email.snippet
        self.emailID = email.id
        self.emailSubject = email.subject
        self.emailSender = email.senderEmail
        self.gmailURL = email.gmailURL.absoluteString
    }
    
    // MARK: - Actions
    
    /// Creates the task
    func createTask() {
        guard isValid else {
            print("⚠️ Form validation failed")
            return
        }
        
        isCreating = true
        
        // Parse amount if provided
        let parsedAmount: Double? = hasAmount ? Double(amount) : nil
        
        // Create the task
        let task = DiligenceTask(
            title: title,
            taskDescription: description,
            isCompleted: false,
            createdDate: Date(),
            dueDate: hasDueDate ? dueDate : nil,
            emailID: emailID,
            emailSubject: emailSubject,
            emailSender: emailSender,
            gmailURL: gmailURL,
            sectionID: selectedSectionID,
            amount: parsedAmount,
            priority: priority,
            recurrencePattern: recurrencePattern,
            recurrenceInterval: recurrenceInterval,
            recurrenceEndType: recurrenceEndType,
            recurrenceEndDate: recurrenceEndDate,
            recurrenceEndCount: recurrenceEndCount,
            recurrenceWeekdays: recurrenceWeekdays
        )
        
        do {
            try taskService.createTask(task, in: modelContext)
            
            // Generate recurring instances if needed
            if task.isRecurring {
                generateRecurringInstances(for: task)
            }
            
            // Trigger sync notification
            NotificationCenter.default.post(name: Notification.Name("TriggerRemindersSync"), object: nil)
            
            // Callback with created task
            onTaskCreated?(task)
            
            // Reset form
            clearForm()
            
            isCreating = false
        } catch {
            print("❌ Failed to create task: \(error)")
            self.error = error
            isCreating = false
        }
    }
    
    /// Clears the form
    func clearForm() {
        title = ""
        description = ""
        hasDueDate = false
        dueDate = Date().addingTimeInterval(86400)
        selectedSectionID = nil
        hasAmount = false
        amount = ""
        priority = .medium
        recurrencePattern = .never
        recurrenceInterval = 1
        recurrenceEndType = .never
        recurrenceEndDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
        recurrenceEndCount = 10
        recurrenceWeekdays = []
        emailID = nil
        emailSubject = nil
        emailSender = nil
        gmailURL = nil
        validationErrors = []
    }
    
    // MARK: - Validation
    
    /// Validates the form
    ///
    /// - Returns: Whether the form is valid
    @discardableResult
    private func validateForm() -> Bool {
        validationErrors.removeAll()
        
        // Title is required
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            validationErrors.append("Title is required")
        }
        
        // Title length check
        if title.count > 500 {
            validationErrors.append("Title is too long (max 500 characters)")
        }
        
        // Amount validation
        if hasAmount {
            if let parsedAmount = Double(amount) {
                if parsedAmount < 0 {
                    validationErrors.append("Amount cannot be negative")
                }
            } else {
                validationErrors.append("Invalid amount format")
            }
        }
        
        // Recurrence validation
        if recurrencePattern != .never {
            if !hasDueDate {
                validationErrors.append("Recurring tasks must have a due date")
            }
            
            if recurrenceInterval < 1 {
                validationErrors.append("Recurrence interval must be at least 1")
            }
            
            if recurrenceEndType == .afterCount && recurrenceEndCount < 1 {
                validationErrors.append("End count must be at least 1")
            }
            
            if recurrenceEndType == .onDate && recurrenceEndDate <= Date() {
                validationErrors.append("End date must be in the future")
            }
            
            if recurrencePattern == .weekly && !recurrenceWeekdays.isEmpty {
                let validWeekdays = recurrenceWeekdays.allSatisfy { (1...7).contains($0) }
                if !validWeekdays {
                    validationErrors.append("Invalid weekday values")
                }
            }
        }
        
        return validationErrors.isEmpty
    }
    
    // MARK: - Private Methods
    
    /// Generates recurring instances for the task
    private func generateRecurringInstances(for task: DiligenceTask) {
        guard task.isRecurring else { return }
        
        let recurringService = RecurringTaskService(modelContext: modelContext)
        let endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        
        do {
            let instances = try recurringService.generateInstances(for: task, until: endDate)
            print("✅ Generated \(instances.count) recurring instances")
            
            // Notify that recurring tasks were updated
            NotificationCenter.default.post(name: Notification.Name("RecurringTasksUpdated"), object: nil)
        } catch {
            print("❌ Failed to generate recurring instances: \(error)")
        }
    }
    
    // MARK: - Error Handling
    
    /// Clears the current error
    func clearError() {
        error = nil
    }
}

// MARK: - Convenience Initializers

extension CreateTaskViewModel {
    /// Creates a view model for preview
    static func preview(modelContext: ModelContext) -> CreateTaskViewModel {
        return CreateTaskViewModel(modelContext: modelContext)
    }
}
