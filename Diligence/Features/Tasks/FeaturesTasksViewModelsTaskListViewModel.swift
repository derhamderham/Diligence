//
//  TaskListViewModel.swift
//  Diligence
//
//  ViewModel for TaskListView - MVVM pattern
//

import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Task List ViewModel

/// View model managing the task list state and business logic
///
/// This view model handles:
/// - Task CRUD operations
/// - Task filtering and sorting
/// - Section management
/// - Reminders synchronization
/// - Recurring task maintenance
///
/// ## Topics
///
/// ### State Management
/// - ``tasks``
/// - ``sections``
/// - ``selectedTask``
/// - ``isLoading``
///
/// ### Operations
/// - ``createTask(_:)``
/// - ``updateTask(_:)``
/// - ``deleteTask(_:)``
/// - ``toggleTaskCompletion(_:)``
@MainActor
final class TaskListViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    private let taskService: TaskServiceProtocol
    private let remindersService: RemindersSyncServiceProtocol
    private let recurringTaskService: RecurringTaskServiceProtocol
    
    // MARK: - Published State
    
    /// All tasks from the database
    @Published var tasks: [DiligenceTask] = []
    
    /// All task sections
    @Published var sections: [TaskSection] = []
    
    /// Currently selected task
    @Published var selectedTask: DiligenceTask?
    
    /// Loading state
    @Published var isLoading: Bool = false
    
    /// Error state
    @Published var error: Error?
    
    /// Show section manager sheet
    @Published var showingSectionManager: Bool = false
    
    /// Show create task sheet
    @Published var showingCreateTask: Bool = false
    
    /// Reminders sync status
    @Published var syncStatus: SyncStatus = .idle
    
    /// Reminders authorization status
    @Published var isRemindersAuthorized: Bool = false
    
    // MARK: - Computed Properties
    
    /// Incomplete tasks
    var incompleteTasks: [DiligenceTask] {
        tasks.filter { !$0.isCompleted }
    }
    
    /// Completed tasks
    var completedTasks: [DiligenceTask] {
        tasks.filter { $0.isCompleted }
    }
    
    /// Tasks not assigned to any section
    var unsectionedTasks: [DiligenceTask] {
        tasks.filter { task in
            task.sectionID == nil || task.sectionID?.isEmpty == true
        }
    }
    
    /// Incomplete unsectioned tasks
    var incompleteUnsectionedTasks: [DiligenceTask] {
        unsectionedTasks.filter { !$0.isCompleted }
    }
    
    /// Completed unsectioned tasks
    var completedUnsectionedTasks: [DiligenceTask] {
        unsectionedTasks.filter { $0.isCompleted }
    }
    
    /// Sync status text for display
    var syncStatusText: String {
        switch syncStatus {
        case .idle:
            return isRemindersAuthorized ? "Ready to sync" : "Not authorized"
        case .syncing:
            return "Syncing with Reminders..."
        case .success(let count):
            return "Synced \(count) task\(count == 1 ? "" : "s")"
        case .failure(let message):
            return "Sync failed: \(message)"
        }
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    // MARK: - Initialization
    
    /// Initializes the view model with dependencies
    ///
    /// - Parameters:
    ///   - modelContext: SwiftData model context
    ///   - taskService: Task service for CRUD operations
    ///   - remindersService: Service for Reminders sync
    ///   - recurringTaskService: Service for recurring task maintenance
    init(
        modelContext: ModelContext,
        taskService: TaskServiceProtocol? = nil,
        remindersService: RemindersSyncServiceProtocol? = nil,
        recurringTaskService: RecurringTaskServiceProtocol? = nil
    ) {
        self.modelContext = modelContext
        self.taskService = taskService ?? ServiceContainer.shared.taskService
        self.remindersService = remindersService ?? ServiceContainer.shared.remindersService
        self.recurringTaskService = recurringTaskService ?? ServiceContainer.shared.recurringService
        
        // Check reminders authorization on init
        self.isRemindersAuthorized = self.remindersService.isAuthorized
    }
    
    // MARK: - Lifecycle Methods
    
    /// Called when the view appears
    func onAppear() {
        fetchTasks()
        fetchSections()
        startRecurringTaskMaintenance()
        setupNotificationObservers()
    }
    
    /// Called when the view disappears
    func onDisappear() {
        cancellables.removeAll()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Data Fetching
    
    /// Fetches all tasks from the database
    func fetchTasks() {
        do {
            tasks = try taskService.fetchTasks(matching: nil, in: modelContext)
            print("📋 Fetched \(tasks.count) tasks")
        } catch {
            print("❌ Failed to fetch tasks: \(error)")
            self.error = error
        }
    }
    
    /// Fetches all sections from the database
    func fetchSections() {
        let descriptor = FetchDescriptor<TaskSection>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        
        do {
            sections = try modelContext.fetch(descriptor)
            print("📂 Fetched \(sections.count) sections")
        } catch {
            print("❌ Failed to fetch sections: \(error)")
            self.error = error
        }
    }
    
    /// Returns tasks for a specific section
    ///
    /// - Parameter section: The section to get tasks for
    /// - Returns: Array of tasks in the section
    func tasks(for section: TaskSection) -> [DiligenceTask] {
        return tasks.filter { $0.sectionID == section.id }
    }
    
    /// Returns incomplete tasks for a specific section
    ///
    /// - Parameter section: The section to get tasks for
    /// - Returns: Array of incomplete tasks in the section
    func incompleteTasks(for section: TaskSection) -> [DiligenceTask] {
        return tasks(for: section).filter { !$0.isCompleted }
    }
    
    /// Returns completed tasks for a specific section
    ///
    /// - Parameter section: The section to get tasks for
    /// - Returns: Array of completed tasks in the section
    func completedTasks(for section: TaskSection) -> [DiligenceTask] {
        return tasks(for: section).filter { $0.isCompleted }
    }
    
    // MARK: - Task Operations
    
    /// Creates a new task
    ///
    /// - Parameter task: The task to create
    func createTask(_ task: DiligenceTask) {
        isLoading = true
        
        do {
            try taskService.createTask(task, in: modelContext)
            fetchTasks() // Refresh list
            
            // Generate recurring instances if needed
            if task.isRecurring {
                generateRecurringInstances(for: task)
            }
            
            // Trigger sync with Reminders
            _Concurrency.Task {
                await syncWithReminders()
            }
            
            isLoading = false
        } catch {
            print("❌ Failed to create task: \(error)")
            self.error = error
            isLoading = false
        }
    }
    
    /// Updates an existing task
    ///
    /// - Parameter task: The task to update
    func updateTask(_ task: DiligenceTask) {
        do {
            try taskService.updateTask(task, in: modelContext)
            fetchTasks() // Refresh list
            
            // Trigger sync with Reminders
            _Concurrency.Task {
                await syncTask(task)
            }
        } catch {
            print("❌ Failed to update task: \(error)")
            self.error = error
        }
    }
    
    /// Deletes a task
    ///
    /// - Parameter task: The task to delete
    func deleteTask(_ task: DiligenceTask) {
        do {
            try taskService.deleteTask(task, in: modelContext)
            fetchTasks() // Refresh list
            
            // Clear selection if needed
            if selectedTask?.id == task.id {
                selectedTask = nil
            }
            
            // Delete from Reminders if synced
            if task.reminderID != nil {
                _Concurrency.Task {
                    try? await remindersService.deleteReminder(for: task)
                }
            }
        } catch {
            print("❌ Failed to delete task: \(error)")
            self.error = error
        }
    }
    
    /// Deletes multiple tasks
    ///
    /// - Parameter tasks: The tasks to delete
    func deleteTasks(_ tasks: [DiligenceTask]) {
        do {
            try taskService.bulkDelete(tasks, in: modelContext)
            fetchTasks() // Refresh list
        } catch {
            print("❌ Failed to delete tasks: \(error)")
            self.error = error
        }
    }
    
    /// Toggles the completion status of a task
    ///
    /// - Parameter task: The task to toggle
    func toggleTaskCompletion(_ task: DiligenceTask) {
        do {
            try taskService.toggleCompletion(for: task, in: modelContext)
            fetchTasks() // Refresh list
            
            // Sync with Reminders
            _Concurrency.Task {
                await syncTask(task)
            }
        } catch {
            print("❌ Failed to toggle task completion: \(error)")
            self.error = error
        }
    }
    
    /// Duplicates a task
    ///
    /// - Parameter task: The task to duplicate
    /// - Returns: The duplicated task
    func duplicateTask(_ task: DiligenceTask) -> DiligenceTask? {
        do {
            let duplicated = try taskService.duplicateTask(task, in: modelContext)
            fetchTasks() // Refresh list
            
            // Trigger sync with Reminders
            _Concurrency.Task {
                await syncWithReminders()
            }
            
            return duplicated
        } catch {
            print("❌ Failed to duplicate task: \(error)")
            self.error = error
            return nil
        }
    }
    
    /// Marks multiple tasks as complete
    ///
    /// - Parameter tasks: The tasks to complete
    func bulkComplete(_ tasks: [DiligenceTask]) {
        do {
            try taskService.bulkComplete(tasks, in: modelContext)
            fetchTasks() // Refresh list
            
            // Sync with Reminders
            _Concurrency.Task {
                await syncWithReminders()
            }
        } catch {
            print("❌ Failed to bulk complete tasks: \(error)")
            self.error = error
        }
    }
    
    // MARK: - Section Operations
    
    /// Creates a new section
    ///
    /// - Parameter title: The section title
    func createSection(title: String) {
        let section = TaskSection(title: title, sortOrder: sections.count)
        modelContext.insert(section)
        
        do {
            try modelContext.save()
            fetchSections() // Refresh list
        } catch {
            print("❌ Failed to create section: \(error)")
            self.error = error
        }
    }
    
    /// Deletes a section
    ///
    /// - Parameter section: The section to delete
    func deleteSection(_ section: TaskSection) {
        modelContext.delete(section)
        
        do {
            try modelContext.save()
            fetchSections() // Refresh list
        } catch {
            print("❌ Failed to delete section: \(error)")
            self.error = error
        }
    }
    
    /// Reorders sections
    ///
    /// - Parameters:
    ///   - source: Source indices
    ///   - destination: Destination index
    func moveSections(from source: IndexSet, to destination: Int) {
        var updatedSections = sections
        updatedSections.move(fromOffsets: source, toOffset: destination)
        
        // Update sort orders
        for (index, section) in updatedSections.enumerated() {
            section.sortOrder = index
        }
        
        do {
            try modelContext.save()
            fetchSections() // Refresh list
        } catch {
            print("❌ Failed to reorder sections: \(error)")
            self.error = error
        }
    }
    
    // MARK: - Reminders Sync
    
    /// Requests authorization for Reminders access
    func requestRemindersAuthorization() {
        _Concurrency.Task {
            let authorized = await remindersService.requestAuthorization()
            await MainActor.run {
                isRemindersAuthorized = authorized
                
                if authorized {
                    // Automatically sync after authorization
                    _Concurrency.Task {
                        await syncWithReminders()
                    }
                }
            }
        }
    }
    
    /// Syncs all tasks with Apple Reminders
    func syncWithReminders() async {
        guard isRemindersAuthorized else {
            print("⚠️ Reminders not authorized")
            return
        }
        
        await MainActor.run {
            syncStatus = .syncing
        }
        
        do {
            try await remindersService.syncAllTasks(in: modelContext)
            
            await MainActor.run {
                syncStatus = .success(taskCount: tasks.count)
                fetchTasks() // Refresh to get updated reminderIDs
            }
        } catch {
            print("❌ Failed to sync with Reminders: \(error)")
            await MainActor.run {
                syncStatus = .failure(message: error.localizedDescription)
                self.error = error
            }
        }
    }
    
    /// Syncs a single task with Reminders
    ///
    /// - Parameter task: The task to sync
    private func syncTask(_ task: DiligenceTask) async {
        guard isRemindersAuthorized else { return }
        
        do {
            try await remindersService.syncTask(task, in: modelContext)
        } catch {
            print("❌ Failed to sync task with Reminders: \(error)")
        }
    }
    
    // MARK: - Recurring Tasks
    
    /// Starts automatic recurring task maintenance
    private func startRecurringTaskMaintenance() {
        _Concurrency.Task {
            await recurringTaskService.startRecurringTaskMaintenance()
        }
    }
    
    /// Generates recurring instances for a task
    ///
    /// - Parameter task: The recurring task
    private func generateRecurringInstances(for task: DiligenceTask) {
        guard task.isRecurring else { return }
        
        let endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        
        do {
            let instances = try recurringTaskService.generateInstances(for: task, until: endDate)
            print("✅ Generated \(instances.count) recurring instances")
            fetchTasks() // Refresh to show new instances
        } catch {
            print("❌ Failed to generate recurring instances: \(error)")
            self.error = error
        }
    }
    
    // MARK: - Notification Observers
    
    /// Sets up notification observers for external events
    private func setupNotificationObservers() {
        // Listen for manual sync triggers
        NotificationCenter.default.publisher(for: Notification.Name("TriggerRemindersSync"))
            .sink { [weak self] _ in
                guard let self = self else { return }
                _Concurrency.Task {
                    await self.syncWithReminders()
                }
            }
            .store(in: &cancellables)
        
        // Listen for recurring task updates
        NotificationCenter.default.publisher(for: Notification.Name("RecurringTasksUpdated"))
            .sink { [weak self] _ in
                self?.fetchTasks()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Error Handling
    
    /// Clears the current error
    func clearError() {
        error = nil
    }
    
    /// Shows an error message
    ///
    /// - Parameter error: The error to display
    func showError(_ error: Error) {
        self.error = error
    }
}

// MARK: - View Model Factory

extension TaskListViewModel {
    /// Creates a view model for testing or preview
    ///
    /// - Parameter context: Model context to use
    /// - Returns: Configured view model
    static func preview(context: ModelContext) -> TaskListViewModel {
        return TaskListViewModel(modelContext: context)
    }
}
