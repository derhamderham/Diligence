//
//  TaskSection.swift
//  Diligence
//
//  Model for organizing tasks into sections
//

import Foundation
import SwiftData

// MARK: - Task Section Model

/// Represents a logical grouping of tasks
///
/// Task sections allow users to organize their tasks into categories,
/// projects, or any custom grouping. Sections can be synced with
/// Apple Reminders lists.
///
/// > Note: Use `DiligenceTaskSection` in new code. The `TaskSection` typealias
/// > is provided for backward compatibility.
///
/// ## Topics
///
/// ### Properties
/// - ``id``
/// - ``title``
/// - ``sortOrder``
/// - ``reminderID``
/// - ``createdDate``
@Model
final class DiligenceTaskSection {
    /// Unique identifier for the section
    @Attribute(.unique) var id: String
    
    /// Display name of the section
    var title: String
    
    /// Sort order for displaying sections (lower numbers appear first)
    var sortOrder: Int
    
    /// EventKit reminder list identifier for sync with Apple Reminders
    ///
    /// When set, tasks in this section will be synced to the corresponding
    /// reminder list in the Reminders app.
    var reminderID: String?
    
    /// Date when the section was created
    var createdDate: Date
    
    // MARK: - Initialization
    
    /// Creates a new task section
    ///
    /// - Parameters:
    ///   - title: The display name for the section
    ///   - sortOrder: The position in the section list (defaults to 0)
    init(title: String, sortOrder: Int = 0) {
        self.id = UUID().uuidString
        self.title = title
        self.sortOrder = sortOrder
        self.createdDate = Date()
    }
}


