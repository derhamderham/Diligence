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
        self.reminderID = nil
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
    @State private var isSyncing = false // Prevent recursive sync operations
    
    // MARK: - Search State
    @State private var searchText: String = ""
    @State private var showingSearchHelp = false
    @State private var parsedQuery: SearchQuery = SearchQuery()
    
    private var syncStatusText: String {
        return remindersService.getSyncStatusText()
    }
    
    // MARK: - Filtered Tasks
    
    /// All tasks filtered by the current search query
    var filteredTasks: [DiligenceTask] {
        if searchText.isEmpty {
            return tasks
        }
        return tasks.filter { task in
            TaskSearchFilter.matches(task: task, query: parsedQuery, sections: sections)
        }
    }
    
    var incompleteTasks: [DiligenceTask] {
        filteredTasks.filter { !$0.isCompleted }
    }
    
    var completedTasks: [DiligenceTask] {
        filteredTasks.filter { $0.isCompleted }
    }
    
    // Group tasks by sections and sort by due date
    func tasksForSection(_ section: TaskSection) -> [DiligenceTask] {
        let tasksInSection = filteredTasks.filter { $0.sectionID == section.id }
        
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
        let unsectioned = filteredTasks.filter { $0.sectionID == nil || $0.sectionID?.isEmpty == true }
        
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
        VStack(spacing: 0) {
            // Title and actions row
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
            
            // Search bar
            searchBarView
        }
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
    
    // MARK: - Search Bar
    
    @ViewBuilder
    private var searchBarView: some View {
        HStack(spacing: 8) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.body)
            
            // Search text field
            TextField("Search tasks...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .onChange(of: searchText) { oldValue, newValue in
                    // Parse the search query as user types
                    parsedQuery = TaskSearchParser.parse(newValue)
                }
            
            // Clear button
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    parsedQuery = SearchQuery()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
            
            // Help button
            Button(action: {
                showingSearchHelp.toggle()
            }) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Search syntax help")
            .popover(isPresented: $showingSearchHelp) {
                searchHelpView
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var searchHelpView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced Search Syntax")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                searchHelpSection(
                    title: "Basic Search",
                    examples: [
                        ("payroll", "Find tasks containing 'payroll'"),
                        ("payroll tax", "Find tasks with both 'payroll' AND 'tax'")
                    ]
                )
                
                Divider()
                
                searchHelpSection(
                    title: "Operators",
                    examples: [
                        ("payroll OR invoice", "Tasks with either term"),
                        ("payroll NOT tax", "Tasks with 'payroll' but not 'tax'"),
                        ("-tax", "Exclude tasks with 'tax'"),
                        ("\"payroll tax\"", "Exact phrase match")
                    ]
                )
                
                Divider()
                
                searchHelpSection(
                    title: "Wildcards",
                    examples: [
                        ("pay*", "Matches payroll, payment, pay, etc.")
                    ]
                )
                
                Divider()
                
                searchHelpSection(
                    title: "Field-Specific Filters",
                    examples: [
                        ("title:payroll", "Search only in title"),
                        ("amount:>5000", "Amount greater than 5000"),
                        ("amount:<1000", "Amount less than 1000"),
                        ("priority:high", "High priority tasks"),
                        ("status:completed", "Completed tasks"),
                        ("section:work", "Tasks in 'work' section"),
                        ("due:today", "Due today"),
                        ("due:>today", "Due after today")
                    ]
                )
                
                Divider()
                
                searchHelpSection(
                    title: "Complex Examples",
                    examples: [
                        ("payroll AND amount:>5000", "Payroll tasks over $5000"),
                        ("priority:high OR priority:medium", "Medium or high priority"),
                        ("invoice NOT status:completed", "Incomplete invoices"),
                        ("\"tax return\" AND due:<today", "Overdue tax returns")
                    ]
                )
            }
            
            Text("💡 Tip: Searches are case-insensitive and match across title, description, amount, section, and more.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .frame(width: 450)
    }
    
    @ViewBuilder
    private func searchHelpSection(title: String, examples: [(query: String, description: String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(examples, id: \.query) { example in
                    HStack(alignment: .top, spacing: 8) {
                        Text(example.query)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                        
                        Text("—")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text(example.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        // Export button
        Button(action: { 
            exportTasks()
        }) {
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(.primary)
        }
        .buttonStyle(.borderless)
        .help("Export Tasks to Excel")
        .disabled(filteredTasks.isEmpty)
        
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
        if filteredTasks.isEmpty {
            emptyStateView
        } else {
            taskListView
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            if !searchText.isEmpty {
                // No search results
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("No tasks found")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text("No tasks match '\(searchText)'")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Button("Clear Search") {
                    searchText = ""
                    parsedQuery = SearchQuery()
                }
                .buttonStyle(.borderedProminent)
            } else {
                // No tasks at all
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var taskListView: some View {
        List(selection: $selectedTask) {
            // Search results indicator
            if !searchText.isEmpty {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text("Showing \(filteredTasks.count) of \(tasks.count) tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Clear") {
                            searchText = ""
                            parsedQuery = SearchQuery()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Debug: Print sections count
            let _ = print("📊 TaskListView sections count: \(sections.count)")
            
            // Show sections with their INCOMPLETE tasks only
            ForEach(sections, id: \.id) { section in
                incompleteSectionView(for: section)
            }
            
            // Unsectioned incomplete tasks
            incompleteUnsectionedTasksView
            
            // All completed tasks at the bottom, organized by section
            completedTasksView
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
    private func incompleteSectionView(for section: TaskSection) -> some View {
        let sectionTasks = tasksForSection(section)
        let incompleteSectionTasks = sectionTasks.filter { !$0.isCompleted }
        
        // Debug logging
        let _ = print("📊 Section '\(section.title)' has \(incompleteSectionTasks.count) incomplete tasks")
        
        // Only show sections that have incomplete tasks
        if !incompleteSectionTasks.isEmpty {
            Section(header: sectionHeaderView(for: section, taskCount: incompleteSectionTasks.count)) {
                // Incomplete tasks for this section only
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
            }
        }
    }
    
    @ViewBuilder
    private var incompleteUnsectionedTasksView: some View {
        let unsectioned = unsectionedTasks
        let incompleteUnsectioned = unsectioned.filter { !$0.isCompleted }
        
        if !incompleteUnsectioned.isEmpty {
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
            }
        }
    }
    
    @ViewBuilder
    private var completedTasksView: some View {
        let allCompletedTasks = tasks.filter { $0.isCompleted }
        
        if !allCompletedTasks.isEmpty {
            Section {
                DisclosureGroup("Completed Tasks (\(allCompletedTasks.count))") {
                    // Show completed tasks grouped by section
                    ForEach(sections, id: \.id) { section in
                        completedTasksForSection(section)
                    }
                    
                    // Completed unsectioned tasks
                    completedUnsectionedTasksSubView
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func completedTasksForSection(_ section: TaskSection) -> some View {
        let sectionTasks = tasksForSection(section)
        let completedSectionTasks = sectionTasks.filter { $0.isCompleted }
        
        if !completedSectionTasks.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                // Section header for completed tasks
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    Text(section.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("(\(completedSectionTasks.count))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                .padding(.leading, 8)
                
                // Completed tasks in this section
                ForEach(completedSectionTasks, id: \.self) { task in
                    TaskRowView(task: task, onToggleCompletion: {
                        toggleTaskCompletion(task)
                    }, onDuplicateTask: { duplicatedTask in
                        selectedTask = duplicatedTask
                    })
                    .tag(task)
                }
            }
        }
    }
    
    @ViewBuilder
    private var completedUnsectionedTasksSubView: some View {
        let unsectioned = unsectionedTasks
        let completedUnsectioned = unsectioned.filter { $0.isCompleted }
        
        if !completedUnsectioned.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                // Header for completed unsectioned tasks
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    Text("Other Tasks")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("(\(completedUnsectioned.count))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                .padding(.leading, 8)
                
                // Completed unsectioned tasks
                ForEach(completedUnsectioned, id: \.self) { task in
                    TaskRowView(task: task, onToggleCompletion: {
                        toggleTaskCompletion(task)
                    }, onDuplicateTask: { duplicatedTask in
                        selectedTask = duplicatedTask
                    })
                    .tag(task)
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
        HStack(spacing: 0) {
            // List pane
            VStack(spacing: 0) {
                headerView
                Divider()
                    .frame(height: 1)
                mainContentView
            }
            .frame(minWidth: 300, idealWidth: 400, maxWidth: 500)
            
            Divider()
            
            // Detail pane
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
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
        // NUCLEAR OPTION: Force delete all corrupted sections without accessing their properties
        forceDeleteCorruptedSections()
        
        // Delete badly reconstructed sections and redo with better logic
        redoSectionReconstruction()
        
        // Then reconstruct sections from task data with improved name detection
        reconstructMissingSections()
        
        // Request Reminders access if not already authorized
        if !remindersService.isAuthorized {
            remindersService.requestAccess()
        }
    }
    
    /// Deletes all existing sections so reconstruction can run again with better logic
    private func redoSectionReconstruction() {
        let redoKey = "RedoSectionReconstruction_v2" // v2 to run again with improved patterns
        if UserDefaults.standard.bool(forKey: redoKey) {
            return // Already ran
        }
        
        print("🔄 Preparing to redo section reconstruction with improved name detection...")
        
        // Delete all currently existing sections (they were badly named)
        let sectionsToDelete = sections
        if !sectionsToDelete.isEmpty {
            print("🗑️ Deleting \(sectionsToDelete.count) existing sections to redo reconstruction...")
            
            for section in sectionsToDelete {
                modelContext.delete(section)
            }
            
            do {
                try modelContext.save()
                print("✅ Deleted existing sections")
            } catch {
                print("❌ Failed to delete sections: \(error)")
            }
        }
        
        UserDefaults.standard.set(true, forKey: redoKey)
    }
    
    /// Force deletes all sections in the database without trying to access their properties
    ///
    /// This is the nuclear option for dealing with corrupted SwiftData objects that
    /// crash when their properties are accessed.
    private func forceDeleteCorruptedSections() {
        let deleteKey = "ForceDeleteAllSections_v2" // v2 to run again after previous failures
        if UserDefaults.standard.bool(forKey: deleteKey) {
            return // Already ran
        }
        
        print("💥 FORCE DELETE: Removing all sections to clear corruption...")
        
        // Clear all old migration keys to ensure clean slate
        let oldKeys = [
            "TaskSectionReminderIDMigration_v1",
            "TaskSectionReminderIDMigration_v2",
            "ClearOrphanedSectionAssignments_v1",
            "TaskSectionReconstruction_v1",
            "ForceDeleteAllSections_v1"
        ]
        for key in oldKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        print("🧹 Cleared old migration flags")
        
        // Use a descriptor to fetch sections without accessing properties
        let descriptor = FetchDescriptor<TaskSection>()
        
        do {
            let sectionsToDelete = try modelContext.fetch(descriptor)
            print("📊 Found \(sectionsToDelete.count) sections to delete")
            
            // Delete each section without trying to read its properties
            for section in sectionsToDelete {
                modelContext.delete(section)
            }
            
            try modelContext.save()
            print("✅ Force deleted \(sectionsToDelete.count) sections")
            
            UserDefaults.standard.set(true, forKey: deleteKey)
        } catch {
            print("❌ Force delete failed: \(error)")
            // Even if this fails, mark it as done to prevent infinite loops
            UserDefaults.standard.set(true, forKey: deleteKey)
        }
    }
    
    /// Reconstructs sections that were deleted but are still referenced by tasks
    ///
    /// This helps recover from situations where sections were deleted but task
    /// assignments were preserved.
    private func reconstructMissingSections() {
        let reconstructionKey = "TaskSectionReconstruction_v3" // v3 with lowered threshold and better patterns
        if UserDefaults.standard.bool(forKey: reconstructionKey) {
            return // Already ran
        }
        
        // Clear old reconstruction flags to run with new logic
        UserDefaults.standard.removeObject(forKey: "TaskSectionReconstruction_v1")
        UserDefaults.standard.removeObject(forKey: "TaskSectionReconstruction_v2")
        
        print("🔄 Checking for missing sections referenced by tasks...")
        
        // Get all section IDs currently referenced by tasks
        let referencedSectionIDs = Set(tasks.compactMap { $0.sectionID }.filter { !$0.isEmpty })
        
        // Get existing section IDs
        let existingSectionIDs = Set(sections.map { $0.id })
        
        // Find missing sections
        let missingSectionIDs = referencedSectionIDs.subtracting(existingSectionIDs)
        
        if missingSectionIDs.isEmpty {
            print("✅ No missing sections found")
            UserDefaults.standard.set(true, forKey: reconstructionKey)
            return
        }
        
        print("⚠️ Found \(missingSectionIDs.count) missing sections!")
        print("🔧 Reconstructing sections from task data...")
        
        // Reconstruct each missing section
        var reconstructedCount = 0
        for (index, sectionID) in missingSectionIDs.sorted().enumerated() {
            // Get tasks in this section to help infer the name
            let tasksInSection = tasks.filter { $0.sectionID == sectionID }
            
            // Try to infer section name from common task patterns
            let sectionName = inferSectionName(from: tasksInSection, fallbackIndex: index + 1)
            
            let newSection = TaskSection(
                title: sectionName,
                sortOrder: sections.count + index
            )
            newSection.id = sectionID // Preserve the original ID!
            
            modelContext.insert(newSection)
            reconstructedCount += 1
            
            print("  ✨ Reconstructed: '\(sectionName)' with \(tasksInSection.count) tasks (ID: \(sectionID))")
        }
        
        do {
            try modelContext.save()
            print("✅ Successfully reconstructed \(reconstructedCount) sections")
            print("💡 You can rename these sections using 'Manage Sections' if needed")
            
            UserDefaults.standard.set(true, forKey: reconstructionKey)
        } catch {
            print("❌ Failed to save reconstructed sections: \(error)")
        }
    }
    
    /// Attempts to infer a section name from the tasks it contains
    private func inferSectionName(from tasks: [DiligenceTask], fallbackIndex: Int) -> String {
        guard !tasks.isEmpty else {
            return "Section \(fallbackIndex)"
        }
        
        // Collect all task titles and descriptions for analysis
        let titles = tasks.map { $0.title.lowercased() }
        let descriptions = tasks.map { $0.taskDescription.lowercased() }.filter { !$0.isEmpty }
        
        // Count pattern matches across all tasks
        var patternScores: [String: Int] = [:]
        
        // Define patterns with their associated section names
        // Order matters - more specific patterns first
        let patterns: [(keywords: [String], sectionName: String)] = [
            (["accounts receivable", "a/r receivable", " ar ", "receivable", "customer payment", "invoice payment"], "AR"),
            (["accounts payable", "a/p payable", " ap ", "payable", "vendor payment", "bill payment"], "AP"),
            (["tech support", "technical", "technology", "software", "hardware", "computer", "it support", "bug", "code"], "Tech"),
            (["admin", "administrative", "office"], "Admin"),
            (["marketing", "campaign", "social media"], "Marketing"),
            (["sales", "prospect", "lead"], "Sales"),
            (["hr", "human resources", "employee", "hiring"], "HR"),
            (["personal"], "Personal"),
            (["project"], "Projects")
        ]
        
        // Count how many tasks match each pattern
        for pattern in patterns {
            var matchCount = 0
            
            for title in titles {
                for keyword in pattern.keywords {
                    if title.contains(keyword) {
                        matchCount += 1
                        break // Count each task only once per pattern
                    }
                }
            }
            
            // Also check descriptions (if they exist)
            for desc in descriptions where !desc.isEmpty {
                for keyword in pattern.keywords {
                    if desc.contains(keyword) {
                        matchCount += 1
                        break
                    }
                }
            }
            
            if matchCount > 0 {
                patternScores[pattern.sectionName] = matchCount
            }
        }
        
        // Print sample task titles to help identify the section
        print("    📝 Sample tasks in section \(fallbackIndex):")
        for (i, task) in tasks.prefix(5).enumerated() {
            print("       \(i+1). \(task.title)")
        }
        if tasks.count > 5 {
            print("       ... and \(tasks.count - 5) more")
        }
        
        // Find the pattern with the highest score
        if let bestMatch = patternScores.max(by: { $0.value < $1.value }),
           bestMatch.value > 0 {
            let percentage = (Double(bestMatch.value) / Double(tasks.count)) * 100
            print("    📊 Pattern analysis: '\(bestMatch.key)' matched \(bestMatch.value)/\(tasks.count) tasks (\(String(format: "%.1f", percentage))%)")
            
            // Lower threshold to 10% or at least 2 tasks
            if percentage >= 10 || bestMatch.value >= 2 {
                return bestMatch.key
            }
        }
        
        // If no pattern matched well, check if the section is purely email-based
        let emailTasks = tasks.filter { $0.isFromEmail }
        if emailTasks.count == tasks.count && tasks.count < 20 {
            return "Emails (\(tasks.count) tasks)"
        }
        
        // Fallback to generic name
        return "Section \(fallbackIndex) (\(tasks.count) tasks)"
    }
    /*
    /// DEPRECATED: Old migration that tried to read corrupted sections
    /// One-time migration to fix corrupted section data
    ///
    /// This recreates all existing sections with properly initialized reminderID fields,
    /// preserving section IDs so task assignments remain intact.
    private func migrateCorruptedSections_OLD() {
        // Check if we've already run this migration
        let migrationKey = "TaskSectionReminderIDMigration_v2"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            print("✅ Section migration already completed")
            return
        }
        
        print("🔄 Running section data migration...")
        
        // Check if the v1 migration already ran (which would have deleted sections)
        let v1MigrationKey = "TaskSectionReminderIDMigration_v1"
        let v1AlreadyRan = UserDefaults.standard.bool(forKey: v1MigrationKey)
        
        if v1AlreadyRan {
            print("⚠️ Previous migration (v1) already deleted sections and cleared assignments")
            print("⚠️ Cannot automatically restore section assignments")
            print("💡 You will need to recreate sections and manually reassign tasks")
            
            // Mark v2 as complete so we don't run this again
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }
        
        print("💡 Recreating sections with fixed data structure while preserving task assignments")
        
        // Collect section data before deletion
        var sectionData: [(id: String, title: String, sortOrder: Int)] = []
        
        for section in sections {
            // Try to safely extract the data we need
            do {
                let id = section.id
                let title = section.title
                let sortOrder = section.sortOrder
                
                sectionData.append((id: id, title: title, sortOrder: sortOrder))
                print("  📋 Captured section: '\(title)' (ID: \(id))")
            } catch {
                print("  ⚠️ Could not read section data, will skip")
            }
        }
        
        if sectionData.isEmpty {
            print("⚠️ No sections found to migrate")
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }
        
        // Delete all corrupted sections
        print("🗑️ Deleting corrupted sections...")
        for section in sections {
            modelContext.delete(section)
        }
        
        // Recreate sections with proper initialization
        print("✨ Recreating sections with fixed data structure...")
        for data in sectionData {
            let newSection = TaskSection(
                title: data.title,
                sortOrder: data.sortOrder
            )
            // CRITICAL: Preserve the original ID so task assignments still work
            newSection.id = data.id
            modelContext.insert(newSection)
            print("  ✓ Recreated section: '\(data.title)' with ID: \(data.id)")
        }
        
        do {
            try modelContext.save()
            
            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationKey)
            
            print("✅ Migration completed successfully")
            print("✅ Recreated \(sectionData.count) sections with original IDs")
            print("✅ All task assignments preserved!")
        } catch {
            print("❌ Failed to complete migration: \(error)")
        }
    }
    */
    
    private func handleTasksChange() {
        // Sync with Reminders whenever tasks change
        // Skip if already syncing to prevent feedback loop
        if remindersService.isAuthorized && !isSyncing {
            syncWithReminders()
        }
    }
    
    private func handleSectionsChange() {
        // Sync with Reminders whenever sections change
        // Skip if already syncing to prevent feedback loop
        if remindersService.isAuthorized && !isSyncing {
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
        
        // Set syncing flag to prevent recursive updates
        isSyncing = true
        defer { isSyncing = false }
        
        task.reminderID = reminderID
        task.lastSyncedToReminders = Date()
        
        // Save the context to persist changes
        do {
            try modelContext.save()
            print("✅ Successfully saved reminder ID update for task: \(task.title)")
            
            // Force UI refresh to show updated task organization
            // Use a delay to ensure the save completes before refreshing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.refreshTrigger.toggle()
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
        
        // Set syncing flag to prevent recursive updates
        isSyncing = true
        defer { isSyncing = false }
        
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
        
        // Trigger sync after completion toggle (but not if we're already syncing)
        if remindersService.isAuthorized && !isSyncing {
            syncWithReminders()
        }
    }
    
    
    private func syncWithReminders() {
        guard !tasks.isEmpty || !sections.isEmpty else {
            print("📝 Skipping Reminders sync - no tasks or sections to sync")
            return
        }
        
        // Prevent recursive sync calls
        guard !isSyncing else {
            print("📝 Skipping Reminders sync - already in progress")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
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
    
    private func exportTasks() {
        print("📊 === EXPORTING TASKS ===")
        print("📊 Total tasks available: \(filteredTasks.count)")
        
        // Count incomplete tasks with sections (what will actually be exported)
        let tasksToExport = filteredTasks.filter { $0.sectionID != nil && !$0.isCompleted }
        print("📊 Incomplete tasks with sections: \(tasksToExport.count)")
        
        // Show section breakdown
        for section in sections {
            let sectionTasks = tasksToExport.filter { $0.sectionID == section.id }
            if !sectionTasks.isEmpty {
                print("📊   - \(section.title): \(sectionTasks.count) tasks")
            }
        }
        
        guard !filteredTasks.isEmpty else {
            showExportError(message: "No tasks to export")
            return
        }
        
        do {
            // Extract section data safely from SwiftData models
            // Map TaskSection objects to ExportSection structs (no cast needed)
            let exportSections: [ExportSection] = sections.map { section in
                ExportSection(id: section.id, title: section.title, sortOrder: section.sortOrder)
            }
            
            print("📊 Mapped \(exportSections.count) sections for export:")
            for section in exportSections {
                print("   - \(section.title) (ID: \(section.id), Sort: \(section.sortOrder))")
            }
            
            print("📊 Exporting to multi-tab Excel workbook...")
            
            // Generate multi-tab Excel export (will filter to only incomplete sectioned tasks)
            let (data, filename) = try TaskExportService.exportToExcel(
                tasks: filteredTasks,
                sections: exportSections
            )
            
            print("✅ Successfully generated Excel export: \(filename) (\(data.count) bytes)")
            print("📊 Workbook structure:")
            print("   - Summary tab: Tasks due by next Saturday")
            for section in exportSections {
                let sectionTasks = tasksToExport.filter { $0.sectionID == section.id }
                if !sectionTasks.isEmpty {
                    print("   - \(section.title) tab: \(sectionTasks.count) tasks")
                }
            }
            
            // Open directly in Excel (no success popup)
            TaskExportService.openInExcel(data: data, filename: filename, taskCount: tasksToExport.count)
        } catch {
            print("❌ Export failed: \(error)")
            showExportError(message: error.localizedDescription)
        }
    }
    
    private func showExportError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Export Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
        
        // If this is a recurring task (parent), also move all its recurring instances
        if task.isRecurring {
            let parentID = task.title + "_" + task.createdDate.timeIntervalSince1970.description
            
            // Find all recurring instances of this task
            let descriptor = FetchDescriptor<DiligenceTask>(
                predicate: #Predicate { $0.parentRecurringTaskID == parentID }
            )
            
            do {
                let recurringInstances = try modelContext.fetch(descriptor)
                let instanceCount = recurringInstances.count
                
                // Update section for all recurring instances
                for instance in recurringInstances {
                    instance.sectionID = sectionID
                }
                
                print("📅 Also updated \(instanceCount) recurring instance(s) to new section")
            } catch {
                print("⚠️ Failed to fetch recurring instances: \(error)")
            }
        }
        
        // If this is a recurring instance, also move the parent task
        if task.isRecurringInstance, let parentID = task.parentRecurringTaskID {
            // First find the parent task by matching parentRecurringTaskID
            let parentDescriptor = FetchDescriptor<DiligenceTask>(
                predicate: #Predicate { task in
                    task.isRecurring
                }
            )
            
            do {
                let allRecurringTasks = try modelContext.fetch(parentDescriptor)
                
                // Manually find the parent by generating its ID
                let parentTask = allRecurringTasks.first { recurringTask in
                    let generatedParentID = recurringTask.title + "_" + recurringTask.createdDate.timeIntervalSince1970.description
                    return generatedParentID == parentID
                }
                
                if let parentTask = parentTask {
                    parentTask.sectionID = sectionID
                    print("📅 Also updated parent recurring task to new section")
                    
                    // Update all sibling instances as well
                    let siblingsDescriptor = FetchDescriptor<DiligenceTask>(
                        predicate: #Predicate { $0.parentRecurringTaskID == parentID }
                    )
                    
                    let siblings = try modelContext.fetch(siblingsDescriptor)
                    for sibling in siblings where sibling.title != task.title {
                        sibling.sectionID = sectionID
                    }
                    
                    print("📅 Also updated \(siblings.count) sibling recurring instance(s) to new section")
                }
            } catch {
                print("⚠️ Failed to fetch parent recurring task: \(error)")
            }
        }
        
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
    
    // Recurrence editing properties
    @State private var editedRecurrencePattern: RecurrencePattern = .never
    @State private var editedRecurrenceInterval: Int = 1
    @State private var editedRecurrenceWeekdays: [Int] = []
    @State private var editedRecurrenceEndType: RecurrenceEndType = .never
    @State private var editedRecurrenceEndDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var editedRecurrenceEndCount: Int = 10
    
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
                                .tag(String?.none)
                            
                            ForEach(sections, id: \.id) { section in
                                HStack {
                                    Text(section.title)
                                }
                                .tag(Optional(section.id))
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
                
                // Recurrence section - only show if task has a due date or is being edited with a due date
                if (editedHasDueDate && isEditing) || (!isEditing && task.dueDate != nil) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recurrence")
                            .font(.headline)
                        
                        if isEditing {
                            // Show recurrence editor when editing
                            RecurrenceQuickSetupView(
                                recurrencePattern: $editedRecurrencePattern,
                                recurrenceInterval: $editedRecurrenceInterval,
                                recurrenceWeekdays: $editedRecurrenceWeekdays,
                                recurrenceEndType: $editedRecurrenceEndType,
                                recurrenceEndDate: $editedRecurrenceEndDate,
                                recurrenceEndCount: $editedRecurrenceEndCount
                            )
                        } else {
                            // Display current recurrence info when not editing
                            if task.isRecurring {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "repeat")
                                            .foregroundColor(.blue)
                                        
                                        Text(task.recurrenceDescription)
                                            .font(.subheadline)
                                            .textSelection(.enabled)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                                    
                                    if let nextDue = task.nextDueDate {
                                        HStack(spacing: 6) {
                                            Image(systemName: "calendar.badge.clock")
                                                .foregroundColor(.orange)
                                                .font(.caption)
                                            
                                            Text("Next occurrence: \(Self.dueDateWithTimeFormatter.string(from: nextDue))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            } else if task.isRecurringInstance {
                                HStack(spacing: 6) {
                                    Image(systemName: "repeat.1")
                                        .foregroundColor(.purple)
                                    
                                    Text("This is a recurring instance")
                                        .font(.subheadline)
                                        .foregroundColor(.purple)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(6)
                            } else {
                                Text("Does not repeat")
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                    }
                    
                    Divider()
                }
                
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
            .padding(20) // Standard macOS content padding
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        
        // Initialize recurrence fields
        editedRecurrencePattern = task.recurrencePattern
        editedRecurrenceInterval = task.recurrenceInterval
        editedRecurrenceWeekdays = task.recurrenceWeekdays
        editedRecurrenceEndType = task.recurrenceEndType
        editedRecurrenceEndDate = task.recurrenceEndDate ?? Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
        editedRecurrenceEndCount = task.recurrenceEndCount ?? 10
        
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
        
        // Save recurrence settings (only if task has a due date)
        let wasRecurring = task.isRecurring
        let oldRecurrencePattern = task.recurrencePattern
        
        if editedHasDueDate {
            task.recurrencePattern = editedRecurrencePattern
            task.recurrenceInterval = editedRecurrenceInterval
            task.recurrenceEndType = editedRecurrenceEndType
            task.recurrenceEndDate = editedRecurrenceEndDate
            task.recurrenceEndCount = editedRecurrenceEndCount
            
            // Set custom weekdays if applicable
            if editedRecurrencePattern == .weekly || editedRecurrencePattern == .custom {
                task.recurrenceWeekdays = editedRecurrenceWeekdays
            } else if editedRecurrencePattern == .weekdays {
                task.recurrenceWeekdays = [2, 3, 4, 5, 6] // Monday through Friday
            } else {
                task.recurrenceWeekdays = []
            }
        } else {
            // If no due date, remove recurrence
            task.recurrencePattern = .never
            task.recurrenceWeekdays = []
        }
        
        // Handle recurrence changes
        let isNowRecurring = task.isRecurring
        let recurrenceChanged = (wasRecurring != isNowRecurring) || (oldRecurrencePattern != task.recurrencePattern)
        
        if recurrenceChanged {
            handleRecurrenceChange(wasRecurring: wasRecurring, isNowRecurring: isNowRecurring)
        }
        
        isEditing = false
        
        // Trigger sync with Reminders after saving changes
        NotificationCenter.default.post(
            name: Notification.Name("TriggerRemindersSync"), 
            object: nil
        )
    }
    
    /// Handles changes to recurrence settings
    private func handleRecurrenceChange(wasRecurring: Bool, isNowRecurring: Bool) {
        if wasRecurring && !isNowRecurring {
            // Task is no longer recurring - delete all existing recurring instances
            deleteRecurringInstances()
        } else if isNowRecurring {
            // Task is now recurring (either newly recurring or pattern changed)
            // Delete old instances and generate new ones
            if wasRecurring {
                deleteRecurringInstances()
            }
            generateRecurringInstances()
        }
    }
    
    /// Deletes all recurring instances of this task
    private func deleteRecurringInstances() {
        let parentID = task.title + "_" + task.createdDate.timeIntervalSince1970.description
        
        let descriptor = FetchDescriptor<DiligenceTask>(
            predicate: #Predicate { $0.parentRecurringTaskID == parentID }
        )
        
        do {
            let instances = try modelContext.fetch(descriptor)
            for instance in instances {
                modelContext.delete(instance)
            }
            print("🗑️ Deleted \(instances.count) recurring instance(s)")
        } catch {
            print("❌ Failed to delete recurring instances: \(error)")
        }
    }
    
    /// Generates new recurring instances for this task
    private func generateRecurringInstances() {
        _Concurrency.Task {
            let endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
            let instances = task.generateRecurringInstances(until: endDate, in: modelContext)
            
            do {
                try modelContext.save()
                print("✅ Generated \(instances.count) recurring instance(s)")
            } catch {
                print("❌ Failed to save recurring instances: \(error)")
            }
        }
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
                                    .tag(String?.none)
                                
                                ForEach(sections, id: \.id) { section in
                                    HStack {
                                        Text(section.title)
                                    }
                                    .tag(Optional(section.id))
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
                            .tag(String?.none)
                        
                        ForEach(sections, id: \.id) { section in
                            HStack {
                                Text(section.title)
                            }
                            .tag(Optional(section.id))
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
            .padding(20) // Standard macOS content padding
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    @FocusState private var isTextFieldFocused: Bool
    
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
                    .focused($isTextFieldFocused)
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
        // Focus the text field when entering edit mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTextFieldFocused = true
        }
    }
    
    private func cancelEdit() {
        editTitle = section.title
        isEditing = false
        isTextFieldFocused = false
    }
    
    private func saveChanges() {
        let trimmedTitle = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        section.title = trimmedTitle
        
        do {
            try modelContext.save()
            isEditing = false
            isTextFieldFocused = false
        } catch {
            print("Failed to save section changes: \(error)")
        }
    }
}

#Preview {
    TaskListView()
        .modelContainer(for: [DiligenceTask.self, TaskSection.self], inMemory: true)
}

