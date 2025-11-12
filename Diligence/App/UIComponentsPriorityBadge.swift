//
//  PriorityBadge.swift
//  Diligence
//
//  Visual component for displaying task priority
//

import SwiftUI

// MARK: - Priority Badge View

/// A visual badge displaying task priority with color coding and icons
///
/// `PriorityBadge` provides a consistent way to display priority levels throughout the app.
/// It supports multiple visual styles from compact icons to full labeled badges.
///
/// ## Usage
///
/// ```swift
/// PriorityBadge(priority: .high, style: .full)
/// PriorityBadge(priority: .medium, style: .compact)
/// ```
struct PriorityBadge: View {
    let priority: DiligenceTaskPriority
    let style: PriorityBadgeStyle
    
    init(priority: DiligenceTaskPriority, style: PriorityBadgeStyle = .compact) {
        self.priority = priority
        self.style = style
    }
    
    var body: some View {
        Group {
            switch style {
            case .compact:
                compactBadge
            case .labeled:
                labeledBadge
            case .full:
                fullBadge
            case .dot:
                dotBadge
            }
        }
        .accessibilityLabel(priority.accessibilityLabel)
    }
    
    // MARK: - Badge Styles
    
    @ViewBuilder
    private var compactBadge: some View {
        if priority.isAssigned {
            // Vertical colored bar only (no icon for cleaner UI)
            Rectangle()
                .fill(priority.color)
                .frame(width: 3)
                .cornerRadius(1.5)
                .help(priority.displayName + " priority")
        }
    }
    
