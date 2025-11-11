//
//  Task.swift
//  Diligence
//
//  Core task model with support for recurring tasks and multi-source integration
//

import Foundation
import SwiftData

// MARK: - Diligence Task Model

/// The primary task model for the Diligence app
///
/// `DiligenceTask` represents a single task or to-do item, with support for:
/// - Basic task properties (title, description, completion status)
/// - Due dates and scheduling
/// - Email integration (Gmail)
/// - Apple Reminders synchronization
/// - Section organization
/// - Financial amounts (for bills and invoices)
/// - Recurring task patterns
///
/// ## Topics
///
/// ### Creating Tasks
/// - ``init(title:taskDescription:isCompleted:createdDate:dueDate:emailID:emailSubject:emailSender:gmailURL:reminderID:sectionID:amount:recurrencePattern:recurrenceInterval:recurrenceEndType:recurrenceEndDate:recurrenceEndCount:recurrenceWeekdays:parentRecurringTaskID:isRecurringInstance:recurringInstanceDate:)``
///
/// ### Task Properties
/// - ``title``
/// - ``taskDescription``
/// - ``isCompleted``
/// - ``createdDate``
/// - ``dueDate``
///
/// ### Email Integration
/// - ``emailID``
/// - ``emailSubject``
/// - ``emailSender``
/// - ``gmailURL``
/// - ``isFromEmail``
/// - ``gmailURLObject``
///
/// ### Reminders Sync
/// - ``reminderID``
/// - ``lastSyncedToReminders``
///
/// ### Organization
/// - ``sectionID``
///
/// ### Financial
/// - ``amount``
///
/// ### Recurrence
/// - ``recurrencePattern``
/// - ``recurrenceInterval``
/// - ``recurrenceEndType``
/// - ``recurrenceEndDate``
/// - ``recurrenceEndCount``
/// - ``currentRecurrenceCount``
/// - ``recurrenceWeekdays``
/// - ``parentRecurringTaskID``
/// - ``isRecurringInstance``
/// - ``recurringInstanceDate``
/// - ``isRecurring``
/// - ``hasRecurrenceEnded``
/// - ``nextDueDate``
/// - ``recurrenceDescription``
///
/// ### Methods
/// - ``calculateNextDueDate(from:)``
/// - ``generateRecurringInstances(until:in:)``
@Model
final class DiligenceTask {
    // MARK: - Core Properties
    
    /// The title or name of the task
    var title: String
    
    /// Detailed description or notes about the task
    var taskDescription: String
    
    /// Whether the task has been completed
    var isCompleted: Bool
    
    /// Date when the task was created
    var createdDate: Date
    
    /// Optional due date for the task
    var dueDate: Date?
    
    // MARK: - Gmail Integration Properties
    
    /// Gmail message ID if this task was created from an email
    var emailID: String?
    
    /// Subject line of the source email
    var emailSubject: String?
    
    /// Sender email address of the source email
    var emailSender: String?
    
    /// Deep link URL to open the email in Gmail
    var gmailURL: String?
    
    // MARK: - Reminders Sync Properties
    
    /// EventKit reminder identifier for syncing with Apple Reminders
    var reminderID: String?
    
    /// Last date this task was synchronized with Reminders
    var lastSyncedToReminders: Date?
    
    // MARK: - Organization Properties
    
    /// ID of the section this task belongs to
    ///
    /// Tasks can be organized into sections for better categorization.
    /// If `nil`, the task appears in the unsectioned area.
    var sectionID: String?
    
    // MARK: - Financial Properties
    
    /// Monetary amount associated with the task (for bills, invoices, etc.)
    var amount: Double?
    
    // MARK: - Recurrence Properties
    
    /// The pattern defining how this task repeats
    var recurrencePattern: RecurrencePattern = RecurrencePattern.never
    
    /// The interval multiplier for the recurrence pattern
    ///
    /// For example, `recurrenceInterval = 2` with `recurrencePattern = .weekly`
    /// means the task repeats every 2 weeks.
    var recurrenceInterval: Int = 1
    
    /// How the recurrence should end
    var recurrenceEndType: RecurrenceEndType = RecurrenceEndType.never
    
    /// The date when recurrence should stop (if using `.onDate` end type)
    var recurrenceEndDate: Date?
    
    /// Maximum number of recurrences (if using `.afterCount` end type)
    var recurrenceEndCount: Int?
    
