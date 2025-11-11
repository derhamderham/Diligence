//
//  RecurrenceModels.swift
//  Diligence
//
//  Task recurrence models and patterns
//

import Foundation

// MARK: - Recurrence Pattern

/// Defines the frequency pattern for recurring tasks
///
/// Supports various recurrence patterns from simple daily repetition
/// to complex custom schedules with specific weekdays.
///
/// - Note: Use `never` for non-recurring tasks
public enum RecurrencePattern: String, CaseIterable, Codable, Sendable {
    /// Task does not repeat
    case never = "never"
    
    /// Task repeats every day
    case daily = "daily"
    
    /// Task repeats on weekdays only (Monday through Friday)
    case weekdays = "weekdays"
    
    /// Task repeats weekly on specific day(s)
    case weekly = "weekly"
    
    /// Task repeats every two weeks
    case biweekly = "biweekly"
    
    /// Task repeats monthly on the same day
    case monthly = "monthly"
    
    /// Task repeats yearly on the same date
    case yearly = "yearly"
    
    /// Task uses a custom recurrence pattern
    case custom = "custom"
    
    /// Human-readable name for the recurrence pattern
    public var displayName: String {
        switch self {
        case .never:
            return "Never"
        case .daily:
            return "Daily"
        case .weekdays:
            return "Weekdays (Mon-Fri)"
        case .weekly:
            return "Weekly"
        case .biweekly:
            return "Every 2 weeks"
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        case .custom:
            return "Custom"
        }
    }
    
    /// SF Symbol name representing the recurrence pattern
    public var systemImageName: String {
        switch self {
        case .never:
            return "clock"
        case .daily:
            return "clock.circle"
        case .weekdays:
            return "briefcase"
        case .weekly:
            return "calendar.badge.clock"
        case .biweekly:
            return "calendar.badge.clock"
        case .monthly:
            return "calendar.circle"
        case .yearly:
            return "calendar"
        case .custom:
            return "gearshape"
        }
    }
}

// MARK: - Recurrence End Type

/// Defines when a recurring task should stop generating instances
///
/// Use this to set termination conditions for recurring tasks, such as
/// a specific end date or a maximum number of occurrences.
public enum RecurrenceEndType: String, CaseIterable, Codable, Sendable {
    /// Recurrence never ends (continues indefinitely)
    case never = "never"
    
    /// Recurrence ends after a specific number of occurrences
    case afterCount = "after_count"
    
    /// Recurrence ends on a specific date
    case onDate = "on_date"
    
    /// Human-readable name for the end type
    public var displayName: String {
        switch self {
        case .never:
            return "Never"
        case .afterCount:
            return "After occurrences"
        case .onDate:
            return "On date"
        }
    }
}

// MARK: - Collection Extension

/// Extension to safely access collection elements by index
extension Collection {
    /// Safely accesses an element at the specified index
    ///
    /// Returns `nil` if the index is out of bounds instead of crashing.
    ///
    /// - Parameter index: The position of the element to access
    /// - Returns: The element at the specified position, or `nil` if out of bounds
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