    @ViewBuilder
    private var labeledBadge: some View {
        if priority.isAssigned {
            HStack(spacing: 6) {
                // Vertical colored bar
                Rectangle()
                    .fill(priority.color)
                    .frame(width: 3)
                    .cornerRadius(1.5)
                
                Image(systemName: priority.systemImageName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(priority.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .help(priority.displayName + " priority")
        }
    }
    
    @ViewBuilder
    private var fullBadge: some View {
        if priority.isAssigned {
            HStack(spacing: 6) {
                // Vertical colored bar
                Rectangle()
                    .fill(priority.color)
                    .frame(width: 3)
                    .cornerRadius(1.5)
                
                Image(systemName: priority.systemImageName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(priority.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priority.backgroundColor)
            .cornerRadius(6)
            .help(priority.displayName + " priority")
        }
    }
    
    @ViewBuilder
    private var dotBadge: some View {
        if priority.isAssigned {
            Circle()
                .fill(priority.color)
                .frame(width: 8, height: 8)
                .help(priority.displayName + " priority")
        }
    }
}

// MARK: - Priority Picker

/// A picker control for selecting task priority
///
/// Provides an intuitive interface for choosing priority levels with visual feedback.
/// Works seamlessly in forms and creation views.
///
/// ## Usage
///
/// ```swift
/// @State private var priority: DiligenceTaskPriority = .medium
///
/// PriorityPicker(selection: $priority)
/// PriorityPicker(selection: $priority, style: .segmented)
/// ```
struct PriorityPicker: View {
    @Binding var selection: DiligenceTaskPriority
    let style: PickerStyle
    let showNone: Bool
    
    enum PickerStyle {
        case menu
        case segmented
        case buttons
    }
    
    init(
        selection: Binding<DiligenceTaskPriority>,
        style: PickerStyle = .menu,
        showNone: Bool = true
    ) {
        self._selection = selection
        self.style = style
        self.showNone = showNone
    }
    
    var body: some View {
        Group {
            switch style {
            case .menu:
                menuPicker
            case .segmented:
                segmentedPicker
            case .buttons:
                buttonsPicker
            }
        }
    }
    
    // MARK: - Picker Styles
    
    private var menuPicker: some View {
        Picker("Priority", selection: $selection) {
            ForEach(priorityOptions, id: \.self) { priority in
                HStack {
                    Image(systemName: priority.systemImageName)
                        .foregroundColor(priority.color)
                    Text(priority.displayName)
                }
                .tag(priority)
            }
        }
        .pickerStyle(.menu)
    }
    
    @ViewBuilder
    private var segmentedPicker: some View {
        Picker("Priority", selection: $selection) {
            ForEach(priorityOptions, id: \.self) { priority in
                Text(priority.shortLabel)
                    .tag(priority)
            }
        }
        .pickerStyle(.segmented)
        .help("Select task priority")
    }
    
    @ViewBuilder
    private var buttonsPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Priority")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(priorityOptions, id: \.self) { priority in
                    PriorityButton(
                        priority: priority,
                        isSelected: selection == priority,
                        action: {
                            selection = priority
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var priorityOptions: [DiligenceTaskPriority] {
        if showNone {
            return DiligenceTaskPriority.allCases
        } else {
            return DiligenceTaskPriority.allCases.filter { $0 != .none }
        }
    }
}

// MARK: - Priority Button (for buttons style)

/// Individual button for priority selection
private struct PriorityButton: View {
    let priority: DiligenceTaskPriority
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: priority.systemImageName)
                    .font(.title3)
                    .foregroundColor(isSelected ? priority.color : .secondary)
                
                Text(priority.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? priority.color : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(isSelected ? priority.backgroundColor : Color.secondary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? priority.color : Color.clear, lineWidth: 2)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .help(priority.displayName + " priority")
    }
}

// MARK: - Priority Indicator (for Task List)

/// A visual indicator showing priority in task rows
///
/// This view combines a priority badge with an optional vertical accent bar
/// for enhanced visibility in task lists.
struct PriorityIndicator: View {
    let priority: DiligenceTaskPriority
    let showAccentBar: Bool
    
    init(priority: DiligenceTaskPriority, showAccentBar: Bool = true) {
        self.priority = priority
        self.showAccentBar = showAccentBar
    }
    
    var body: some View {
        HStack(spacing: 6) {
            if showAccentBar && priority.isAssigned {
                Rectangle()
                    .fill(priority.color)
                    .frame(width: 3)
                    .cornerRadius(1.5)
            }
            
            PriorityBadge(priority: priority, style: .compact)
        }
    }
}

// MARK: - Preview

#Preview("Priority Badges") {
    VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compact Style")
                .font(.headline)
            
            HStack(spacing: 16) {
                ForEach(DiligenceTaskPriority.allCases, id: \.self) { priority in
                    PriorityBadge(priority: priority, style: .compact)
                }
            }
        }
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Labeled Style")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(DiligenceTaskPriority.allCases, id: \.self) { priority in
                    PriorityBadge(priority: priority, style: .labeled)
                }
            }
        }
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Full Style")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(DiligenceTaskPriority.allCases, id: \.self) { priority in
                    PriorityBadge(priority: priority, style: .full)
                }
            }
        }
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Dot Style")
                .font(.headline)
            
            HStack(spacing: 16) {
                ForEach(DiligenceTaskPriority.allCases, id: \.self) { priority in
                    PriorityBadge(priority: priority, style: .dot)
                }
            }
        }
    }
    .padding()
}

#Preview("Priority Pickers") {
    @Previewable @State var selectedPriority: DiligenceTaskPriority = .medium
    
    VStack(spacing: 30) {
        VStack(alignment: .leading, spacing: 12) {
            Text("Menu Picker")
                .font(.headline)
            
            PriorityPicker(selection: $selectedPriority, style: .menu)
        }
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Segmented Picker")
                .font(.headline)
            
            PriorityPicker(selection: $selectedPriority, style: .segmented)
        }
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Buttons Picker")
                .font(.headline)
            
            PriorityPicker(selection: $selectedPriority, style: .buttons)
        }
        
        Text("Selected: \(selectedPriority.displayName)")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .frame(width: 400)
}