    /// Current count of generated recurrence instances
    var currentRecurrenceCount: Int = 0
    
    /// Custom weekdays for weekly recurrence patterns
    ///
    /// Array of integers where 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    /// Stored as encoded Data for SwiftData compatibility.
    @Attribute(.transformable(by: "NSSecureUnarchiveFromDataTransformer"))
    var recurrenceWeekdaysData: Data = Data()
    
    /// Computed property for accessing custom weekdays
    var recurrenceWeekdays: [Int] {
        get {
            if recurrenceWeekdaysData.isEmpty { return [] }
            do {
                return try JSONDecoder().decode([Int].self, from: recurrenceWeekdaysData)
            } catch {
                print("Failed to decode recurrenceWeekdays: \(error)")
                return []
            }
        }
        set {
            do {
                recurrenceWeekdaysData = try JSONEncoder().encode(newValue)
            } catch {
                print("Failed to encode recurrenceWeekdays: \(error)")
                recurrenceWeekdaysData = Data()
            }
        }
    }
    
    // MARK: - Recurrence Relationship Properties
    
    /// ID of the parent recurring task (if this is a recurring instance)
    var parentRecurringTaskID: String?
    
    /// Whether this is an automatically generated instance of a recurring task
    var isRecurringInstance: Bool = false
    
    /// The specific date this recurring instance was created for
    var recurringInstanceDate: Date?
    
    // MARK: - Initialization
    
    /// Creates a new task
    ///
    /// - Parameters:
    ///   - title: The task title
    ///   - taskDescription: Optional detailed description
    ///   - isCompleted: Initial completion status (defaults to `false`)
    ///   - createdDate: Creation date (defaults to current date)
    ///   - dueDate: Optional due date
    ///   - emailID: Gmail message ID if created from email
    ///   - emailSubject: Subject of source email
    ///   - emailSender: Sender of source email
    ///   - gmailURL: Deep link to email in Gmail
    ///   - reminderID: EventKit reminder ID for sync
    ///   - sectionID: Section this task belongs to
    ///   - amount: Financial amount for the task
    ///   - recurrencePattern: How the task repeats
    ///   - recurrenceInterval: Interval multiplier for recurrence
    ///   - recurrenceEndType: How recurrence should end
    ///   - recurrenceEndDate: End date for recurrence
    ///   - recurrenceEndCount: Maximum recurrence count
    ///   - recurrenceWeekdays: Custom weekdays for weekly patterns
    ///   - parentRecurringTaskID: Parent task ID if this is a recurring instance
    ///   - isRecurringInstance: Whether this is a recurring instance
    ///   - recurringInstanceDate: Date this recurring instance represents
    init(title: String, 
         taskDescription: String = "", 
         isCompleted: Bool = false, 
         createdDate: Date = Date(),
         dueDate: Date? = nil,
         emailID: String? = nil,
         emailSubject: String? = nil,
         emailSender: String? = nil,
         gmailURL: String? = nil,
         reminderID: String? = nil,
         sectionID: String? = nil,
         amount: Double? = nil,
         recurrencePattern: RecurrencePattern = RecurrencePattern.never,
         recurrenceInterval: Int = 1,
         recurrenceEndType: RecurrenceEndType = RecurrenceEndType.never,
         recurrenceEndDate: Date? = nil,
         recurrenceEndCount: Int? = nil,
         recurrenceWeekdays: [Int] = [],
         parentRecurringTaskID: String? = nil,
         isRecurringInstance: Bool = false,
         recurringInstanceDate: Date? = nil) {
        self.title = title
        self.taskDescription = taskDescription
        self.isCompleted = isCompleted
        self.createdDate = createdDate
        self.dueDate = dueDate
        self.emailID = emailID
        self.emailSubject = emailSubject
        self.emailSender = emailSender
        self.gmailURL = gmailURL
        self.reminderID = reminderID
        self.sectionID = sectionID
        self.amount = amount
        self.recurrencePattern = recurrencePattern
        self.recurrenceInterval = recurrenceInterval
        self.recurrenceEndType = recurrenceEndType
        self.recurrenceEndDate = recurrenceEndDate
        self.recurrenceEndCount = recurrenceEndCount
        self.parentRecurringTaskID = parentRecurringTaskID
        self.isRecurringInstance = isRecurringInstance
        self.recurringInstanceDate = recurringInstanceDate
        
        // Set recurrenceWeekdays using the property setter for proper encoding
        self.recurrenceWeekdays = recurrenceWeekdays
    }
    
