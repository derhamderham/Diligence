//
//  TaskListView.swift
//  Diligence
//
//  Created by derham on 10/24/25.
//  Updated by Assistant on 10/29/25.
//

import SwiftUI
import SwiftData
import AppKit
import EventKit

// Section model for SwiftData
@Model
class TaskSection {
    @Attribute(.unique) var id: String
    var title: String
    var sortOrder: Int
    var reminderID: String?
    var createdDate: Date
    
    init(title: String, sortOrder: Int = 0) {
        self.id = UUID().uuidString
        self.title = title
        self.sortOrder = sortOrder
        self.createdDate = Date()
    }
}

    
    struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\DiligenceTask.createdDate, order: .reverse)]) 
    private var tasks: [DiligenceTask]
    @Query(sort: [SortDescriptor(\TaskSection.sortOrder)]) 
    private var sections: [TaskSection]
    @StateObject private var remindersService = RemindersService()
    
    @State private var selectedTask: DiligenceTask?
    @State private var showingSectionManager = false
    @State private var isPerformingOperation = false // Prevent rapid operations
    @State private var refreshTrigger = false // Force UI refresh
    
    private var syncStatusText: String {
        return remindersService.getSyncStatusText()
    }
    
    var incompleteTasks: [DiligenceTask] {
        tasks.filter { !$0.isCompleted }
    }
    
    var completedTasks: [DiligenceTask] {
        tasks.filter { $0.isCompleted }
    }
    
    // Group tasks by sections and sort by due date
    func tasksForSection(_ section: TaskSection) -> [DiligenceTask] {
        let tasksInSection = tasks.filter { $0.sectionID == section.id }
        
        // Sort by due date: tasks with due dates first (sorted by date), then tasks without due dates
        let sortedTasks = tasksInSection.sorted { task1, task2 in
            switch (task1.dueDate, task2.dueDate) {
            case (let date1?, let date2?):
                // Both have due dates - sort by date (earliest first)
                return date1 < date2
            case (nil, _?):
                // task1 has no due date, task2 has due date - task2 comes first
                return false
            case (_?, nil):
                // task1 has due date, task2 has no due date - task1 comes first
                return true
            case (nil, nil):
                // Neither has due date - sort by creation date (newest first)
                return task1.createdDate > task2.createdDate
            }
        }
        
        if !sortedTasks.isEmpty {
            print("📋 Section '\(section.title)' (\(section.id)) contains \(sortedTasks.count) tasks sorted by due date")
        }
        return sortedTasks
    }
    
    var unsectionedTasks: [DiligenceTask] {
        let unsectioned = tasks.filter { $0.sectionID == nil || $0.sectionID?.isEmpty == true }
        
        // Sort by due date: tasks with due dates first (sorted by date), then tasks without due dates
        let sortedTasks = unsectioned.sorted { task1, task2 in
            switch (task1.dueDate, task2.dueDate) {
            case (let date1?, let date2?):
                // Both have due dates - sort by date (earliest first)
                return date1 < date2
            case (nil, _?):
                // task1 has no due date, task2 has due date - task2 comes first
                return false
            case (_?, nil):
                // task1 has due date, task2 has no due date - task1 comes first
                return true
            case (nil, nil):
                // Neither has due date - sort by creation date (newest first)
                return task1.createdDate > task2.createdDate
            }
        }
        
        if !sortedTasks.isEmpty {
            print("📋 Unsectioned tasks: \(sortedTasks.count) tasks sorted by due date")
        }
        return sortedTasks
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tasks")
                    .font(.title2)
                    .fontWeight(.medium)
                
                // Reminders sync status
                HStack(spacing: 4) {
                    Image(systemName: remindersService.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(remindersService.isAuthorized ? .green : .red)
                        .font(.caption)
                    
                    Text(syncStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // Permission request buttons (shown when not authorized)
                if !remindersService.isAuthorized {
                    permissionButtons
                }
                
                // Action buttons
                actionButtons
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    @ViewBuilder
    private var permissionButtons: some View {
        HStack(spacing: 4) {
            Button("Grant Access") {
                remindersService.requestAccess()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.orange)
            .help("Grant Reminders access to enable sync")
            
            Button("System Settings") {
                remindersService.openSystemSettings()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.blue)
            .help("Open System Settings to manually grant access")
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        // Manual sync button
        Button(action: { 
            syncWithReminders()
        }) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.primary)
        }
        .buttonStyle(.borderless)
        .disabled(!remindersService.isAuthorized)
        .help("Sync with Reminders")
        
        // Debug button - remove in production
        Button(action: { 
            printDebugInfo()
        }) {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Print Debug Info")
        
        // Section management button
        Button(action: { 
            showingSectionManager = true
        }) {
            Image(systemName: "folder.badge.plus")
                .foregroundColor(.primary)
        }
        .buttonStyle(.borderless)
        .help("Manage Sections")
        
        // Add task button
        Button(action: { 
            guard !isPerformingOperation else { return }
            isPerformingOperation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPerformingOperation = false
            }
            selectedTask = nil // This will show the create form in detail view
        }) {
            Image(systemName: "plus")
                .foregroundColor(.primary)
        }
        .buttonStyle(.borderless)
        .disabled(isPerformingOperation)
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        if tasks.isEmpty {
            emptyStateView
        } else {
            taskListView
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Text("No tasks yet")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text("Create a task manually or import emails from Gmail to get started.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button("Create First Task") {
                selectedTask = nil // This will show the create form in detail view
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var taskListView: some View {
        List(selection: $selectedTask) {
            // Debug: Print sections count
            let _ = print("📊 TaskListView sections count: \(sections.count)")
            
            // Show sections with their tasks
            ForEach(sections, id: \.id) { section in
                sectionView(for: section)
            }
            
            // Unsectioned tasks
            unsectionedTasksView
        }
        .listStyle(.sidebar)
        .onChange(of: selectedTask) { oldValue, newValue in
            // Add a small delay to prevent rapid state changes
            DispatchQueue.main.async {
                print("Selected task changed from \(oldValue?.title ?? "none") to \(newValue?.title ?? "none")")
            }
        }
    }
    
    @ViewBuilder
    private func sectionView(for section: TaskSection) -> some View {
        let sectionTasks = tasksForSection(section)
        let incompleteSectionTasks = sectionTasks.filter { !$0.isCompleted }
        let completedSectionTasks = sectionTasks.filter { $0.isCompleted }
        
        // Debug logging
        let _ = print("📊 Section '\(section.title)' has \(sectionTasks.count) tasks (\(incompleteSectionTasks.count) incomplete)")
        
        if !sectionTasks.isEmpty || true { // Always show sections, even if empty
            Section(header: sectionHeaderView(for: section, taskCount: incompleteSectionTasks.count)) {
                // Incomplete tasks for this section
                ForEach(incompleteSectionTasks, id: \.self) { task in
                    TaskRowView(task: task, onToggleCompletion: {
                        toggleTaskCompletion(task)
                    }, onDuplicateTask: { duplicatedTask in
                        selectedTask = duplicatedTask
                    })
                    .tag(task)
                }
                .onDelete { indexSet in
                    deleteSectionTasks(incompleteSectionTasks, at: indexSet)
                }
                
                // Completed tasks for this section
                if !completedSectionTasks.isEmpty {
                    DisclosureGroup("Completed (\(completedSectionTasks.count))") {
                        ForEach(completedSectionTasks, id: \.self) { task in
                            TaskRowView(task: task, onToggleCompletion: {
                                toggleTaskCompletion(task)
                            }, onDuplicateTask: { duplicatedTask in
                                selectedTask = duplicatedTask
                            })
                            .tag(task)
                        }
                        .onDelete { indexSet in
                            deleteSectionTasks(completedSectionTasks, at: indexSet)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var unsectionedTasksView: some View {
        let unsectioned = unsectionedTasks
        let incompleteUnsectioned = unsectioned.filter { !$0.isCompleted }
        let completedUnsectioned = unsectioned.filter { $0.isCompleted }
        
        if !unsectioned.isEmpty {
            Section("Other Tasks (\(incompleteUnsectioned.count))") {
                ForEach(incompleteUnsectioned, id: \.self) { task in
                    TaskRowView(task: task, onToggleCompletion: {
                        toggleTaskCompletion(task)
                    }, onDuplicateTask: { duplicatedTask in
                        selectedTask = duplicatedTask
                    })
                    .tag(task)
                }
                .onDelete { indexSet in
                    deleteSectionTasks(incompleteUnsectioned, at: indexSet)
                }
                
                if !completedUnsectioned.isEmpty {
                    DisclosureGroup("Completed (\(completedUnsectioned.count))") {
                        ForEach(completedUnsectioned, id: \.self) { task in
                            TaskRowView(task: task, onToggleCompletion: {
                                toggleTaskCompletion(task)
                            }, onDuplicateTask: { duplicatedTask in
                                selectedTask = duplicatedTask
                            })
                            .tag(task)
                        }
                        .onDelete { indexSet in
                            deleteSectionTasks(completedUnsectioned, at: indexSet)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        if let selectedTask = selectedTask {
            TaskDetailView(task: selectedTask)
        } else {
            CreateTaskDetailView(sections: sections, onTaskCreated: { task in
                selectedTask = task
            })
        }
    }
    
    @ViewBuilder
    private var mainNavigationView: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                headerView
                Divider()
                    .frame(height: 1)
                mainContentView
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 500)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.automatic)
    }
    
    @ViewBuilder
    private var sectionManagerSheet: some View {
        SectionManagerView()
            .environment(\.modelContext, modelContext)
            .onDisappear {
                // Force a refresh when the sheet is dismissed
                DispatchQueue.main.async {
                    refreshTrigger.toggle()
                }
            }
    }
    
    var body: some View {
        mainNavigationView
            .sheet(isPresented: $showingSectionManager) {
                sectionManagerSheet
            }
            .onAppear {
                handleOnAppear()
            }
            .onChange(of: refreshTrigger) { _, _ in
                // This onChange will trigger when refreshTrigger changes,
                // causing the view to re-evaluate and refresh the sections query
            }
            .onChange(of: tasks) { _, newTasks in
                handleTasksChange()
            }
            .onChange(of: sections) { _, newSections in
                handleSectionsChange()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UpdateTaskReminderID"))) { notification in
                handleTaskReminderIDUpdate(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UpdateSectionReminderID"))) { notification in
                handleSectionReminderIDUpdate(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TriggerRemindersSync"))) { _ in
                handleManualSyncRequest()
            }
    }
    
    // MARK: - Event Handlers
    
    private func handleOnAppear() {
        // Request Reminders access if not already authorized
        if !remindersService.isAuthorized {
            remindersService.requestAccess()
        }
    }
    
    private func handleTasksChange() {
        // Sync with Reminders whenever tasks change
        if remindersService.isAuthorized {
            syncWithReminders()
        }
    }
    
    private func handleSectionsChange() {
        // Sync with Reminders whenever sections change
        if remindersService.isAuthorized {
            syncWithReminders()
        }
    }
    
    private func handleTaskReminderIDUpdate(_ notification: Notification) {
        // Handle reminder ID updates from the RemindersService
        guard let userInfo = notification.userInfo,
              let taskIDString = userInfo["taskID"] as? String,
              let reminderID = userInfo["reminderID"] as? String else {
            print("❌ Invalid task reminder ID update notification")
            return
        }
        
        // Find task by matching the generated ID
        let matchingTask = tasks.first { task in
            let generatedID = task.persistentModelID.hashValue.description
            return generatedID == taskIDString
        }
        
        guard let task = matchingTask else {
            print("❌ Could not find task with ID: \(taskIDString)")
            return
        }
        
        print("📝 Updating reminder ID for task '\(task.title)' to: \(reminderID)")
        task.reminderID = reminderID
        task.lastSyncedToReminders = Date()
        
        // Save the context to persist changes
        do {
            try modelContext.save()
            print("✅ Successfully saved reminder ID update for task: \(task.title)")
            
            // Force UI refresh to show updated task organization
            DispatchQueue.main.async {
                refreshTrigger.toggle()
            }
        } catch {
            print("❌ Failed to save reminder ID update: \(error)")
            // Reset the reminder ID on failure to maintain consistency
            task.reminderID = nil
            task.lastSyncedToReminders = nil
        }
    }
    
    private func handleSectionReminderIDUpdate(_ notification: Notification) {
        // Handle section reminder ID updates from the RemindersService
        guard let userInfo = notification.userInfo,
              let sectionIDString = userInfo["sectionID"] as? String,
              let reminderID = userInfo["reminderID"] as? String else {
            return
        }
        
        // Find section by ID
        guard let section = sections.first(where: { $0.id == sectionIDString }) else {
            print("Could not find section with ID: \(sectionIDString)")
            return
        }
        
        section.reminderID = reminderID
        
        // Save the context to persist changes
        do {
            try modelContext.save()
            print("✅ Successfully saved section reminder ID update for: \(section.title)")
        } catch {
            print("❌ Failed to save section reminder ID update: \(error)")
            // Reset the reminder ID on failure
            section.reminderID = nil
        }
    }
    
    private func handleManualSyncRequest() {
        // Handle manual sync requests from task section assignments or other operations
        if remindersService.isAuthorized {
            print("📱 Manual sync requested - triggering Reminders sync")
            syncWithReminders()
        } else {
            print("📱 Manual sync requested but Reminders access not authorized")
        }
    }
    
    @ViewBuilder
    private func sectionHeaderView(for section: TaskSection, taskCount: Int) -> some View {
        HStack(spacing: 8) {
            // Simple color indicator (no hex color support)
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 12, height: 12)
            
            Text(section.title)
                .font(.headline)
                .fontWeight(.medium)
            
            Text("(\(taskCount))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private func toggleTaskCompletion(_ task: DiligenceTask) {
        withAnimation {
            task.isCompleted.toggle()
        }
        
        // Trigger sync after completion toggle
        if remindersService.isAuthorized {
            syncWithReminders()
        }
    }
    
    
      private func syncWithReminders() {
          guard !tasks.isEmpty || !sections.isEmpty else {
              print("📝 Skipping Reminders sync - no tasks or sections to sync")
              return
          }
          
          print("📝 Starting sync with Reminders: \(sections.count) sections, \(tasks.count) tasks")
          
          let taskData = tasks.map { task in
              TaskSyncData(
                  id: task.persistentModelID.hashValue.description, // Use hashValue as string ID
                  title: task.title,
                  description: task.taskDescription,
                  isCompleted: task.isCompleted,
                  dueDate: task.dueDate,
                  reminderID: task.reminderID,
                  isFromEmail: task.isFromEmail,
                  emailSender: task.emailSender,
                  emailSubject: task.emailSubject,
                  sectionID: task.sectionID,
                  recurrencePattern: task.recurrencePattern,
                  recurrenceDescription: (task as DiligenceTask).recurrenceDescription,
                  isRecurringInstance: task.isRecurringInstance
              )
          }
          
          let sectionData = sections.map { section in
              SectionSyncData(
                  id: section.id,
                  title: section.title,
                  color: nil,
                  sortOrder: section.sortOrder,
                  reminderID: section.reminderID
              )
          }
          
          // Debug logging for section assignments
          let tasksWithSections = taskData.filter { $0.sectionID != nil }
          if !tasksWithSections.isEmpty {
              print("📝 Tasks with section assignments:")
              for task in tasksWithSections {
                  let sectionTitle = sections.first(where: { $0.id == task.sectionID })?.title ?? "Unknown"
                  print("  - '\(task.title)' -> '\(sectionTitle)' (\(task.sectionID!))")
              }
          }
          
          remindersService.forceSyncNow(taskData: taskData, sectionData: sectionData)
      }
      
    
      
    private func printDebugInfo() {
        print("\n🔍 === DEBUG INFO ===")
        print("📊 Total tasks: \(tasks.count)")
        print("📊 Total sections: \(sections.count)")
        print("📊 Incomplete tasks: \(incompleteTasks.count)")
        print("📊 Completed tasks: \(completedTasks.count)")
        print("📊 Reminders authorized: \(remindersService.isAuthorized)")
        print("📊 Sync status: \(remindersService.syncStatus)")
        
        print("\n📋 Tasks breakdown:")
        for task in tasks.prefix(10) {
            let sectionTitle = sections.first(where: { $0.id == task.sectionID })?.title ?? "No Section"
            let reminderStatus = task.reminderID != nil ? "Has Reminder ID" : "No Reminder ID"
            print("  • '\(task.title)' - \(sectionTitle) - \(reminderStatus)")
        }
        
        print("\n📁 Sections breakdown:")
        for section in sections {
            let taskCount = tasks.filter { $0.sectionID == section.id }.count
            let reminderStatus = section.reminderID != nil ? "Has Reminder ID" : "No Reminder ID" 
            print("  • '\(section.title)' (\(taskCount) tasks) - \(reminderStatus)")
        }
        
        print("🔍 === END DEBUG INFO ===\n")
    }
    
    private func testRemindersSync() {
        print("🧪 === TESTING REMINDERS SYNC ===")
        guard remindersService.isAuthorized else {
            print("❌ Cannot test sync - not authorized for Reminders")
            return
        }
        
        remindersService.testSync()
    }
    
    private func deleteSectionTasks(_ tasksArray: [DiligenceTask], at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(tasksArray[index])
            }
        }
    }
    
    private func deleteIncompleteTasks(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(incompleteTasks[index])
            }
        }
    }
    
    private func deleteCompletedTasks(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(completedTasks[index])
            }
        }
    }
}

struct TaskRowView: View {
    let task: DiligenceTask
    let onToggleCompletion: () -> Void
    let onDuplicateTask: ((DiligenceTask) -> Void)? // New callback for task duplication
    @Query(sort: [SortDescriptor(\TaskSection.sortOrder)]) private var sections: [TaskSection]
    @Environment(\.modelContext) private var modelContext
    
    init(task: DiligenceTask, onToggleCompletion: @escaping () -> Void, onDuplicateTask: ((DiligenceTask) -> Void)? = nil) {
        self.task = task
        self.onToggleCompletion = onToggleCompletion
        self.onDuplicateTask = onDuplicateTask
    }
    
    // Date formatter for task list due date: dd-MMM-yy
    private static let dueDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yy"
        return formatter
    }()
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Priority indicator (visual accent)
            PriorityIndicator(priority: task.priority, showAccentBar: false)
            
            // Completion toggle
            Button(action: onToggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .secondary)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                // Task title
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                
                // Email info if task is from email
                if task.isFromEmail {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope")
                            .foregroundColor(.blue)
                            .font(.caption)
                        
                        if let emailSubject = task.emailSubject {
                            Text(emailSubject)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                // Description preview
                if !task.taskDescription.isEmpty {
                    Text(task.taskDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Due date
                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(dueDate < Date() ? .red : .orange)
                            .font(.caption)
                        
                        Text(TaskRowView.dueDateFormatter.string(from: dueDate) + (dueDate < Date() ? " (Overdue)" : ""))
                            .font(.caption)
                            .foregroundColor(dueDate < Date() ? .red : .orange)
                        
                        // Show recurrence indicator
                        if task.isRecurring || task.isRecurringInstance {
                            Image(systemName: task.recurrencePattern.systemImageName)
                                .foregroundColor(.blue)
                                .font(.caption2)
                        }
                    }
                }
                
                // Show recurrence description for recurring tasks
                if task.isRecurring && !task.hasRecurrenceEnded {
                    Text(task.recurrenceDescription)
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                // Show amount for bills/invoices
                if let amount = task.amount, amount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text("$\(formatAmountWithCommas(amount))")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contextMenu {
            // Section assignment menu
            Menu("Assign to Section") {
                Button(action: { assignToSection(nil) }) {
                    HStack {
                        Text("No Section")
                        Spacer()
                        if task.sectionID == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Divider()
                
                ForEach(sections, id: \.id) { section in
                    Button(action: { assignToSection(section.id) }) {
                        HStack {
                            Text(section.title)
                            Spacer()
                            
                            if task.sectionID == section.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Duplicate task option
            Button("Duplicate Task") {
                duplicateTask()
            }
            
            Divider()
            
            // Quick actions
            Button("Mark as \(task.isCompleted ? "Incomplete" : "Complete")") {
                onToggleCompletion()
            }
        }
    }
    
    private func assignToSection(_ sectionID: String?) {
        let oldSectionID = task.sectionID
        task.sectionID = sectionID
        
        // Get section name for logging
        let oldSectionName = oldSectionID != nil ? (sections.first(where: { $0.id == oldSectionID })?.title ?? "Unknown Section") : "none"
        let newSectionName = sectionID != nil ? (sections.first(where: { $0.id == sectionID })?.title ?? "Unknown Section") : "none"
        
        print("📝 Assigning task '\(task.title)' from section '\(oldSectionName)' to section '\(newSectionName)'")
        
        do {
            try modelContext.save()
            print("✅ Successfully updated task section assignment")
            
            // Add a small delay before triggering sync to ensure the UI has updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Trigger sync with Reminders after successful section assignment
                NotificationCenter.default.post(
                    name: Notification.Name("TriggerRemindersSync"), 
                    object: nil
                )
                print("📱 Triggered Reminders sync after task section assignment")
            }
        } catch {
            print("❌ Failed to update task section: \(error)")
            // Revert on failure
            task.sectionID = oldSectionID
        }
    }
    
    private func duplicateTask() {
        // Create a duplicate of the task with a modified title
        let duplicatedTask = DiligenceTask(
            title: "\(task.title) (Copy)",
            taskDescription: task.taskDescription,
            isCompleted: false, // Reset completion status for the copy
            createdDate: Date(), // Set new creation date
            dueDate: task.dueDate,
            emailID: task.emailID,
            emailSubject: task.emailSubject,
            emailSender: task.emailSender,
            gmailURL: task.gmailURL,
            reminderID: nil, // Don't copy reminder ID - let it sync as a new task
            sectionID: task.sectionID, // Keep the same section
            amount: task.amount, // Copy the amount for bills/invoices
            recurrencePattern: task.recurrencePattern,
            recurrenceInterval: task.recurrenceInterval,
            recurrenceEndType: task.recurrenceEndType,
            recurrenceEndDate: task.recurrenceEndDate,
            recurrenceEndCount: task.recurrenceEndCount,
            recurrenceWeekdays: task.recurrenceWeekdays,
            parentRecurringTaskID: nil, // Don't copy recurring relationship
            isRecurringInstance: false,
            recurringInstanceDate: nil
        )
        
        // Insert the new task into the model context
        modelContext.insert(duplicatedTask)
        
        do {
            try modelContext.save()
            print("✅ Successfully duplicated task: \(task.title)")
            
            // Notify the parent view to select the new duplicated task for editing
            onDuplicateTask?(duplicatedTask)
            
            // Trigger sync with Reminders for the new task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: Notification.Name("TriggerRemindersSync"), 
                    object: nil
                )
            }
        } catch {
            print("❌ Failed to duplicate task: \(error)")
            // Remove the task from context if save failed
            modelContext.delete(duplicatedTask)
        }
    }
    
    private func formatAmountWithCommas(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
}

struct TaskDetailView: View {
    let task: DiligenceTask
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\TaskSection.sortOrder)]) private var sections: [TaskSection]
    
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    @State private var editedDescription: String = ""
    @State private var editedDueDate: Date = Date()
    @State private var editedHasDueDate: Bool = false
    @State private var editedSectionID: String? = nil
    @State private var editedAmount: String = ""
    @State private var editedHasAmount: Bool = false
    @State private var editedPriority: TaskPriority = .medium
    
    // DateFormatter for created date: HH:mm:ss dd-MMM-yy
    private static let createdDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss dd-MMM-yy"
        return formatter
    }()
    
    // DateFormatter for due date with time: HH:mm:ss dd-MMM-yy
    private static let dueDateWithTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss dd-MMM-yy"
        return formatter
    }()
    
    // DateFormatter for due date date only: dd-MMM-yy
    private static let dueDateDateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yy"
        return formatter
    }()
    
    // Helper function to check if time component is set (i.e. not at midnight)
    private func dueDateHasTime(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        return hour != 0 || minute != 0 || second != 0
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Task header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        if isEditing {
                            TextField("Task Title", text: $editedTitle)
                                .textFieldStyle(.roundedBorder)
                                .font(.title)
                        } else {
                            Text(task.title)
                                .font(.title)
                                .fontWeight(.medium)
                                .textSelection(.enabled)
                        }
                        
                        HStack(spacing: 16) {
                            // Completion status
                            Button(action: toggleCompletion) {
                                HStack(spacing: 6) {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(task.isCompleted ? .green : .secondary)
                                    
                                    Text(task.isCompleted ? "Completed" : "To Do")
                                        .font(.subheadline)
                                        .foregroundColor(task.isCompleted ? .green : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            // Created date
                            Text("Created: \(Self.createdDateFormatter.string(from: task.createdDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Action buttons section (matching Gmail view pattern)
                    HStack(spacing: 8) {
                        // Delete button (trash icon)
                        Button(action: deleteTask) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .help("Delete Task")
                        
                        // Edit button
                        Button(isEditing ? "Save" : "Edit") {
                            if isEditing {
                                saveChanges()
                            } else {
                                startEditing()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                Divider()
                
                // Section assignment
                VStack(alignment: .leading, spacing: 8) {
                    Text("Section")
                        .font(.headline)
                    
                    if isEditing {
                        Picker("Section", selection: $editedSectionID) {
                            Text("No Section")
                                .tag(nil as String?)
                            
                            ForEach(sections, id: \.id) { section in
                                HStack {
                                    Text(section.title)
                                }
                                .tag(section.id as String?)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        if let sectionID = task.sectionID,
                           let section = sections.first(where: { $0.id == sectionID }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 12, height: 12)
                                
                                Text(section.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .textSelection(.enabled)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        } else {
                            Text("No section assigned")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
                
                Divider()
                
                // Priority section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Priority")
                        .font(.headline)
                    
                    if isEditing {
                        PriorityPicker(selection: $editedPriority, style: .buttons, showNone: false)
                    } else {
                        PriorityBadge(priority: task.priority, style: .full)
                    }
                }
                
                Divider()
                
                // Due date section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Due Date")
                        .font(.headline)
                    
                    if isEditing {
                        Toggle("Set Due Date", isOn: $editedHasDueDate)
                            .toggleStyle(SwitchToggleStyle())
                        
                        if editedHasDueDate {
                            DatePicker("Due Date", selection: $editedDueDate, displayedComponents: [.date, .hourAndMinute])
                        }
                    } else {
                        if let dueDate = task.dueDate {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .foregroundColor(dueDate < Date() ? .red : .orange)
                                
                                if dueDateHasTime(dueDate) {
                                    Text("\(Self.dueDateWithTimeFormatter.string(from: dueDate))\(dueDate < Date() ? " (Overdue)" : "")")
                                        .foregroundColor(dueDate < Date() ? .red : .orange)
                                        .textSelection(.enabled)
                                } else {
                                    Text("\(Self.dueDateDateOnlyFormatter.string(from: dueDate))\(dueDate < Date() ? " (Overdue)" : "")")
                                        .foregroundColor(dueDate < Date() ? .red : .orange)
                                        .textSelection(.enabled)
                                }
                            }
                        } else {
                            Text("No due date set")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
                
                Divider()
                
                // Description section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                    
                    if isEditing {
                        TextEditor(text: $editedDescription)
                            .frame(minHeight: 100, maxHeight: 200)
                            .border(Color.gray.opacity(0.3), width: 1)
                    } else {
                        if !task.taskDescription.isEmpty {
                            Text(task.taskDescription)
                                .textSelection(.enabled)
                                .padding()
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                        } else {
                            Text("No description")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
                
                Divider()
                
                // Amount section for bills/invoices
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.headline)
                    
                    if isEditing {
                        HStack(spacing: 8) {
                            Text("$")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            TextField("0.00", text: $editedAmount)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }
                        
                        Text("Optional - for bills, invoices, or financial tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        if let amount = task.amount, amount > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "dollarsign.circle")
                                    .foregroundColor(.green)
                                
                                Text("$\(formatAmountWithCommas(amount))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .textSelection(.enabled)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        } else {
                            Text("No amount set")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
                
                // Email info section
                if task.isFromEmail {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.blue)
                            
                            Text("Created from Email")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            if let emailSubject = task.emailSubject {
                                HStack {
                                    Text("Subject:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(emailSubject)
                                        .font(.subheadline)
                                        .textSelection(.enabled)
                                }
                            }
                            
                            if let emailSender = task.emailSender {
                                HStack {
                                    Text("From:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(emailSender)
                                        .font(.subheadline)
                                        .textSelection(.enabled)
                                }
                            }
                            
                            if let gmailURL = task.gmailURLObject {
                                Button("Open Email in Gmail") {
                                    NSWorkspace.shared.open(gmailURL)
                                }
                                .buttonStyle(.bordered)
                                .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24) // Balanced horizontal padding
            .padding(.vertical, 16)   // Comfortable vertical padding
        }
        .navigationTitle("Task Details")
    }
    
    private func startEditing() {
        editedTitle = task.title
        editedDescription = task.taskDescription
        editedHasDueDate = task.dueDate != nil
        editedSectionID = task.sectionID
        editedPriority = task.priority
        if let dueDate = task.dueDate {
            editedDueDate = dueDate
        }
        
        // Initialize amount fields
        editedHasAmount = task.amount != nil && task.amount! > 0
        editedAmount = task.amount != nil ? String(format: "%.2f", task.amount!) : ""
        
        isEditing = true
    }
    
    private func formatAmountWithCommas(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
    
    private func saveChanges() {
        task.title = editedTitle
        task.taskDescription = editedDescription
        task.dueDate = editedHasDueDate ? editedDueDate : nil
        task.sectionID = editedSectionID
        task.priority = editedPriority
        
        // Save amount for bills/invoices (no toggle needed)
        if !editedAmount.isEmpty, let amountValue = Double(editedAmount.replacingOccurrences(of: ",", with: "")) {
            task.amount = amountValue
        } else {
            task.amount = nil
        }
        
        isEditing = false
        
        // Trigger sync with Reminders after saving changes
        NotificationCenter.default.post(
            name: Notification.Name("TriggerRemindersSync"), 
            object: nil
        )
    }
    
    private func toggleCompletion() {
        withAnimation {
            task.isCompleted.toggle()
        }
    }
    
    private func deleteTask() {
        modelContext.delete(task)
    }
}

struct CreateTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\TaskSection.sortOrder)]) private var sections: [TaskSection]
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var dueDate: Date = Date().addingTimeInterval(86400) // Tomorrow
    @State private var hasDueDate: Bool = false
    @State private var selectedSectionID: String? = nil
    @State private var priority: TaskPriority = .medium
    
    // Recurrence properties
    @State private var recurrencePattern: RecurrencePattern = .never
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceWeekdays: [Int] = []
    @State private var recurrenceEndType: RecurrenceEndType = .never
    @State private var recurrenceEndDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var recurrenceEndCount: Int = 10
    
    // DateFormatter for due date in create view: dd-MMM-yy (and HH:mm:ss if time set)
    private static let dueDateWithTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss dd-MMM-yy"
        return formatter
    }()
    
    private static let dueDateDateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yy"
        return formatter
    }()
    
    // Helper function to check if time component is set (i.e. not at midnight)
    private func dueDateHasTime(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        return hour != 0 || minute != 0 || second != 0
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Form {
                    Section("Task Details") {
                        TextField("Task Title", text: $title)
                            .textFieldStyle(.roundedBorder)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description (optional)")
                                .font(.headline)
                            
                            TextEditor(text: $description)
                                .frame(minHeight: 100, maxHeight: 200)
                                .border(Color.gray.opacity(0.3), width: 1)
                        }
                        
                        // Priority selection
                        VStack(alignment: .leading, spacing: 8) {
                            PriorityPicker(selection: $priority, style: .buttons, showNone: false)
                        }
                        
                        // Section selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Section (optional)")
                                .font(.headline)
                            
                            Picker("Section", selection: $selectedSectionID) {
                                Text("No Section")
                                    .tag(nil as String?)
                                
                                ForEach(sections, id: \.id) { section in
                                    HStack {
                                        Text(section.title)
                                    }
                                    .tag(section.id as String?)
                                }
                            }
                            .pickerStyle(.automatic)
                        }
                        
                        Toggle("Set Due Date", isOn: $hasDueDate)
                        
                        if hasDueDate {
                            DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                            
                            // Show selected due date in dd-MMM-yy (and HH:mm:ss if time set)
                            let formattedDueDate = dueDateHasTime(dueDate) ?
                                Self.dueDateWithTimeFormatter.string(from: dueDate) :
                                Self.dueDateDateOnlyFormatter.string(from: dueDate)
                            Text("Selected due date: \(formattedDueDate)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Create New Task")
            .frame(minWidth: 400, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        }
    }
    
    private func createTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        // Create the main task with recurrence settings
        let newTask = DiligenceTask(
            title: trimmedTitle,
            taskDescription: description,
            dueDate: hasDueDate ? dueDate : nil,
            sectionID: selectedSectionID,
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
        } catch {
            print("Failed to save task: \(error)")
        }
        
        dismiss()
    }
}

struct CreateTaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let sections: [TaskSection]
    let onTaskCreated: (DiligenceTask) -> Void
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var dueDate: Date = Date().addingTimeInterval(86400) // Tomorrow
    @State private var hasDueDate: Bool = false
    @State private var selectedSectionID: String? = nil
    @State private var amount: String = ""
    @State private var hasAmount: Bool = false
    @State private var priority: TaskPriority = .medium
    
    // Recurrence properties
    @State private var recurrencePattern: RecurrencePattern = .never
    @State private var recurrenceInterval: Int = 1
    @State private var recurrenceWeekdays: [Int] = []
    @State private var recurrenceEndType: RecurrenceEndType = .never
    @State private var recurrenceEndDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var recurrenceEndCount: Int = 10
    
    // DateFormatter for due date in create view: dd-MMM-yy (and HH:mm:ss if time set)
    private static let dueDateWithTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss dd-MMM-yy"
        return formatter
    }()
    
    private static let dueDateDateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yy"
        return formatter
    }()
    
    // Helper function to check if time component is set (i.e. not at midnight)
    private func dueDateHasTime(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        return hour != 0 || minute != 0 || second != 0
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create New Task")
                        .font(.title)
                        .fontWeight(.medium)
                    
                    Text("Fill out the details below to create a new task")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Task title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.headline)
                    
                    TextField("Enter task title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                    
                    Text("Optional - provide additional details about the task")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $description)
                        .frame(minHeight: 120, maxHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Priority section
                VStack(alignment: .leading, spacing: 8) {
                    PriorityPicker(selection: $priority, style: .buttons, showNone: false)
                }
                
                // Section selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Section")
                        .font(.headline)
                    
                    Text("Optional - assign this task to a section")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Section", selection: $selectedSectionID) {
                        Text("No Section")
                            .tag(nil as String?)
                        
                        ForEach(sections, id: \.id) { section in
                            HStack {
                                Text(section.title)
                            }
                            .tag(section.id as String?)
                        }
                    }
                    .pickerStyle(.automatic)
                }
                
                // Amount section for bills/invoices
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.headline)
                    
                    Text("Optional - for bills, invoices, or financial tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text("$")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TextField("0.00", text: $amount)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                    }
                    
                    if !amount.isEmpty, let amountValue = Double(amount.replacingOccurrences(of: ",", with: "")) {
                        HStack(spacing: 6) {
                            Image(systemName: "dollarsign.circle")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text("Amount: $\(formatAmountWithCommas(amountValue))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Due date section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Due Date")
                        .font(.headline)
                    
                    Toggle("Set due date", isOn: $hasDueDate)
                        .toggleStyle(SwitchToggleStyle())
                    
                    if hasDueDate {
                        VStack(alignment: .leading, spacing: 8) {
                            DatePicker("Due date and time", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                            
                            // Show selected due date in dd-MMM-yy (and HH:mm:ss if time set)
                            let formattedDueDate = dueDateHasTime(dueDate) ?
                                Self.dueDateWithTimeFormatter.string(from: dueDate) :
                                Self.dueDateDateOnlyFormatter.string(from: dueDate)
                            
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                
                                Text("Due: \(formattedDueDate)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                
                // Recurrence section - only show if due date is set
                if hasDueDate {
                    VStack(alignment: .leading, spacing: 12) {
                        RecurrenceQuickSetupView(
                            recurrencePattern: $recurrencePattern,
                            recurrenceInterval: $recurrenceInterval,
                            recurrenceWeekdays: $recurrenceWeekdays,
                            recurrenceEndType: $recurrenceEndType,
                            recurrenceEndDate: $recurrenceEndDate,
                            recurrenceEndCount: $recurrenceEndCount
                        )
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Clear Form") {
                        clearForm()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Create Task") {
                        createTask()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24) // Balanced horizontal padding
            .padding(.vertical, 16)   // Comfortable vertical padding
        }
        .navigationTitle("New Task")
    }
    
    private func clearForm() {
        title = ""
        description = ""
        dueDate = Date().addingTimeInterval(86400) // Tomorrow
        hasDueDate = false
        selectedSectionID = nil
        amount = ""
        hasAmount = false
        priority = .medium
        
        // Reset recurrence settings
        recurrencePattern = .never
        recurrenceInterval = 1
        recurrenceWeekdays = []
        recurrenceEndType = .never
        recurrenceEndDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
        recurrenceEndCount = 10
    }
    
    private func formatAmountWithCommas(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
    
    private func createTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let newTask = DiligenceTask(
            title: trimmedTitle,
            taskDescription: description,
            dueDate: hasDueDate ? dueDate : nil,
            sectionID: selectedSectionID,
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
        
        // Set amount for bills/invoices (no toggle needed)
        if !amount.isEmpty, let amountValue = Double(amount.replacingOccurrences(of: ",", with: "")) {
            newTask.amount = amountValue
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
            onTaskCreated(newTask) // Select the newly created task
            clearForm() // Reset the form
        } catch {
            print("Failed to save task: \(error)")
        }
    }
}

struct SectionManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\TaskSection.sortOrder)]) private var sections: [TaskSection]
    
    @State private var newSectionTitle = ""
    @State private var editingSection: TaskSection?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Manage Sections")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Create and organize sections to group your tasks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Add new section form
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        TextField("Section name", text: $newSectionTitle)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Add Section") {
                            addSection()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                .background(Color(NSColor.textBackgroundColor))
                
                Divider()
                
                // Sections list
                if sections.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No sections yet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("Create your first section to organize your tasks")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let _ = print("📊 SectionManagerView sections count: \(sections.count)")
                    List {
                        ForEach(sections, id: \.id) { section in
                            SectionRowView(
                                section: section,
                                onDelete: { deleteSection(section) }
                            )
                        }
                        .onMove(perform: moveSections)
                    }
                    .listStyle(.plain)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
    }
    
    private func addSection() {
        let trimmedTitle = newSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let newSection = TaskSection(
            title: trimmedTitle,
            sortOrder: sections.count
        )
        
        modelContext.insert(newSection)
        
        do {
            try modelContext.save()
            print("✅ Successfully added section: \(trimmedTitle)")
            
            // Reset form
            newSectionTitle = ""
            
        } catch {
            print("❌ Failed to save section: \(error)")
        }
    }
    
    private func deleteSection(_ section: TaskSection) {
        modelContext.delete(section)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete section: \(error)")
        }
    }
    
    private func moveSections(from source: IndexSet, to destination: Int) {
        var updatedSections = sections
        updatedSections.move(fromOffsets: source, toOffset: destination)
        
        // Update sort orders
        for (index, section) in updatedSections.enumerated() {
            section.sortOrder = index
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to reorder sections: \(error)")
        }
    }
}

struct SectionRowView: View {
    @State private var section: TaskSection
    let onDelete: () -> Void
    
    @State private var isEditing = false
    @State private var editTitle = ""
    
    @Environment(\.modelContext) private var modelContext
    
    init(section: TaskSection, onDelete: @escaping () -> Void) {
        self._section = State(initialValue: section)
        self.onDelete = onDelete
        self._editTitle = State(initialValue: section.title)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Simple color indicator
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 16, height: 16)
            
            // Section title
            if isEditing {
                TextField("Section name", text: $editTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        saveChanges()
                    }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.headline)
                    
                    Text("Sort order: \(section.sortOrder)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                if isEditing {
                    Button("Save") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button("Cancel") {
                        cancelEdit()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Edit") {
                        startEdit()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Delete") {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func startEdit() {
        editTitle = section.title
        isEditing = true
    }
    
    private func cancelEdit() {
        editTitle = section.title
        isEditing = false
    }
    
    private func saveChanges() {
        let trimmedTitle = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        section.title = trimmedTitle
        
        do {
            try modelContext.save()
            isEditing = false
        } catch {
            print("Failed to save section changes: \(error)")
        }
    }
}

#Preview {
    TaskListView()
        .modelContainer(for: [DiligenceTask.self, TaskSection.self], inMemory: true)
}

