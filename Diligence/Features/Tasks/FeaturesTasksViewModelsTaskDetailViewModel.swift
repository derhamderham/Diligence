//
//  TaskDetailViewModel.swift
//  Diligence
//
//  ViewModel for TaskDetailView - MVVM pattern
//

import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Task Detail ViewModel

/// View model managing the task detail/editing state
///
/// Handles task editing, validation, and updates
@MainActor
final class TaskDetailViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    private let taskService: TaskServiceProtocol
    private let task: DiligenceTask
    
    // MARK: - Published State
    
    /// Whether the task is being edited
    @Published var isEditing: Bool = false
    
    /// Edited task properties
    @Published var editedTitle: String
    @Published var editedDescription: String
    @Published var editedHasDueDate: Bool
    @Published var editedDueDate: Date
    @Published var editedSectionID: String?
    @Published var editedHasAmount: Bool
    @Published var editedAmount: String
    
    /// Recurrence properties
    @Published var editedRecurrencePattern: RecurrencePattern
    @Published var editedRecurrenceInterval: Int
    @Published var editedRecurrenceEndType: RecurrenceEndType
    @Published var editedRecurrenceEndDate: Date
    @Published var editedRecurrenceEndCount: Int
    @Published var editedRecurrenceWeekdays: [Int]
    
    /// Error state
    @Published var error: Error?
    
    /// Validation errors
    @Published var validationErrors: [String] = []
    
    // MARK: - Computed Properties
    
    /// Whether the form has unsaved changes
    var hasChanges: Bool {
        return editedTitle != task.title ||
               editedDescription != task.taskDescription ||
               (editedHasDueDate && editedDueDate != task.dueDate) ||
               editedSectionID != task.sectionID ||
               (editedHasAmount && Double(editedAmount) != task.amount) ||
               editedRecurrencePattern != task.recurrencePattern
    }
    
    /// Whether the form is valid
    var isValid: Bool {
        validateForm()
        return validationErrors.isEmpty
    }
    
    // MARK: - Initialization
    
    init(
        task: DiligenceTask,
        modelContext: ModelContext,
        taskService: TaskServiceProtocol? = nil
    ) {
        self.task = task
        self.modelContext = modelContext
        self.taskService = taskService ?? ServiceContainer.shared.taskService
        
        // Initialize edited values with current task values
        self.editedTitle = task.title
        self.editedDescription = task.taskDescription
        self.editedHasDueDate = task.dueDate != nil
        self.editedDueDate = task.dueDate ?? Date()
        self.editedSectionID = task.sectionID
        self.editedHasAmount = task.amount != nil
        self.editedAmount = task.amount != nil ? String(task.amount!) : ""
        
        // Recurrence
        self.editedRecurrencePattern = task.recurrencePattern
        self.editedRecurrenceInterval = task.recurrenceInterval
        self.editedRecurrenceEndType = task.recurrenceEndType
        self.editedRecurrenceEndDate = task.recurrenceEndDate ?? Date()
        self.editedRecurrenceEndCount = task.recurrenceEndCount ?? 10
        self.editedRecurrenceWeekdays = task.recurrenceWeekdays
    }
    
    // MARK: - Actions
    
    /// Starts editing mode
    func startEditing() {
        isEditing = true
    }
    
    /// Cancels editing and reverts changes
    func cancelEditing() {
        isEditing = false
        revertChanges()
    }
    
    /// Saves the edited task
    func saveChanges() {
        guard isValid else {
            print("⚠️ Form validation failed")
            return
        }
        
        // Apply changes to task
        task.title = editedTitle
        task.taskDescription = editedDescription
        task.dueDate = editedHasDueDate ? editedDueDate : nil
        task.sectionID = editedSectionID
        task.amount = editedHasAmount ? Double(editedAmount) : nil
        
        // Recurrence
        task.recurrencePattern = editedRecurrencePattern
        task.recurrenceInterval = editedRecurrenceInterval
        task.recurrenceEndType = editedRecurrenceEndType
        task.recurrenceEndDate = editedRecurrenceEndDate
        task.recurrenceEndCount = editedRecurrenceEndCount
        task.recurrenceWeekdays = editedRecurrenceWeekdays
        
        do {
            try taskService.updateTask(task, in: modelContext)
            isEditing = false
            
            // Trigger sync notification
            NotificationCenter.default.post(name: Notification.Name("TriggerRemindersSync"), object: nil)
        } catch {
            print("❌ Failed to save task: \(error)")
            self.error = error
        }
    }
    
    /// Toggles the task completion status
    func toggleCompletion() {
        do {
            try taskService.toggleCompletion(for: task, in: modelContext)
            
            // Trigger sync notification
            NotificationCenter.default.post(name: Notification.Name("TriggerRemindersSync"), object: nil)
        } catch {
            print("❌ Failed to toggle completion: \(error)")
            self.error = error
        }
    }
    
    /// Deletes the task
    func deleteTask() {
        do {
            try taskService.deleteTask(task, in: modelContext)
        } catch {
            print("❌ Failed to delete task: \(error)")
            self.error = error
        }
    }
    
    // MARK: - Private Methods
    
    /// Reverts all changes to original values
    private func revertChanges() {
        editedTitle = task.title
        editedDescription = task.taskDescription
        editedHasDueDate = task.dueDate != nil
        editedDueDate = task.dueDate ?? Date()
        editedSectionID = task.sectionID
        editedHasAmount = task.amount != nil
        editedAmount = task.amount != nil ? String(task.amount!) : ""
        editedRecurrencePattern = task.recurrencePattern
        editedRecurrenceInterval = task.recurrenceInterval
        editedRecurrenceEndType = task.recurrenceEndType
        editedRecurrenceEndDate = task.recurrenceEndDate ?? Date()
        editedRecurrenceEndCount = task.recurrenceEndCount ?? 10
        editedRecurrenceWeekdays = task.recurrenceWeekdays
    }
    
    /// Validates the form and updates validation errors
    ///
    /// - Returns: Whether the form is valid
    @discardableResult
    private func validateForm() -> Bool {
        validationErrors.removeAll()
        
        // Title is required
        if editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors.append("Title is required")
        }
        
        // Title length check
        if editedTitle.count > 500 {
            validationErrors.append("Title is too long (max 500 characters)")
        }
        
        // Amount validation
        if editedHasAmount {
            if let amount = Double(editedAmount) {
                if amount < 0 {
                    validationErrors.append("Amount cannot be negative")
                }
            } else {
                validationErrors.append("Invalid amount format")
            }
        }
        
        // Recurrence validation
        if editedRecurrencePattern != .never {
            if !editedHasDueDate {
                validationErrors.append("Recurring tasks must have a due date")
            }
            
            if editedRecurrenceInterval < 1 {
                validationErrors.append("Recurrence interval must be at least 1")
            }
            
            if editedRecurrenceEndType == .afterCount && editedRecurrenceEndCount < 1 {
                validationErrors.append("End count must be at least 1")
            }
            
            if editedRecurrenceEndType == .onDate && editedRecurrenceEndDate <= Date() {
                validationErrors.append("End date must be in the future")
            }
        }
        
        return validationErrors.isEmpty
    }
    
    // MARK: - Error Handling
    
    /// Clears the current error
    func clearError() {
        error = nil
    }
}
