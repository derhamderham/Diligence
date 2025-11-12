//
//  PriorityVisualReference.swift
//  Diligence
//
//  Visual reference and testing playground for Priority UI components
//

import SwiftUI

/// Visual reference showing all Priority UI components and their usage
///
/// This view demonstrates every priority component style and can be used
/// for testing, documentation, or as a component gallery.
struct PriorityVisualReference: View {
    @State private var selectedPriority: DiligenceTaskPriority = .medium
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Priority System - Visual Reference")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Complete overview of all priority components and styles")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Priority Levels Overview
                priorityLevelsSection
                
                Divider()
                
                // Badge Styles
                badgeStylesSection
                
                Divider()
                
                // Picker Styles
                pickerStylesSection
                
                Divider()
                
                // Task Row Examples
                taskRowExamplesSection
                
                Divider()
                
                // Color Reference
                colorReferenceSection
                
                Divider()
                
                // Interactive Demo
                interactiveDemoSection
            }
            .padding(40)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var priorityLevelsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Priority Levels")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Four priority levels with semantic meaning and color coding")
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                priorityLevelRow(
                    priority: .high,
                    description: "Urgent or critical tasks requiring immediate attention",
                    example: "Meeting in 1 hour, Urgent client request"
                )
                
                priorityLevelRow(
                    priority: .medium,
                    description: "Standard tasks with normal importance (default)",
                    example: "Review report, Schedule meeting"
                )
                
                priorityLevelRow(
                    priority: .low,
                    description: "Tasks that can wait or are nice-to-have",
                    example: "Read article, Organize files"
                )
                
                priorityLevelRow(
                    priority: .none,
                    description: "No priority assigned or informational items",
                    example: "Reference material, Archive candidate"
                )
            }
        }
    }
    
    @ViewBuilder
    private func priorityLevelRow(priority: DiligenceTaskPriority, description: String, example: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Visual indicator
            VStack(spacing: 8) {
                PriorityBadge(priority: priority, style: .full)
                    .frame(width: 120)
                
                Image(systemName: priority.systemImageName)
                    .font(.title)
                    .foregroundColor(priority.color)
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text(priority.displayName)
                    .font(.headline)
                    .foregroundColor(priority.color)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Example: \(example)")
                    .font(.caption)
                    .italic()
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding()
        .background(priority.backgroundColor)
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private var badgeStylesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Badge Styles")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Different visual representations for different contexts")
                .foregroundColor(.secondary)
            
            // Style comparison grid
            Grid(alignment: .leading, horizontalSpacing: 30, verticalSpacing: 20) {
                GridRow {
                    Text("Style")
                        .font(.headline)
                        .gridColumnAlignment(.leading)
                    
                    ForEach(DiligenceTaskPriority.allCases, id: \.self) { priority in
                        Text(priority.displayName)
                            .font(.headline)
                            .foregroundColor(priority.color)
                    }
                }
                
                GridRow {
                    Text("Compact")
                        .foregroundColor(.secondary)
                    
                    ForEach(DiligenceTaskPriority.allCases, id: \.self) { priority in
                        PriorityBadge(priority: priority, style: .compact)
                    }
                }
                
                GridRow {
                    Text("Labeled")
                        .foregroundColor(.secondary)
                    
                    ForEach(DiligenceTaskPriority.allCases, id: \.self) { priority in
                        PriorityBadge(priority: priority, style: .labeled)
                    }
                }
                
                GridRow {
                    Text("Full")
                        .foregroundColor(.secondary)
                    
                    ForEach(DiligenceTaskPriority.allCases, id: \.self) { priority in
                        PriorityBadge(priority: priority, style: .full)
                    }
                }
                
                GridRow {
                    Text("Dot")
                        .foregroundColor(.secondary)
                    
                    ForEach(DiligenceTaskPriority.allCases, id: \.self) { priority in
                        HStack {
                            PriorityBadge(priority: priority, style: .dot)
                            Spacer()
                        }
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            // Usage recommendations
            VStack(alignment: .leading, spacing: 8) {
                Text("Usage Recommendations:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                recommendationRow(icon: "list.bullet", text: "Compact - Task list rows")
                recommendationRow(icon: "doc.text", text: "Labeled - Inline labels with context")
                recommendationRow(icon: "sidebar.right", text: "Full - Task detail view, prominent display")
                recommendationRow(icon: "circle.fill", text: "Dot - Minimal indicator, subtle accent")
            }
            .padding()
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private func recommendationRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var pickerStylesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Picker Styles")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Different input methods for selecting priority")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 30) {
                // Menu Picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Menu Style")
                        .font(.headline)
                    Text("Dropdown menu - Compact, good for inline editing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    PriorityPicker(selection: $selectedPriority, style: .menu)
                        .frame(maxWidth: 300)
                }
                
                // Segmented Picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Segmented Style")
                        .font(.headline)
                    Text("Segmented control - Quick selection, minimal space")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    PriorityPicker(selection: $selectedPriority, style: .segmented, showNone: false)
                        .frame(maxWidth: 300)
                }
                
                // Buttons Picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Buttons Style (Recommended)")
                        .font(.headline)
                    Text("Visual button grid - Most intuitive for task creation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    PriorityPicker(selection: $selectedPriority, style: .buttons, showNone: false)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
    
    @ViewBuilder
    private var taskRowExamplesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Task Row Examples")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("How priority appears in the task list")
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                mockTaskRow(
                    priority: .high,
                    title: "Urgent: Client presentation",
                    description: "Prepare slides for tomorrow's meeting",
                    dueDate: Date()
                )
                
                mockTaskRow(
                    priority: .medium,
                    title: "Review quarterly report",
                    description: "Go through Q4 financial data",
                    dueDate: Date().addingTimeInterval(86400 * 3)
                )
                
                mockTaskRow(
                    priority: .low,
                    title: "Organize project files",
                    description: "Clean up old documents and archives",
                    dueDate: nil
                )
                
                mockTaskRow(
                    priority: .none,
                    title: "Read industry news",
                    description: "Catch up on latest developments",
                    dueDate: nil
                )
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
    
    @ViewBuilder
    private func mockTaskRow(priority: DiligenceTaskPriority, title: String, description: String, dueDate: Date?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Priority indicator with accent bar
            PriorityIndicator(priority: priority, showAccentBar: true)
            
            // Checkbox
            Image(systemName: "circle")
                .foregroundColor(.secondary)
                .font(.title2)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    
                    PriorityBadge(priority: priority, style: .compact)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let dueDate = dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(dueDate, style: .date)
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var colorReferenceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Color Reference")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Color coding system for priority levels")
                .foregroundColor(.secondary)
            
            Grid(alignment: .leading, horizontalSpacing: 40, verticalSpacing: 16) {
                GridRow {
                    Text("Priority")
                        .font(.headline)
                    Text("Color")
                        .font(.headline)
                    Text("Usage")
                        .font(.headline)
                    Text("Psychology")
                        .font(.headline)
                }
                
                GridRow {
                    Text("High")
                        .foregroundColor(.red)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 30, height: 30)
                    Text("Urgency, critical items")
                        .font(.caption)
                    Text("Demands immediate attention")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                GridRow {
                    Text("Medium")
                        .foregroundColor(.orange)
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 30, height: 30)
                    Text("Standard tasks, default")
                        .font(.caption)
                    Text("Balanced importance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                GridRow {
                    Text("Low")
                        .foregroundColor(.blue)
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 30, height: 30)
                    Text("Deferrable items")
                        .font(.caption)
                    Text("Calm, can wait")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                GridRow {
                    Text("None")
                        .foregroundColor(.secondary)
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 30, height: 30)
                    Text("Unassigned or neutral")
                        .font(.caption)
                    Text("No urgency signal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
    
    @ViewBuilder
    private var interactiveDemoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Interactive Demo")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try selecting different priorities and see how they display")
                .foregroundColor(.secondary)
            
            VStack(spacing: 30) {
                // Picker
                PriorityPicker(selection: $selectedPriority, style: .buttons, showNone: false)
                
                // Live preview
                VStack(spacing: 20) {
                    HStack {
                        Text("Current Selection:")
                            .font(.headline)
                        Spacer()
                        PriorityBadge(priority: selectedPriority, style: .full)
                    }
                    
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Properties:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            propertyRow(label: "Display Name", value: selectedPriority.displayName)
                            propertyRow(label: "Short Label", value: selectedPriority.shortLabel)
                            propertyRow(label: "Icon", value: selectedPriority.systemImageName)
                            propertyRow(label: "Raw Value", value: String(selectedPriority.rawValue))
                            propertyRow(label: "Accessibility", value: selectedPriority.accessibilityLabel)
                        }
                        
                        Spacer()
                        
                        // Visual preview
                        VStack(spacing: 12) {
                            Text("Badge Styles:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 16) {
                                VStack {
                                    PriorityBadge(priority: selectedPriority, style: .compact)
                                    Text("Compact")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    PriorityBadge(priority: selectedPriority, style: .labeled)
                                    Text("Labeled")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    PriorityBadge(priority: selectedPriority, style: .full)
                                    Text("Full")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    PriorityBadge(priority: selectedPriority, style: .dot)
                                    Text("Dot")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(selectedPriority.backgroundColor)
                .cornerRadius(10)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
    
    @ViewBuilder
    private func propertyRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview("Priority Visual Reference") {
    PriorityVisualReference()
        .frame(width: 900, height: 800)
}
