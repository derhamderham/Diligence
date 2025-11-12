//
//  Priority.swift
//  Diligence
//
//  Task priority levels with visual styling
//

import Foundation
import SwiftUI

// MARK: - Task Priority

/// Defines the priority level for a task
///
/// Use priority to visually distinguish important tasks and organize your workflow.
/// Priority affects task sorting and visual presentation throughout the app.
///
/// - Note: Default priority for new tasks is `.medium`
public enum TaskPriority: Int, CaseIterable, Codable, Sendable, Comparable {
    /// High priority - urgent or critical tasks
    case high = 3
    
    /// Medium priority - standard tasks (default)
    case medium = 2
    
    /// Low priority - tasks that can wait
    case low = 1
    
    /// No priority assigned
    case none = 0
    
    // MARK: - Display Properties
    
    /// Human-readable name for the priority level
    public var displayName: String {
        switch self {
        case .high:
            return "High"
        case .medium:
            return "Medium"
        case .low:
            return "Low"
        case .none:
            return "None"
        }
    }
    
    /// Short label for compact display
    public var shortLabel: String {
        switch self {
        case .high:
            return "H"
        case .medium:
            return "M"
        case .low:
            return "L"
        case .none:
            return "—"
        }
    }
    
    /// SF Symbol icon representing the priority
    /// Note: Priority is primarily shown via the colored vertical bar
    public var systemImageName: String {
        switch self {
        case .high, .medium, .low:
            return "circle"
        case .none:
            return "circle"
        }
    }
    
    // MARK: - Color Coding
    
    /// Primary color for the priority level
    public var color: Color {
        switch self {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .blue
        case .none:
            return .secondary
        }
    }
    
    /// Background color for priority badges
    public var backgroundColor: Color {
        switch self {
        case .high:
            return Color.red.opacity(0.1)
        case .medium:
            return Color.orange.opacity(0.1)
        case .low:
            return Color.blue.opacity(0.1)
        case .none:
            return Color.secondary.opacity(0.05)
        }
    }
    
    // MARK: - Comparable Conformance
    
    /// Compares two priority values
    ///
    /// Higher priority values are considered "greater than" lower values.
    /// This allows for natural sorting with high-priority tasks appearing first.
    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    // MARK: - Helper Properties
    
    /// Whether this is a meaningful priority (not `.none`)
    public var isAssigned: Bool {
        return self != .none
    }
    
    /// Accessibility label for VoiceOver
    public var accessibilityLabel: String {
        switch self {
        case .high:
            return "High priority"
        case .medium:
            return "Medium priority"
        case .low:
            return "Low priority"
        case .none:
            return "No priority set"
        }
    }
}

// MARK: - Priority Extension for SwiftUI

extension TaskPriority {
    /// Creates a priority badge view
    ///
    /// Use this to display a compact, color-coded priority indicator.
    ///
    /// - Parameter style: The visual style of the badge
    /// - Returns: A SwiftUI view representing the priority
    @ViewBuilder
    func badge(style: PriorityBadgeStyle = .compact) -> some View {
        PriorityBadge(priority: self, style: style)
    }
}

// MARK: - Type Alias for Consistency

/// Type alias for consistency with DiligenceTask naming
///
/// Use `DiligenceTaskPriority` in new code to match the `DiligenceTask` naming convention.
public typealias DiligenceTaskPriority = TaskPriority

// MARK: - Priority Badge Styles

/// Visual styles for priority badges
public enum PriorityBadgeStyle {
    /// Compact badge with icon only
    case compact
    
    /// Badge with icon and label
    case labeled
    
    /// Full badge with icon, label, and background
    case full
    
    /// Minimal dot indicator
    case dot
}
