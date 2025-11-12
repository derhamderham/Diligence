//
//  AITaskSuggestionsView.swift
//  Diligence
//
//  AI Task Suggestions Interface for reviewing and creating tasks from AI analysis
//

import SwiftUI
import SwiftData

struct AITaskSuggestionsView: View {
    let email: ProcessedEmail
    let suggestions: [AITaskSuggestion]
    let availableSections: [TaskSection]
    let onTasksCreated: ([DiligenceTask]) -> Void
    let onCancel: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSuggestions = Set<UUID>()
    @State private var editedSuggestions: [UUID: EditableTaskSuggestion] = [:]
    @State private var isCreatingTasks = false
    
    private var allSelected: Bool {
        selectedSuggestions.count == suggestions.count
    }
    
    private var someSelected: Bool {
        !selectedSuggestions.isEmpty && selectedSuggestions.count < suggestions.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if suggestions.isEmpty {
                emptyStateView
            } else {
                suggestionsList
            }
            
            Divider()
            
            // Footer
            footerView
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            initializeEditedSuggestions()
            selectAllByDefault()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Task Suggestions")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Review and customize the suggested tasks from your email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.borderless)
            }
            
            // Email context
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("From Email: \(email.subject)")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text("Sender: \(email.sender)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !suggestions.isEmpty {
                    selectAllToggle
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var selectAllToggle: some View {
        HStack(spacing: 8) {
            Button(action: toggleSelectAll) {
                HStack(spacing: 4) {
                    Image(systemName: allSelected ? "checkmark.square.fill" : someSelected ? "minus.square.fill" : "square")
                        .foregroundColor(selectedSuggestions.isEmpty ? .secondary : .accentColor)
                    
                    Text(allSelected ? "Deselect All" : "Select All")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderless)
            
            if !selectedSuggestions.isEmpty {
                Text("(\(selectedSuggestions.count) selected)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Task Suggestions")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("The AI couldn't find any actionable items in this email. You can still create a task manually.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Suggestions List
    
    private var suggestionsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(suggestions) { suggestion in
                    AITaskSuggestionRow(
                        suggestion: suggestion,
                        editedSuggestion: editedSuggestions[suggestion.id] ?? EditableTaskSuggestion(from: suggestion),
                        availableSections: availableSections,
                        isSelected: selectedSuggestions.contains(suggestion.id),
                        onSelectionChanged: { isSelected in
                            if isSelected {
                                selectedSuggestions.insert(suggestion.id)
                            } else {
                                selectedSuggestions.remove(suggestion.id)
                            }
                        },
                        onEditChanged: { editedSuggestion in
                            editedSuggestions[suggestion.id] = editedSuggestion
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Text("AI-generated suggestions • Review before creating")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Button("Create Selected Tasks (\(selectedSuggestions.count))") {
                    createSelectedTasks()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedSuggestions.isEmpty || isCreatingTasks)
                
                if isCreatingTasks {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16, alignment: .center)
                        .fixedSize()
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Methods
    
    private func initializeEditedSuggestions() {
        for suggestion in suggestions {
            editedSuggestions[suggestion.id] = EditableTaskSuggestion(from: suggestion)
        }
    }
    
    private func selectAllByDefault() {
        // Auto-select suggestions that have clear due dates or high priority
        for suggestion in suggestions {
            if suggestion.dueDate != nil || suggestion.priority == .high {
                selectedSuggestions.insert(suggestion.id)
            }
        }
        
        // If nothing was auto-selected, select the first suggestion
        if selectedSuggestions.isEmpty && !suggestions.isEmpty {
            selectedSuggestions.insert(suggestions[0].id)
        }
    }
    
    private func toggleSelectAll() {
        if allSelected {
            selectedSuggestions.removeAll()
        } else {
            selectedSuggestions = Set(suggestions.map { $0.id })
        }
    }
    
    private func createSelectedTasks() {
        isCreatingTasks = true
        
        var createdTasks: [DiligenceTask] = []
        
        for suggestionID in selectedSuggestions {
            guard let originalSuggestion = suggestions.first(where: { $0.id == suggestionID }),
                  let editedSuggestion = editedSuggestions[suggestionID] else {
                continue
            }
            
            let task = createTask(from: editedSuggestion, originalSuggestion: originalSuggestion)
            modelContext.insert(task)
            createdTasks.append(task)
        }
        
        do {
            try modelContext.save()
            onTasksCreated(createdTasks)
        } catch {
            print("❌ Failed to save AI-generated tasks: \(error)")
            // TODO: Show error to user
        }
        
        isCreatingTasks = false
    }
    
    private func createTask(from edited: EditableTaskSuggestion, originalSuggestion: AITaskSuggestion) -> DiligenceTask {
        let task = DiligenceTask(
            title: edited.title,
            taskDescription: edited.description,
            isCompleted: false,
            createdDate: Date(),
            dueDate: edited.dueDate,
            emailID: email.id,
            emailSubject: email.subject,
            emailSender: email.sender,
            gmailURL: email.gmailURL.absoluteString,
            sectionID: edited.sectionID
        )
        
        // Handle recurring tasks
        if edited.isRecurring, let recurrencePattern = edited.recurrencePattern {
            switch recurrencePattern.lowercased() {
            case "daily":
                task.recurrencePattern = .daily
            case "weekly":
                task.recurrencePattern = .weekly
            case "monthly":
                task.recurrencePattern = .monthly
            case "yearly":
                task.recurrencePattern = .yearly
            default:
                task.recurrencePattern = .never
            }
        }
        
        return task
    }
}

// MARK: - Editable Task Suggestion

struct EditableTaskSuggestion {
    var title: String
    var description: String
    var dueDate: Date?
    var sectionID: String?
    var tags: [String]
    var amount: Double?
    var priority: DiligenceTaskPriority?
    var isRecurring: Bool
    var recurrencePattern: String?
    
    init(from suggestion: AITaskSuggestion) {
        self.title = suggestion.title
        self.description = suggestion.description
        self.dueDate = parseDueDateString(suggestion.dueDate)
        self.sectionID = nil // Will be set based on section matching
        self.tags = suggestion.tags
        self.amount = suggestion.amount
        self.priority = convertAIPriorityToTaskPriority(suggestion.priority)
        self.isRecurring = suggestion.isRecurring ?? false
        self.recurrencePattern = suggestion.recurrencePattern
    }
}

// Helper function to convert AITaskPriority to DiligenceTaskPriority
private func convertAIPriorityToTaskPriority(_ aiPriority: AITaskPriority?) -> DiligenceTaskPriority? {
    guard let aiPriority = aiPriority else { return nil }
    switch aiPriority {
    case .low:
        return .low
    case .medium:
        return .medium
    case .high, .urgent: // Map both high and urgent to high
        return .high
    }
}

private func parseDueDateString(_ dateString: String?) -> Date? {
    guard let dateString = dateString else { return nil }
    
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    
    return formatter.date(from: dateString)
}

// MARK: - Individual Task Suggestion Row

struct AITaskSuggestionRow: View {
    let suggestion: AITaskSuggestion
    @State var editedSuggestion: EditableTaskSuggestion
    let availableSections: [TaskSection]
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    let onEditChanged: (EditableTaskSuggestion) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            mainRow
            
            // Expanded details
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)
                
                expandedDetails
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.accentColor : Color(NSColor.separatorColor),
                    lineWidth: isSelected ? 2 : 0.5
                )
        )
        .cornerRadius(8)
    }
    
    private var mainRow: some View {
        HStack(alignment: .top, spacing: 12) {
            // Selection checkbox
            Button(action: { onSelectionChanged(!isSelected) }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            
            // Task content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(editedSuggestion.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    taskBadges
                }
                
                if !editedSuggestion.description.isEmpty {
                    Text(editedSuggestion.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }
                
                taskMetadata
            }
            
            // Expand/collapse button
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding()
    }
    
    private var taskBadges: some View {
        HStack(spacing: 4) {
            if let priority = editedSuggestion.priority {
                priorityBadge(priority)
            }
            
            if editedSuggestion.isRecurring {
                Badge(text: "Recurring", color: .orange)
            }
            
            if editedSuggestion.tags.contains("AP") {
                Badge(text: "AP", color: .red)
            } else if editedSuggestion.tags.contains("AR") {
                Badge(text: "AR", color: .green)
            }
            
            if let amount = editedSuggestion.amount {
                Badge(text: formatCurrency(amount), color: .blue)
            }
        }
    }
    
    private func priorityBadge(_ priority: DiligenceTaskPriority) -> some View {
        // Use the priority's built-in color property
        return Badge(text: priority.displayName, color: priority.color)
    }
    
    private var taskMetadata: some View {
        HStack(spacing: 12) {
            if let dueDate = editedSuggestion.dueDate {
                Label {
                    Text(formatDueDate(dueDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let sectionID = editedSuggestion.sectionID,
               let section = availableSections.first(where: { $0.id == sectionID }) {
                Label {
                    Text(section.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "folder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title editing
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                TextField("Task title", text: $editedSuggestion.title)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: editedSuggestion.title) { _, _ in
                        onEditChanged(editedSuggestion)
                    }
            }
            
            // Description editing
            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $editedSuggestion.description)
                    .frame(minHeight: 60, maxHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                    .onChange(of: editedSuggestion.description) { _, _ in
                        onEditChanged(editedSuggestion)
                    }
            }
            
            HStack(spacing: 16) {
                // Due date editing
                VStack(alignment: .leading, spacing: 4) {
                    Text("Due Date")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    DatePicker(
                        "Due Date",
                        selection: Binding(
                            get: { editedSuggestion.dueDate ?? Date() },
                            set: { editedSuggestion.dueDate = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.field)
                    .onChange(of: editedSuggestion.dueDate) { _, _ in
                        onEditChanged(editedSuggestion)
                    }
                    
                    Button("Clear Date") {
                        editedSuggestion.dueDate = nil
                        onEditChanged(editedSuggestion)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                
                // Section assignment
                VStack(alignment: .leading, spacing: 4) {
                    Text("Section")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Picker("Section", selection: $editedSuggestion.sectionID) {
                        Text("No Section")
                            .tag(nil as String?)
                        
                        ForEach(availableSections, id: \.id) { section in
                            Text(section.title)
                                .tag(section.id as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: editedSuggestion.sectionID) { _, _ in
                        onEditChanged(editedSuggestion)
                    }
                }
            }
            
            // Recurring task settings
            if editedSuggestion.isRecurring {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recurrence")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Picker("Recurrence Pattern", selection: Binding(
                        get: { editedSuggestion.recurrencePattern ?? "monthly" },
                        set: { editedSuggestion.recurrencePattern = $0 }
                    )) {
                        Text("Monthly").tag("monthly")
                        Text("Weekly").tag("weekly")
                        Text("Yearly").tag("yearly")
                        Text("Daily").tag("daily")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: editedSuggestion.recurrencePattern) { _, _ in
                        onEditChanged(editedSuggestion)
                    }
                }
            }
        }
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Badge Component

struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var showSuggestions = true
    
    let sampleEmail = ProcessedEmail(
        id: "sample123",
        threadId: "thread123",
        subject: "Invoice #12345 - Due October 30th",
        sender: "Acme Corp",
        senderEmail: "billing@acme.com",
        body: "Please remit payment of $2,500.00 by October 30th, 2024",
        snippet: "Invoice for services rendered...",
        receivedDate: Date(),
        gmailURL: URL(string: "https://mail.google.com/sample")!,
        attachments: []
    )
    
    let sampleSuggestions = [
        AITaskSuggestion(
            title: "Pay Acme Corp Invoice #12345",
            description: "Payment of $2,500.00 due October 30th",
            dueDate: "2024-10-30",
            section: "Finance",
            tags: ["AP"],
            amount: 2500.00,
            priority: .high,
            isRecurring: false,
            recurrencePattern: nil
        ),
        AITaskSuggestion(
            title: "Review service agreement with Acme Corp",
            description: "Follow up on services rendered mentioned in invoice",
            dueDate: nil,
            section: "Business",
            tags: [],
            amount: nil,
            priority: .medium,
            isRecurring: false,
            recurrencePattern: nil
        )
    ]
    
    let sampleSections = [
        TaskSection(title: "Finance", sortOrder: 0),
        TaskSection(title: "Business", sortOrder: 1),
        TaskSection(title: "Personal", sortOrder: 2)
    ]
    
    AITaskSuggestionsView(
        email: sampleEmail,
        suggestions: sampleSuggestions,
        availableSections: sampleSections,
        onTasksCreated: { tasks in
            print("Created \(tasks.count) tasks")
        },
        onCancel: {
            print("Cancelled")
        }
    )
    .frame(width: 700, height: 500)
}