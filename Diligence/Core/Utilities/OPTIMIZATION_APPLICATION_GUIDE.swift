//
//  OPTIMIZATION_APPLICATION_GUIDE.swift
//  Diligence
//
//  Step-by-step guide to applying optimizations to existing code
//

import SwiftUI
import SwiftData
import Combine

/*
 APPLYING PERFORMANCE OPTIMIZATIONS TO EXISTING CODE
 ===================================================
 
 This file shows concrete examples of how to apply the performance
 optimizations to your existing Diligence codebase.
 */

// MARK: - Example 1: Optimizing GmailViewModel

/*
 BEFORE: GmailViewModel without optimizations
 */

class GmailViewModel_Before: ObservableObject {
    @Published var emails: [ProcessedEmail] = []
    @Published var isLoading = false
    
    private let gmailService = GmailService()
    
    func loadEmails() async {
        isLoading = true
        defer { isLoading = false }
        
        // No caching, no pagination, no cancellation
        await gmailService.loadRecentEmails(maxResults: 500)
        emails = gmailService.emails
    }
}

/*
 AFTER: GmailViewModel with all optimizations applied
 */

@MainActor  // Optimization 1: Main actor annotation
class GmailViewModel_After: ObservableObject {
    @Published var emails: [ProcessedEmail] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let gmailService = GmailService()
    private let paginationManager = EmailPaginationManager(pageSize: 50)
    private let cancellables = CancellableTaskManager()
    
    // Optimization 2: Track performance
    func loadEmails() async {
        await PerformanceMonitor.shared.measure("gmail_load_initial") { @MainActor in
            isLoading = true
            error = nil
            
            // Optimization 3: Cancellable task
            let task = _Concurrency.Task  { @MainActor in
                defer { isLoading = false }
                
                do {
                    paginationManager.reset()
                    
                    // Optimization 4: Check cache first
                    let newEmails = try await loadWithCaching()
                    
                    await MainActor.run {
                        emails = newEmails
                    }
                } catch {
                    if !_Concurrency.Task.isCancelled {
                        await MainActor.run {
                            self.error = error
                        }
                    }
                }
            }
            
            cancellables.store("load_emails", task: task)
        }
    }
    
