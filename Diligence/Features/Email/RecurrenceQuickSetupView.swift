//
//  RecurrenceQuickSetupView.swift
//  Diligence
//
//  Created by derham on 11/11/25.
//

import SwiftUI

/// A view that provides a quick setup interface for task recurrence patterns
///
/// This view allows users to configure:
/// - Recurrence pattern (daily, weekly, monthly, etc.)
/// - Recurrence interval (every N days/weeks/months)
/// - Specific weekdays (for weekly patterns)
/// - End conditions (never, after count, or on date)
struct RecurrenceQuickSetupView: View {
    @Binding var recurrencePattern: RecurrencePattern
    @Binding var recurrenceInterval: Int
    @Binding var recurrenceWeekdays: [Int]
    @Binding var recurrenceEndType: RecurrenceEndType
    @Binding var recurrenceEndDate: Date
    @Binding var recurrenceEndCount: Int
    
    private let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Recurrence Pattern Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Repeat")
                    .font(.headline)
                
                Picker("Repeat", selection: $recurrencePattern) {
                    ForEach(RecurrencePattern.allCases, id: \.self) { pattern in
                        HStack {
                            Image(systemName: pattern.systemImageName)
                            Text(pattern.displayName)
                        }
                        .tag(pattern)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            // Show additional options if not "never"
            if recurrencePattern != .never {
                Divider()
                
                // Interval selector for applicable patterns
                if showsIntervalSelector {
                    HStack {
                        Text("Every")
                        Stepper("\(recurrenceInterval)", value: $recurrenceInterval, in: 1...99)
                            .frame(maxWidth: 100)
                        Text(intervalUnitName)
                    }
                }
                
                // Weekday selector for weekly patterns
                if recurrencePattern == .weekly || recurrencePattern == .custom {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Repeat on")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { weekday in
                                weekdayButton(for: weekday)
                            }
                        }
                    }
                }
                
                Divider()
                
                // End type selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ends")
                        .font(.headline)
                    
                    Picker("Ends", selection: $recurrenceEndType) {
                        ForEach(RecurrenceEndType.allCases, id: \.self) { endType in
                            Text(endType.displayName)
                                .tag(endType)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    
                    // Show appropriate input based on end type
                    switch recurrenceEndType {
                    case .never:
                        EmptyView()
                        
                    case .afterCount:
                        HStack {
                            Text("After")
                            Stepper("\(recurrenceEndCount)", value: $recurrenceEndCount, in: 1...999)
                                .frame(maxWidth: 100)
                            Text(recurrenceEndCount == 1 ? "occurrence" : "occurrences")
                        }
                        
                    case .onDate:
                        DatePicker("End Date", selection: $recurrenceEndDate, displayedComponents: .date)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Views
    
    private func weekdayButton(for weekday: Int) -> some View {
        let isSelected = recurrenceWeekdays.contains(weekday)
        
        return Button(action: {
            if isSelected {
                recurrenceWeekdays.removeAll { $0 == weekday }
            } else {
                recurrenceWeekdays.append(weekday)
                recurrenceWeekdays.sort()
            }
        }) {
            Text(weekdayNames[weekday - 1])
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Properties
    
    /// Determines if the interval selector should be shown for the current pattern
    private var showsIntervalSelector: Bool {
        switch recurrencePattern {
        case .never, .weekdays:
            return false
        default:
            return true
        }
    }
    
    /// Returns the appropriate unit name based on the recurrence pattern
    private var intervalUnitName: String {
        let isPlural = recurrenceInterval > 1
        
        switch recurrencePattern {
        case .daily:
            return isPlural ? "days" : "day"
        case .weekly:
            return isPlural ? "weeks" : "week"
        case .biweekly:
            return isPlural ? "weeks" : "week"
        case .monthly:
            return isPlural ? "months" : "month"
        case .yearly:
            return isPlural ? "years" : "year"
        default:
            return "units"
        }
    }
}

// MARK: - Preview

#Preview("Basic Recurrence") {
    @Previewable @State var pattern: RecurrencePattern = .weekly
    @Previewable @State var interval: Int = 1
    @Previewable @State var weekdays: [Int] = [2, 4, 6] // Mon, Wed, Fri
    @Previewable @State var endType: RecurrenceEndType = .never
    @Previewable @State var endDate: Date = Date()
    @Previewable @State var endCount: Int = 10
    
    return Form {
        RecurrenceQuickSetupView(
            recurrencePattern: $pattern,
            recurrenceInterval: $interval,
            recurrenceWeekdays: $weekdays,
            recurrenceEndType: $endType,
            recurrenceEndDate: $endDate,
            recurrenceEndCount: $endCount
        )
    }
    .frame(width: 400)
    .padding()
}

#Preview("Daily with End Date") {
    @Previewable @State var pattern: RecurrencePattern = .daily
    @Previewable @State var interval: Int = 2
    @Previewable @State var weekdays: [Int] = []
    @Previewable @State var endType: RecurrenceEndType = .onDate
    @Previewable @State var endDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 30)
    @Previewable @State var endCount: Int = 10
    
    return Form {
        RecurrenceQuickSetupView(
            recurrencePattern: $pattern,
            recurrenceInterval: $interval,
            recurrenceWeekdays: $weekdays,
            recurrenceEndType: $endType,
            recurrenceEndDate: $endDate,
            recurrenceEndCount: $endCount
        )
    }
    .frame(width: 400)
    .padding()
}