    // MARK: - Computed Properties
    
    /// Returns `true` if this task was created from a Gmail email
    var isFromEmail: Bool {
        return emailID != nil
    }
    
    /// URL object for opening the task's associated email in Gmail
    var gmailURLObject: URL? {
        guard let gmailURL = gmailURL else { return nil }
        return URL(string: gmailURL)
    }
    
    /// Returns `true` if this is a recurring task (not an instance)
    var isRecurring: Bool {
        return recurrencePattern != .never && !isRecurringInstance
    }
    
    /// Returns `true` if the recurrence has reached its end condition
    var hasRecurrenceEnded: Bool {
        guard isRecurring else { return false }
        
        switch recurrenceEndType {
        case .never:
            return false
        case .afterCount:
            guard let endCount = recurrenceEndCount else { return false }
            return currentRecurrenceCount >= endCount
        case .onDate:
            guard let endDate = recurrenceEndDate else { return false }
            return Date() > endDate
        }
    }
    
    /// The next scheduled due date for this recurring task
    var nextDueDate: Date? {
        guard isRecurring else { return nil }
        return calculateNextDueDate(from: Date())
    }
    
    /// Human-readable description of the recurrence pattern
    var recurrenceDescription: String {
        guard recurrencePattern != .never else { return "Does not repeat" }
        
        var description = ""
        
        // Base pattern
        switch recurrencePattern {
        case .never:
            return "Does not repeat"
        case .daily:
            description = recurrenceInterval == 1 ? "Daily" : "Every \(recurrenceInterval) days"
        case .weekdays:
            description = "Every weekday (Monday through Friday)"
        case .weekly:
            if recurrenceWeekdays.isEmpty {
                description = recurrenceInterval == 1 ? "Weekly" : "Every \(recurrenceInterval) weeks"
            } else {
                let weekdayNames = recurrenceWeekdays.sorted().compactMap { weekdayNumber in
                    let formatter = DateFormatter()
                    formatter.locale = Locale.current
                    let weekdays = formatter.weekdaySymbols
                    return weekdays?[safe: weekdayNumber - 1]
                }
                let pattern = recurrenceInterval == 1 ? "Weekly" : "Every \(recurrenceInterval) weeks"
                description = "\(pattern) on \(weekdayNames.joined(separator: ", "))"
            }
        case .biweekly:
            description = "Every 2 weeks"
        case .monthly:
            description = recurrenceInterval == 1 ? "Monthly" : "Every \(recurrenceInterval) months"
        case .yearly:
            description = recurrenceInterval == 1 ? "Yearly" : "Every \(recurrenceInterval) years"
        case .custom:
            if !recurrenceWeekdays.isEmpty {
                let weekdayNames = recurrenceWeekdays.sorted().compactMap { weekdayNumber in
                    let formatter = DateFormatter()
                    formatter.locale = Locale.current
                    let shortWeekdays = formatter.shortWeekdaySymbols
                    return shortWeekdays?[safe: weekdayNumber - 1]
                }
                description = "Custom pattern on \(weekdayNames.joined(separator: ", "))"
            } else {
                description = "Every \(recurrenceInterval) days"
            }
        }
        
        // Add end condition
        switch recurrenceEndType {
        case .never:
            break
        case .afterCount:
            if let endCount = recurrenceEndCount {
                description += ", ending after \(endCount) \(endCount == 1 ? "occurrence" : "occurrences")"
            }
        case .onDate:
            if let endDate = recurrenceEndDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                description += ", ending on \(formatter.string(from: endDate))"
            }
        }
        
