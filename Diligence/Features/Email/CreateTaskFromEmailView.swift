//
//  CreateTaskFromEmailView.swift
//  Diligence
//
//  Created by derham on 10/24/25.
//

import SwiftUI
import SwiftData

struct CreateTaskFromEmailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\TaskSection.sortOrder)]) private var sections: [TaskSection]
    
    let email: ProcessedEmail
    let gmailService: GmailService
    
    @State private var taskTitle: String = ""
    @State private var taskDescription: String = ""
    @State private var dueDate: Date = Date().addingTimeInterval(86400) // Default to tomorrow
    @State private var hasDueDate: Bool = false
    @State private var selectedSectionID: String? = nil
    @State private var priority: TaskPriority = .medium
    @State private var amount: Double? = nil
    
    // Recurrence properties
    @State private var recurrencePattern: RecurrencePattern = .never
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceWeekdays: [Int] = []
    @State private var recurrenceEndType: RecurrenceEndType = .never
    @State private var recurrenceEndDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var recurrenceEndCount: Int = 10
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Email Information Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Creating task from email:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(email.subject)
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("From: \(email.sender)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Received: \(email.receivedDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                Form {
                    Section("Task Details") {
                        TextField("Task Title", text: $taskTitle)
                            .textFieldStyle(.roundedBorder)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description (optional)")
                                .font(.headline)
                            
                            TextEditor(text: $taskDescription)
                                .frame(minHeight: 100, maxHeight: 150)
                                .border(Color.gray.opacity(0.3), width: 1)
                        }
                        
                        // Priority Picker
                        VStack(alignment: .leading, spacing: 8) {
                            PriorityPicker(selection: $priority, style: .buttons, showNone: false)
                        }
                        
                        // Amount field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount (optional)")
                                .font(.headline)
                            
                            Text("For bills, invoices, or financial tasks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                TextField(
                                    "Amount",
                                    value: $amount,
                                    format: .currency(code: Locale.current.currency?.identifier ?? "USD")
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                                
                                if amount != nil {
                                    Button("Clear") {
                                        amount = nil
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        
                        Toggle("Set Due Date", isOn: $hasDueDate)
                        
                        if hasDueDate {
                            DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                            
                            // Recurrence section
                            RecurrenceQuickSetupView(
                                recurrencePattern: $recurrencePattern,
                                recurrenceInterval: $recurrenceInterval,
                                recurrenceWeekdays: $recurrenceWeekdays,
                                recurrenceEndType: $recurrenceEndType,
                                recurrenceEndDate: $recurrenceEndDate,
                                recurrenceEndCount: $recurrenceEndCount
                            )
                        }
                        
                        // Section selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Section (optional)")
                                .font(.headline)
                            
                            Text("Assign this email task to a section")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Section", selection: $selectedSectionID) {
                                Text("No Section")
                                    .tag(nil as String?)
                                
                                ForEach(sections, id: \.id) { section in
                                    Text(section.title)
                                        .tag(section.id as String?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    
                    Section("Email Content") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email Body:")
                                    .font(.headline)
                                
                                RTFTextView(htmlContent: email.body.isEmpty ? email.snippet : email.body)
                                    .font(.body)
                                    .padding()
                                    .background(Color(NSColor.textBackgroundColor))
                                    .border(Color.gray.opacity(0.3), width: 1)
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                    
                    // Attachments section
                    if !email.attachments.isEmpty {
                        Section("Attachments") {
                            AttachmentsListView(attachments: email.attachments, gmailService: gmailService)
                        }
                    }
                }
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                    
                    Spacer()
                    
                    Button("Create Task") {
                        createTask()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Create Task")
            .frame(minWidth: 600, minHeight: 600)
        }
        .onAppear {
            // Always set task title to current email subject to avoid
            // carrying over titles from previously viewed emails
            taskTitle = email.subject
            
            // Smart section suggestion based on email sender or subject
            suggestSection()
        }
    }
    
    private func createTask() {
        let trimmedTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let newTask = DiligenceTask(
            title: trimmedTitle,
            taskDescription: taskDescription,
            isCompleted: false,
            createdDate: Date(),
            dueDate: hasDueDate ? dueDate : nil,
            emailID: email.id,
            emailSubject: email.subject,
            emailSender: email.sender,
            gmailURL: email.gmailURL.absoluteString,
            sectionID: selectedSectionID,  // Assign to selected section
            amount: amount,
            priority: priority,
            recurrencePattern: hasDueDate ? recurrencePattern : .never,
            recurrenceInterval: recurrenceInterval,
            recurrenceEndType: recurrenceEndType,
            recurrenceEndDate: recurrenceEndDate,
            recurrenceEndCount: recurrenceEndCount
        )
        
        // Set custom weekdays if applicable
        if recurrencePattern == .weekly || recurrencePattern == .custom {
            newTask.recurrenceWeekdays = recurrenceWeekdays
        } else if recurrencePattern == .weekdays {
            newTask.recurrenceWeekdays = [2, 3, 4, 5, 6] // Monday through Friday
        }
        
        modelContext.insert(newTask)
        
        // Generate recurring instances if applicable
        if newTask.isRecurring {
            _Concurrency.Task {
                let endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
                let _ = newTask.generateRecurringInstances(until: endDate, in: modelContext)
                
                do {
                    try modelContext.save()
                } catch {
                    print("Error saving recurring task instances: \(error)")
                }
            }
        }
        
        do {
            try modelContext.save()
            
            // Log section assignment for debugging
            if let sectionID = selectedSectionID {
                let sectionTitle = sections.first(where: { $0.id == sectionID })?.title ?? "Unknown"
                print("✅ Created email task '\(trimmedTitle)' in section '\(sectionTitle)'")
            } else {
                print("✅ Created email task '\(trimmedTitle)' without section assignment")
            }
            
            // Trigger Reminders sync after creating task from email
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: Notification.Name("TriggerRemindersSync"),
                    object: nil
                )
                print("📱 Triggered Reminders sync after email task creation")
            }
            
        } catch {
            print("Failed to save task: \(error)")
        }
        
        dismiss()
    }
    
    private func suggestSection() {
        // Smart section suggestion based on email sender or subject
        // This is a placeholder for future intelligent section assignment
        // For now, we'll leave the section selection as manual
    }
}

#Preview {
    let sampleEmail = ProcessedEmail(
        id: "sample123",
        threadId: "thread123", 
        subject: "Important Meeting Tomorrow",
        sender: "John Smith",
        senderEmail: "john@example.com",
        body: "Hi there,\n\nI wanted to remind you about our important meeting tomorrow at 2 PM. Please make sure to bring the quarterly reports and be prepared to discuss the budget allocations.\n\nThanks,\nJohn",
        snippet: "Hi there, I wanted to remind you about our important meeting tomorrow...",
        receivedDate: Date(),
        gmailURL: URL(string: "https://mail.google.com/mail/u/0/#inbox/sample123")!,
        attachments: [
            EmailAttachment(
                id: "attachment1",
                filename: "report.pdf",
                mimeType: "application/pdf",
                size: 1024000,
                messageId: "sample123"
            )
        ]
    )
    
    CreateTaskFromEmailView(email: sampleEmail, gmailService: GmailService())
        .modelContainer(for: [DiligenceTask.self, TaskSection.self], inMemory: true)
}
