//
//  GmailViewModel.swift
//  Diligence
//
//  ViewModel for GmailView - MVVM pattern
//

import Foundation
import SwiftUI
import Combine
import SwiftData

// MARK: - Gmail View Model

/// View model managing Gmail email state and operations
///
/// This view model handles:
/// - Gmail authentication and authorization
/// - Email fetching and pagination
/// - Email selection and display
/// - Task creation from emails
/// - AI-powered email analysis
/// - Error handling and loading states
///
/// ## Topics
///
/// ### Authentication
/// - ``isAuthenticated``
/// - ``userEmail``
/// - ``signIn()``
/// - ``signOut()``
///
/// ### Email Operations
/// - ``fetchEmails()``
/// - ``loadMoreEmails()``
/// - ``refreshEmails()``
/// - ``selectEmail(_:)``
///
/// ### Task Creation
/// - ``createTaskFromEmail(_:)``
/// - ``generateAITasks()``
@MainActor
final class GmailViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let emailService: EmailServiceProtocol
    private let aiService: AIServiceProtocol
    private let taskService: TaskServiceProtocol
    private let modelContext: ModelContext
    
    // MARK: - Published State
    
    /// Authentication state
    @Published var isAuthenticated: Bool = false
    @Published var userEmail: String?
    
    /// Email data
    @Published var emails: [ProcessedEmail] = []
    @Published var selectedEmail: ProcessedEmail?
    @Published var selectedEmailIndex: Int = 0
    
    /// UI state
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var error: Error?
    
    /// AI state
    @Published var isGeneratingTasks: Bool = false
    @Published var aiGeneratedTasks: [GeneratedTask] = []
    @Published var showingAITasksSheet: Bool = false
    
    /// Email content state
    @Published var emailContent: String = ""
    @Published var isLoadingContent: Bool = false
    
    /// Pagination
    @Published var hasMoreEmails: Bool = true
    private var nextPageToken: String?
    
    /// Search and filter
    @Published var searchQuery: String = ""
    @Published var selectedFilter: EmailFilter = .all
    
    // MARK: - Computed Properties
    
    /// Filtered emails based on search and filter
    var filteredEmails: [ProcessedEmail] {
        var result = emails
        
        // Apply search filter
        if !searchQuery.isEmpty {
            result = result.filter { email in
                email.subject.localizedCaseInsensitiveContains(searchQuery) ||
                email.sender.localizedCaseInsensitiveContains(searchQuery) ||
                email.body.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        // Apply category filter
        switch selectedFilter {
        case .all:
            break
        case .today:
            result = result.filter { $0.receivedDate.isToday }
        case .thisWeek:
            result = result.filter { $0.receivedDate.isThisWeek }
        case .hasAttachments:
            result = result.filter { $0.hasAttachments }
        case .unread:
            // Would need unread status in model
            break
        }
        
        return result
    }
    
    /// Status text for display
    var statusText: String {
        if isLoading {
            return "Loading emails..."
        } else if isRefreshing {
            return "Refreshing..."
        } else if isAuthenticated {
            return "\(emails.count) email\(emails.count == 1 ? "" : "s")"
        } else {
            return "Not signed in"
        }
    }
    
    /// Whether AI features are available
    var isAIAvailable: Bool {
        return aiService.isAvailable
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let maxEmailsPerRequest = 50
    
    // MARK: - Initialization
    
    /// Initializes the view model with dependencies
    ///
    /// - Parameters:
    ///   - emailService: Service for email operations
    ///   - aiService: Service for AI task generation
    ///   - taskService: Service for task creation
    ///   - modelContext: SwiftData model context
    init(
        emailService: EmailServiceProtocol,
        aiService: AIServiceProtocol,
        taskService: TaskServiceProtocol,
        modelContext: ModelContext
    ) {
        self.emailService = emailService
        self.aiService = aiService
        self.taskService = taskService
        self.modelContext = modelContext
        
        // Check authentication status on init
        self.isAuthenticated = emailService.isAuthenticated
        self.userEmail = emailService.userEmail
        
        setupSearchDebouncing()
    }
    
    /// Convenience initializer using the shared service container
    ///
    /// - Parameter modelContext: SwiftData model context
    convenience init(modelContext: ModelContext) {
        self.init(
            emailService: ServiceContainer.shared.emailService,
            aiService: ServiceContainer.shared.aiService,
            taskService: ServiceContainer.shared.taskService,
            modelContext: modelContext
        )
    }
    
    // MARK: - Lifecycle Methods
    
    /// Called when the view appears
    func onAppear() {
        if isAuthenticated && emails.isEmpty {
            _Concurrency.Task {
                await fetchEmails()
            }
        }
    }
    
    /// Called when the view disappears
    func onDisappear() {
        cancellables.removeAll()
    }
    
    // MARK: - Authentication
    
    /// Signs in to Gmail
    func signIn() async {
        isLoading = true
        error = nil
        
        do {
            let email = try await emailService.authenticate()
            
            await MainActor.run {
                isAuthenticated = true
                userEmail = email
                isLoading = false
            }
            
            // Fetch emails after successful sign in
            await fetchEmails()
            
        } catch let emailError as EmailServiceError {
            await MainActor.run {
                error = emailError
                isLoading = false
            }
            print("❌ Gmail authentication failed: \(emailError)")
        } catch {
            await MainActor.run {
                self.error = error
                isLoading = false
            }
            print("❌ Gmail authentication failed: \(error)")
        }
    }
    
    /// Signs out of Gmail
    func signOut() {
        do {
            try emailService.signOut()
            
            // Clear state
            isAuthenticated = false
            userEmail = nil
            emails = []
            selectedEmail = nil
            nextPageToken = nil
            
            print("✅ Signed out successfully")
        } catch {
            self.error = error
            print("❌ Sign out failed: \(error)")
        }
    }
    
    // MARK: - Email Fetching
    
    /// Fetches emails from Gmail
    func fetchEmails() async {
        guard isAuthenticated else {
            print("⚠️ Not authenticated")
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let response = try await emailService.fetchMessages(
                query: searchQuery.isEmpty ? nil : searchQuery,
                maxResults: maxEmailsPerRequest,
                pageToken: nil
            )
            
            // Fetch full message details
            let fetchedEmails = await fetchMessageDetails(for: response.messages ?? [])
            
            await MainActor.run {
                emails = fetchedEmails
                nextPageToken = response.nextPageToken
                hasMoreEmails = nextPageToken != nil
                isLoading = false
                
                print("✅ Fetched \(fetchedEmails.count) emails")
            }
            
        } catch let emailError as EmailServiceError {
            await MainActor.run {
                error = emailError
                isLoading = false
            }
            print("❌ Failed to fetch emails: \(emailError)")
        } catch {
            await MainActor.run {
                self.error = error
                isLoading = false
            }
            print("❌ Failed to fetch emails: \(error)")
        }
    }
    
    /// Loads more emails (pagination)
    func loadMoreEmails() async {
        guard isAuthenticated, hasMoreEmails, !isLoadingMore else {
            return
        }
        
        isLoadingMore = true
        
        do {
            let response = try await emailService.fetchMessages(
                query: searchQuery.isEmpty ? nil : searchQuery,
                maxResults: maxEmailsPerRequest,
                pageToken: nextPageToken
            )
            
            let fetchedEmails = await fetchMessageDetails(for: response.messages ?? [])
            
            await MainActor.run {
                emails.append(contentsOf: fetchedEmails)
                nextPageToken = response.nextPageToken
                hasMoreEmails = nextPageToken != nil
                isLoadingMore = false
                
                print("✅ Loaded \(fetchedEmails.count) more emails (total: \(emails.count))")
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                isLoadingMore = false
            }
            print("❌ Failed to load more emails: \(error)")
        }
    }
    
    /// Refreshes the email list
    func refreshEmails() async {
        guard isAuthenticated else { return }
        
        isRefreshing = true
        nextPageToken = nil
        
        do {
            let response = try await emailService.fetchMessages(
                query: searchQuery.isEmpty ? nil : searchQuery,
                maxResults: maxEmailsPerRequest,
                pageToken: nil
            )
            
            let fetchedEmails = await fetchMessageDetails(for: response.messages ?? [])
            
            await MainActor.run {
                emails = fetchedEmails
                nextPageToken = response.nextPageToken
                hasMoreEmails = nextPageToken != nil
                isRefreshing = false
                
                print("✅ Refreshed emails")
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                isRefreshing = false
            }
            print("❌ Failed to refresh emails: \(error)")
        }
    }
    
    /// Fetches full message details for message references
    ///
    /// - Parameter references: Array of message references
    /// - Returns: Array of processed emails
    private func fetchMessageDetails(for references: [GmailMessageReference]) async -> [ProcessedEmail] {
        var processedEmails: [ProcessedEmail] = []
        
        // Fetch in batches to avoid overwhelming the API
        for reference in references {
            do {
                let message = try await emailService.getMessage(id: reference.id)
                
                // Convert to ProcessedEmail
                if let processed = ProcessedEmail.from(message) {
                    processedEmails.append(processed)
                }
                
            } catch {
                print("⚠️ Failed to fetch message \(reference.id): \(error)")
            }
        }
        
        return processedEmails
    }
    
    // MARK: - Email Selection
    
    /// Selects an email for viewing
    ///
    /// - Parameter email: The email to select
    func selectEmail(_ email: ProcessedEmail) {
        selectedEmail = email
        
        // Find index
        if let index = emails.firstIndex(where: { $0.id == email.id }) {
            selectedEmailIndex = index
        }
        
        // Load full content if needed
        _Concurrency.Task {
            await loadEmailContent(email)
        }
    }
    
    /// Selects the next email
    func selectNextEmail() {
        guard !emails.isEmpty else { return }
        
        let nextIndex = (selectedEmailIndex + 1) % emails.count
        selectedEmailIndex = nextIndex
        selectedEmail = emails[nextIndex]
        
        _Concurrency.Task {
            await loadEmailContent(emails[nextIndex])
        }
    }
    
    /// Selects the previous email
    func selectPreviousEmail() {
        guard !emails.isEmpty else { return }
        
        let prevIndex = selectedEmailIndex > 0 ? selectedEmailIndex - 1 : emails.count - 1
        selectedEmailIndex = prevIndex
        selectedEmail = emails[prevIndex]
        
        _Concurrency.Task {
            await loadEmailContent(emails[prevIndex])
        }
    }
    
    /// Loads full email content
    ///
    /// - Parameter email: The email to load content for
    private func loadEmailContent(_ email: ProcessedEmail) async {
        isLoadingContent = true
        
        // Simulate async content loading (in real app, fetch from service)
        emailContent = email.body
        
        await MainActor.run {
            isLoadingContent = false
        }
    }
    
    // MARK: - Task Creation
    
    /// Creates a task from the selected email
    func createTaskFromSelectedEmail() {
        guard let email = selectedEmail else {
            print("⚠️ No email selected")
            return
        }
        
        createTaskFromEmail(email)
    }
    
    /// Creates a task from an email
    ///
    /// - Parameter email: The email to create a task from
    func createTaskFromEmail(_ email: ProcessedEmail) {
        let task = DiligenceTask(
            title: email.subject,
            taskDescription: email.snippet,
            emailID: email.id,
            emailSubject: email.subject,
            emailSender: email.senderEmail,
            gmailURL: email.gmailURL.absoluteString
        )
        
        do {
            try taskService.createTask(task, in: modelContext)
            print("✅ Created task from email: \(email.subject)")
            
            // Post notification
            NotificationCenter.default.post(
                name: Notification.Name("TriggerRemindersSync"),
                object: nil
            )
        } catch {
            self.error = error
            print("❌ Failed to create task from email: \(error)")
        }
    }
    
    // MARK: - AI Task Generation
    
    /// Generates tasks from selected emails using AI
    func generateAITasks() async {
        guard isAIAvailable else {
            error = AIServiceError.notAvailable
            return
        }
        
        let emailsToAnalyze = emails.prefix(10).map { $0 } // Analyze first 10
        
        isGeneratingTasks = true
        aiGeneratedTasks = []
        error = nil
        
        do {
            let tasks = try await aiService.generateTasks(
                from: emailsToAnalyze,
                preferences: TaskGenerationPreferences(
                    includeAttachments: true,
                    dueDateStrategy: "tomorrow",
                    autoAssignSections: false
                )
            )
            
            await MainActor.run {
                aiGeneratedTasks = tasks
                showingAITasksSheet = tasks.count > 0
                isGeneratingTasks = false
                
                print("✅ Generated \(tasks.count) AI tasks")
            }
            
        } catch let aiError as AIServiceError {
            await MainActor.run {
                error = aiError
                isGeneratingTasks = false
            }
            print("❌ AI task generation failed: \(aiError)")
        } catch {
            await MainActor.run {
                self.error = error
                isGeneratingTasks = false
            }
            print("❌ AI task generation failed: \(error)")
        }
    }
    
    /// Creates actual tasks from AI-generated suggestions
    ///
    /// - Parameter generatedTasks: The AI-generated tasks to create
    func createTasksFromAISuggestions(_ generatedTasks: [GeneratedTask]) {
        for generatedTask in generatedTasks {
            let task = DiligenceTask(
                title: generatedTask.title,
                taskDescription: generatedTask.description,
                dueDate: generatedTask.suggestedDueDate,
                emailID: generatedTask.sourceEmailID
            )
            
            do {
                try taskService.createTask(task, in: modelContext)
            } catch {
                print("⚠️ Failed to create task: \(error)")
            }
        }
        
        print("✅ Created \(generatedTasks.count) tasks from AI suggestions")
        
        // Post notification
        NotificationCenter.default.post(
            name: Notification.Name("TriggerRemindersSync"),
            object: nil
        )
        
        // Close sheet
        showingAITasksSheet = false
        aiGeneratedTasks = []
    }
    
    // MARK: - Search and Filter
    
    /// Sets up search query debouncing
    private func setupSearchDebouncing() {
        $searchQuery
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                _Concurrency.Task {
                    await self?.fetchEmails()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Changes the email filter
    ///
    /// - Parameter filter: The new filter to apply
    func changeFilter(_ filter: EmailFilter) {
        selectedFilter = filter
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

// MARK: - Email Filter

/// Available email filters
enum EmailFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case today = "Today"
    case thisWeek = "This Week"
    case hasAttachments = "With Attachments"
    case unread = "Unread"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all:
            return "tray.fill"
        case .today:
            return "calendar"
        case .thisWeek:
            return "calendar.badge.clock"
        case .hasAttachments:
            return "paperclip"
        case .unread:
            return "envelope.badge"
        }
    }
}

// MARK: - View Model Factory

extension GmailViewModel {
    /// Creates a view model for testing or preview
    ///
    /// - Parameter context: Model context to use
    /// - Returns: Configured view model
    static func preview(context: ModelContext) -> GmailViewModel {
        return GmailViewModel(modelContext: context)
    }
}