        return description
    }
    
    // MARK: - Recurrence Management
    
    /// Calculates the next due date based on the recurrence pattern
    ///
    /// - Parameter date: The reference date to calculate from
    /// - Returns: The next scheduled due date, or `nil` if not recurring
    func calculateNextDueDate(from date: Date) -> Date? {
        guard recurrencePattern != .never, let currentDue = dueDate else {
            return nil
        }
        
        let calendar = Calendar.current
        
        switch recurrencePattern {
        case .never:
            return nil
            
        case .daily:
            return calendar.date(byAdding: .day, value: recurrenceInterval, to: currentDue)
            
        case .weekdays:
            // Find the next weekday (Monday through Friday)
            var nextDate = calendar.date(byAdding: .day, value: 1, to: currentDue) ?? currentDue
            while calendar.component(.weekday, from: nextDate) == 1 || 
                  calendar.component(.weekday, from: nextDate) == 7 {
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
            }
            return nextDate
            
        case .weekly:
            if recurrenceWeekdays.isEmpty {
                // Simple weekly recurrence
                return calendar.date(byAdding: .weekOfYear, value: recurrenceInterval, to: currentDue)
            } else {
                // Custom weekly pattern - find next selected weekday
                return findNextWeekdayDate(from: currentDue, calendar: calendar)
            }
            
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2 * recurrenceInterval, to: currentDue)
            
        case .monthly:
            return calendar.date(byAdding: .month, value: recurrenceInterval, to: currentDue)
            
        case .yearly:
            return calendar.date(byAdding: .year, value: recurrenceInterval, to: currentDue)
            
        case .custom:
            // For custom patterns, fall back to weekly if weekdays are set
            if !recurrenceWeekdays.isEmpty {
                return findNextWeekdayDate(from: currentDue, calendar: calendar)
            }
            return calendar.date(byAdding: .day, value: recurrenceInterval, to: currentDue)
        }
    }
    
    /// Finds the next date matching the custom weekday pattern
    private func findNextWeekdayDate(from date: Date, calendar: Calendar) -> Date? {
        let currentWeekday = calendar.component(.weekday, from: date)
        let sortedWeekdays = recurrenceWeekdays.sorted()
        
        // Find the next weekday in this week
        if let nextWeekday = sortedWeekdays.first(where: { $0 > currentWeekday }) {
            let daysToAdd = nextWeekday - currentWeekday
            return calendar.date(byAdding: .day, value: daysToAdd, to: date)
        }
        
        // If no weekday left this week, go to first weekday of next week
        if let firstWeekday = sortedWeekdays.first {
            let daysUntilNextWeek = 7 - currentWeekday + firstWeekday
            return calendar.date(byAdding: .day, value: daysUntilNextWeek, to: date)
        }
        
        return nil
    }
    
    /// Generates recurring task instances up to a specified date
    ///
    /// This method creates new task instances based on the recurrence pattern,
    /// respecting the end conditions and interval settings.
    ///
    /// - Parameters:
    ///   - endDate: The date up to which instances should be generated
    ///   - context: The ModelContext to insert new instances into
    /// - Returns: An array of newly created recurring task instances
    func generateRecurringInstances(until endDate: Date, in context: ModelContext) -> [DiligenceTask] {
        guard isRecurring, !hasRecurrenceEnded, let startDue = dueDate else {
            return []
        }
        
        var instances: [DiligenceTask] = []
        var currentDate = startDue
        var instanceCount = 0
        let maxInstances = 100 // Safety limit to prevent infinite loops
        
        while currentDate <= endDate && instanceCount < maxInstances && !hasRecurrenceEnded {
            if let nextDate = calculateNextDueDate(from: currentDate) {
                // Check if we should stop based on end conditions
                if recurrenceEndType == .afterCount,
                   let endCount = recurrenceEndCount,
                   instanceCount >= endCount {
                    break
                }
                
                if recurrenceEndType == .onDate,
                   let recurrenceEnd = recurrenceEndDate,
                   nextDate > recurrenceEnd {
                    break
                }
                
                // Create recurring instance
                let instance = DiligenceTask(
                    title: title,
                    taskDescription: taskDescription,
                    isCompleted: false,
                    createdDate: Date(),
                    dueDate: nextDate,
                    emailID: emailID,
                    emailSubject: emailSubject,
                    emailSender: emailSender,
                    gmailURL: gmailURL,
                    sectionID: sectionID,
                    parentRecurringTaskID: title + "_" + createdDate.timeIntervalSince1970.description,
                    isRecurringInstance: true,
                    recurringInstanceDate: nextDate
                )
                
                instances.append(instance)
                context.insert(instance)
                
                currentDate = nextDate
                instanceCount += 1
            } else {
                break
            }
        }
        
        // Update the recurrence count on the parent task
        currentRecurrenceCount += instanceCount
        
        return instances
    }
}

// MARK: - Legacy Support

/// Legacy type alias for backward compatibility
///
/// Use `DiligenceTask` in new code.
typealias Task = DiligenceTask