    // Optimization 5: Pagination support
    func loadMoreEmails() async {
        guard !isLoading && paginationManager.hasMorePages else { return }
        
        await PerformanceMonitor.shared.measure("gmail_load_more") { @MainActor in
            isLoading = true
            defer { isLoading = false }
            
            do {
                let newEmails = try await paginationManager.loadNextPage(from: gmailService as! EmailServiceProtocol)
                
                await MainActor.run {
                    emails.append(contentsOf: newEmails)
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    // Optimization 6: Cache integration
    private func loadWithCaching() async throws -> [ProcessedEmail] {
        let newEmails = try await paginationManager.loadNextPage(from: gmailService as! EmailServiceProtocol)
        
        // Emails are automatically cached by paginationManager
        // But we can explicitly cache too
        EmailCacheManager.shared.cacheEmails(newEmails)
        
        return newEmails
    }
    
    // Optimization 7: Proper cleanup
    func cancelAll() {
        cancellables.cancelAll()
    }
}

// MARK: - Example 2: Optimizing GmailView

/*
 BEFORE: GmailView without optimizations
 */

struct GmailView_Before: View {
    @StateObject private var viewModel = GmailViewModel_Before()
    
    var body: some View {
        List(viewModel.emails) { email in
            // Simple row
            Text(email.subject)
        }
        .task {
            await viewModel.loadEmails()
        }
    }
}

/*
 AFTER: GmailView with optimizations
 */

struct GmailView_After: View {
    @StateObject private var viewModel = GmailViewModel_After()
    
    var body: some View {
        List {
            // Iterate using Array(emails) to ensure we have a proper collection
            ForEach(Array(viewModel.emails.enumerated()), id: \.offset) { index, email in
                EmailRowView_Optimized(email: email)
                    .onAppear {
                        if shouldLoadMore(email) {
                            _Concurrency.Task {
                                await viewModel.loadMoreEmails()
                            }
                        }
                    }
            }
            
            // Loading indicator for pagination
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            }
        }
        .trackPerformance("GmailView")  // Optimization: Track view performance
        .task {
            await viewModel.loadEmails()
        }
        .onDisappear {
            viewModel.cancelAll()  // Optimization: Cancel on disappear
        }
        .overlay {
            if let error = viewModel.error {
                ErrorBanner(error: error) {
                    _Concurrency.Task {
                        await viewModel.loadEmails()
                    }
                }
            }
        }
    }
    
    private func shouldLoadMore(_ email: ProcessedEmail) -> Bool {
        guard let index = viewModel.emails.firstIndex(where: { $0.id == email.id }) else {
            return false
        }
        return index >= viewModel.emails.count - 10
    }
}

// Optimized email row with caching
struct EmailRowView_Optimized: View {
    let email: ProcessedEmail
    @State private var cachedImage: NSImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Optimization: Cache sender avatar/image
            if let image = cachedImage {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(email.subject)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(email.sender)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(email.receivedDate, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Example 3: Optimizing AI Query Interface

/*
 BEFORE: AI query without optimizations
 */

struct AIQueryView_Before: View {
    let emails: [ProcessedEmail]
    let aiService: EnhancedAIEmailService
    
    @State private var query = ""
    @State private var response = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            TextField("Query", text: $query)
            
            Button("Query") {
                _Concurrency.Task {
                    isLoading = true
                    response = try! await aiService.queryEmails(
                        query: query,
                        emails: emails
                    )
                    isLoading = false
                }
            }
            
            if isLoading {
                ProgressView()
            }
            
            Text(response)
        }
    }
}

/*
 AFTER: AI query with full optimizations
 */

struct AIQueryView_After: View {
    let emails: [ProcessedEmail]
    let aiService: EnhancedAIEmailService
    
    @State private var query = ""
    @State private var response = ""
    @State private var error: Error?
    @StateObject private var queryManager = CancellableAIQueryManager()
    
    var body: some View {
        VStack(spacing: 16) {
            // Query input
            HStack {
                TextField("Ask about your emails...", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .disabled(queryManager.isQuerying)
                
                if queryManager.isQuerying {
                    Button("Cancel", action: {
                        queryManager.cancelCurrentQuery()
                    })
                    .buttonStyle(.bordered)
                } else {
                    Button("Query", action: {
                        performOptimizedQuery()
                    })
                    .buttonStyle(.borderedProminent)
                    .disabled(query.isEmpty || emails.isEmpty)
                }
            }
            
            // Optimization: Progress tracking
            if queryManager.isQuerying {
                VStack(spacing: 8) {
                    ProgressView(value: queryManager.progress)
                    Text("Processing... \(Int(queryManager.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Response display
            if !response.isEmpty {
                ScrollView {
                    Text(response)
                        .textSelection(.enabled)
                        .padding()
                }
                .frame(maxHeight: 300)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
            }
            
            // Error handling
            if let error = error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                    Spacer()
                    Button("Dismiss", action: {
                        self.error = nil
                    })
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .trackPerformance("AIQueryView")
    }
    
    // Optimization: Use optimized query with cancellation
    private func performOptimizedQuery() {
        error = nil
        response = ""
        
        _Concurrency.Task {
            do {
                // Use optimized context window management
                let result = try await queryManager.executeQuery(
                    query,
                    emails: emails,
                    using: aiService
                )
                
                await MainActor.run {
                    response = result
                }
            } catch is CancellationError {
                // Query was cancelled, don't show error
                await MainActor.run {
                    response = "Query cancelled"
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
}

// MARK: - Example 4: Optimizing Settings Persistence

/*
 BEFORE: Direct UserDefaults access
 */

class Settings_Before {
    static var theme: String {
        get { UserDefaults.standard.string(forKey: "theme") ?? "light" }
        set { UserDefaults.standard.set(newValue, forKey: "theme") }
    }
    
    static var emailPageSize: Int {
        get { UserDefaults.standard.integer(forKey: "emailPageSize") }
        set { UserDefaults.standard.set(newValue, forKey: "emailPageSize") }
    }
}

/*
 AFTER: Optimized settings with caching and observation
 */

@MainActor
final class Settings_After: ObservableObject {
    static let shared = Settings_After()
    
    // Optimization: Use @AppStorage for automatic observation
    @AppStorage("theme") var theme: String = "light"
    @AppStorage("emailPageSize") var emailPageSize: Int = 50
    @AppStorage("enableCache") var enableCache: Bool = true
    @AppStorage("maxMemoryMB") var maxMemoryMB: Double = 200
    
    // Optimization: Batched writes
    private var pendingWrites: [String: Any] = [:]
    private var writeTimer: Timer?
    
    private init() {
        // Track performance of settings access
        PerformanceMonitor.shared.recordEvent("settings_initialized")
    }
    
    // Optimization: Batch settings updates
    func batchUpdate(_ updates: [String: Any]) {
        for (key, value) in updates {
            pendingWrites[key] = value
        }
        
        // Debounce writes
        writeTimer?.invalidate()
        writeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.flushWrites()
        }
    }
    
    private func flushWrites() {
        PerformanceMonitor.shared.measureSync("settings_batch_write") {
            let defaults = UserDefaults.standard
            
            for (key, value) in pendingWrites {
                defaults.set(value, forKey: key)
            }
            
            pendingWrites.removeAll()
        }
    }
    
    // Optimization: Clear cache when settings change
    func resetCache() {
        EmailCacheManager.shared.purgeCache()
        PerformanceMonitor.shared.reset()
    }
}

// Usage in SwiftUI
struct SettingsView_After: View {
    @StateObject private var settings = Settings_After.shared
    
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $settings.theme) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("Auto").tag("auto")
                }
            }
            
            Section("Performance") {
                Stepper("Page Size: \(settings.emailPageSize)", 
                       value: $settings.emailPageSize, 
                       in: 10...200, 
                       step: 10)
                
                Toggle("Enable Cache", isOn: $settings.enableCache)
                
                Slider(value: $settings.maxMemoryMB, 
                      in: 50...500, 
                      step: 50) {
                    Text("Max Memory: \(Int(settings.maxMemoryMB)) MB")
                }
            }
            
            Section("Debug") {
                Button("Clear Cache", action: {
                    settings.resetCache()
                })
                
                Button("Performance Report", action: {
                    PerformanceMonitor.shared.printReport()
                })
            }
        }
        .trackPerformance("SettingsView")
    }
}

// MARK: - Example 5: Optimizing Task Operations

/*
 BEFORE: Direct SwiftData operations
 */

func deleteTask_Before(_ task: DiligenceTask, context: ModelContext) {
    context.delete(task)
    try? context.save()
}

func toggleCompletion_Before(_ task: DiligenceTask, context: ModelContext) {
    task.isCompleted.toggle()
    try? context.save()
}

/*
 AFTER: Optimized with batching and performance tracking
 */

@MainActor
class TaskOperations_After {
    private let context: ModelContext
    private var pendingOperations: [() -> Void] = []
    private var saveTimer: Timer?
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // Optimization: Batch deletions
    func deleteTask(_ task: DiligenceTask) {
        PerformanceMonitor.shared.recordEvent("task_delete_queued")
        
        pendingOperations.append { [weak context] in
            context?.delete(task)
        }
        
        scheduleSave()
    }
    
    // Optimization: Batch updates
    func toggleCompletion(_ task: DiligenceTask) {
        PerformanceMonitor.shared.recordEvent("task_toggle_queued")
        
        pendingOperations.append {
            task.isCompleted.toggle()
        }
        
        scheduleSave()
    }
    
    // Optimization: Debounced save
    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.executePendingOperations()
        }
    }
    
    private func executePendingOperations() {
        guard !pendingOperations.isEmpty else { return }
        
        PerformanceMonitor.shared.measureSync("task_batch_save") {
            for operation in pendingOperations {
                operation()
            }
            
            do {
                try context.save()
                PerformanceMonitor.shared.recordEvent("task_batch_save_success")
            } catch {
                print("Error saving: \(error)")
                PerformanceMonitor.shared.recordEvent("task_batch_save_error")
            }
            
            pendingOperations.removeAll()
        }
    }
    
    // Force immediate save when needed
    func saveImmediately() {
        saveTimer?.invalidate()
        executePendingOperations()
    }
}

// MARK: - Example 6: Complete App Integration

// Helper function to create SwiftData ModelContainer
@MainActor
private func makeSwiftDataContainer() -> SwiftData.ModelContainer {
    let schema = SwiftData.Schema([DiligenceTask.self, TaskSection.self])
    let config = SwiftData.ModelConfiguration(schema: schema)
    return try! SwiftData.ModelContainer(for: schema, configurations: [config])
}

struct DiligenceApp_Optimized: App {
    @StateObject private var container = DependencyContainer.shared
    
    // Explicitly create SwiftData container to avoid symbol collision
    private let modelContainer = makeSwiftDataContainer()
    
    init() {
        setupPerformanceMonitoring()
    }
    
    var body: some Scene {
        SwiftUI.WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(\.dependencyContainer, container)
                .task {
                    // Start performance monitoring
                    await logStartupMetrics()
                }
        }
        .commands {
            SwiftUI.CommandGroup(replacing: .help) {
                SwiftUI.Button("Performance Report") {
                    PerformanceMonitor.shared.printReport()
                }
                
                SwiftUI.Button("Clear Cache") {
                    EmailCacheManager.shared.purgeCache()
                }
            }
        }
    }
    
    private func setupPerformanceMonitoring() {
        _Concurrency.Task { @MainActor in
            PerformanceMonitor.shared.startMonitoring()
            PerformanceMonitor.shared.enableLogging = true
            
            // Log initial memory
            let memoryMB = PerformanceMonitor.shared.currentMemoryUsageMB
            print("📊 App started with \(String(format: "%.2f", memoryMB)) MB memory usage")
        }
    }
    
    private func logStartupMetrics() async {
        PerformanceMonitor.shared.recordEvent("app_startup")
        
        let memoryMB = PerformanceMonitor.shared.currentMemoryUsageMB
        print("📊 Post-initialization memory: \(String(format: "%.2f", memoryMB)) MB")
    }
}

// MARK: - Helper Views

private struct ErrorBanner: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.white)
                Text(error.localizedDescription)
                    .foregroundColor(.white)
                    .font(.caption)
            }
            
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding()
        .background(Color.red)
        .cornerRadius(8)
        .padding()
    }
}

/*
 MIGRATION CHECKLIST
 ==================
 
 Apply these optimizations in order:
 
 □ 1. Add PerformanceMonitor to app initialization
 □ 2. Add @MainActor to all view models and UI classes
 □ 3. Replace direct service instantiation with DI
 □ 4. Add CancellableTaskManager to long-running operations
 □ 5. Integrate EmailCacheManager in GmailService
 □ 6. Add EmailPaginationManager to email views
 □ 7. Replace direct AI queries with optimized versions
 □ 8. Add performance tracking to critical operations
 □ 9. Optimize SwiftData queries with predicates
 □ 10. Add .trackPerformance() to main views
 □ 11. Implement proper task cancellation in .onDisappear
 □ 12. Test and measure improvements
 
 */
