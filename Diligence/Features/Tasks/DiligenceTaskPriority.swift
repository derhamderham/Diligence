//
//  DiligenceTaskPriority.swift
//  Diligence
//
//  Priority level enumeration for tasks
//  DEPRECATED: Use TaskPriority from CoreModelsTaskPriority.swift instead
//

import Foundation

/// Priority levels for tasks
@available(*, deprecated, renamed: "TaskPriority", message: "Use TaskPriority instead")
public enum DiligenceTaskPriority: Int, Codable, CaseIterable, Comparable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    
    /// Display name for the priority
    public var displayName: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    /// Comparable conformance - higher priority values are "greater"
    public static func < (lhs: DiligenceTaskPriority, rhs: DiligenceTaskPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

