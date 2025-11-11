//
//  EmailCacheManager.swift
//  Diligence
//
//  Optimization 2: Caching layer for emails and attachments with pagination support
//

import Foundation
import AppKit
import Combine
import SwiftUI

// MARK: - Email Cache Manager

/// Manages caching of emails and attachments with memory-aware purging
@MainActor
final class EmailCacheManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = EmailCacheManager()
    
    // MARK: - Cache Storage
    
    private var emailCache: NSCache<NSString, CachedEmail>
    private var attachmentCache: NSCache<NSString, CachedAttachment>
    private var imageCache: NSCache<NSString, NSImage>
    
    // MARK: - Published Properties
    
    @Published private(set) var cacheStats: CacheStatistics
    
    // MARK: - Configuration
    
    private let emailCacheLimit = 200 // Number of emails
    private let attachmentCacheLimit = 50 // Number of attachments
    private let imageCacheLimit = 100 // Number of images
    private let emailMemoryLimit = 50 * 1024 * 1024 // 50 MB
    private let attachmentMemoryLimit = 100 * 1024 * 1024 // 100 MB
    private let imageMemoryLimit = 50 * 1024 * 1024 // 50 MB
    
    // MARK: - Initialization
    
    private init() {
        emailCache = NSCache<NSString, CachedEmail>()
        emailCache.countLimit = emailCacheLimit
        emailCache.totalCostLimit = emailMemoryLimit
        
        attachmentCache = NSCache<NSString, CachedAttachment>()
        attachmentCache.countLimit = attachmentCacheLimit
        attachmentCache.totalCostLimit = attachmentMemoryLimit
        
        imageCache = NSCache<NSString, NSImage>()
        imageCache.countLimit = imageCacheLimit
        imageCache.totalCostLimit = imageMemoryLimit
        
        cacheStats = CacheStatistics()
        
        setupMemoryWarningObserver()
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: .performancePurgeCache,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.purgeCache()
        }
    }
    
    func purgeCache() {
        PerformanceMonitor.shared.recordEvent("cache_purge")
        
        emailCache.removeAllObjects()
        attachmentCache.removeAllObjects()
        imageCache.removeAllObjects()
        
        updateStatistics()
    }
    
    func purgeLowPriorityCache() {
        // Remove half of the cached items (oldest first through natural NSCache eviction)
        PerformanceMonitor.shared.recordEvent("cache_purge_low_priority")
        
        // NSCache automatically removes least-recently-used items
        // We just need to reduce the limits temporarily
        let originalEmailLimit = emailCache.countLimit
        let originalAttachmentLimit = attachmentCache.countLimit
        let originalImageLimit = imageCache.countLimit
        
        emailCache.countLimit = originalEmailLimit / 2
        attachmentCache.countLimit = originalAttachmentLimit / 2
        imageCache.countLimit = originalImageLimit / 2
        
        // Restore original limits
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.emailCache.countLimit = originalEmailLimit
            self?.attachmentCache.countLimit = originalAttachmentLimit
            self?.imageCache.countLimit = originalImageLimit
        }
        
        updateStatistics()
    }
    
    // MARK: - Email Caching
    
    func cacheEmail(_ email: ProcessedEmail, cost: Int? = nil) {
        let key = NSString(string: email.id)
        let cachedEmail = CachedEmail(email: email, cachedDate: Date())
        
        // Estimate cost based on email content size
        let estimatedCost = cost ?? estimateEmailCost(email)
        
        emailCache.setObject(cachedEmail, forKey: key, cost: estimatedCost)
        cacheStats.emailCacheHits += 1
        
        PerformanceMonitor.shared.recordEvent("email_cached")
    }
    
    func getEmail(_ emailId: String) -> ProcessedEmail? {
        let key = NSString(string: emailId)
        
        if let cached = emailCache.object(forKey: key) {
            cacheStats.emailCacheHits += 1
            PerformanceMonitor.shared.recordEvent("email_cache_hit")
            return cached.email
        }
        
        cacheStats.emailCacheMisses += 1
        PerformanceMonitor.shared.recordEvent("email_cache_miss")
        return nil
    }
    
    func cacheEmails(_ emails: [ProcessedEmail]) {
        for email in emails {
            cacheEmail(email)
        }
    }
    
    private func estimateEmailCost(_ email: ProcessedEmail) -> Int {
        let subjectCost = email.subject.utf8.count
        let bodyCost = email.body.utf8.count
        let snippetCost = email.snippet.utf8.count
        return subjectCost + bodyCost + snippetCost
    }
    
    // MARK: - Attachment Caching
    
    func cacheAttachment(_ attachmentId: String, data: Data) {
        let key = NSString(string: attachmentId)
        let cached = CachedAttachment(data: data, cachedDate: Date())
        
        attachmentCache.setObject(cached, forKey: key, cost: data.count)
        cacheStats.attachmentCacheHits += 1
        
        PerformanceMonitor.shared.recordEvent("attachment_cached")
    }
    
    func getAttachment(_ attachmentId: String) -> Data? {
        let key = NSString(string: attachmentId)
        
        if let cached = attachmentCache.object(forKey: key) {
            cacheStats.attachmentCacheHits += 1
            PerformanceMonitor.shared.recordEvent("attachment_cache_hit")
            return cached.data
        }
        
        cacheStats.attachmentCacheMisses += 1
        PerformanceMonitor.shared.recordEvent("attachment_cache_miss")
        return nil
    }
    
    // MARK: - Image Caching
    
    func cacheImage(_ imageId: String, image: NSImage) {
        let key = NSString(string: imageId)
        
        // Estimate image size
        let estimatedSize = Int(image.size.width * image.size.height * 4) // RGBA
        
        imageCache.setObject(image, forKey: key, cost: estimatedSize)
        cacheStats.imageCacheHits += 1
        
        PerformanceMonitor.shared.recordEvent("image_cached")
    }
    
    func getImage(_ imageId: String) -> NSImage? {
        let key = NSString(string: imageId)
        
        if let cached = imageCache.object(forKey: key) {
            cacheStats.imageCacheHits += 1
            PerformanceMonitor.shared.recordEvent("image_cache_hit")
            return cached
        }
        
        cacheStats.imageCacheMisses += 1
        PerformanceMonitor.shared.recordEvent("image_cache_miss")
        return nil
    }
    
    // MARK: - Statistics
    
    private func updateStatistics() {
        // NSCache doesn't expose current count, so we track it manually via stats
        PerformanceMonitor.shared.recordEvent("cache_stats_updated")
    }
    
    func resetStatistics() {
        cacheStats = CacheStatistics()
    }
}

// MARK: - Cached Objects

private class CachedEmail: NSObject {
    let email: ProcessedEmail
    let cachedDate: Date
    
    init(email: ProcessedEmail, cachedDate: Date) {
        self.email = email
        self.cachedDate = cachedDate
    }
}

private class CachedAttachment: NSObject {
    let data: Data
    let cachedDate: Date
    
    init(data: Data, cachedDate: Date) {
        self.data = data
        self.cachedDate = cachedDate
    }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    var emailCacheHits: Int = 0
    var emailCacheMisses: Int = 0
    var attachmentCacheHits: Int = 0
    var attachmentCacheMisses: Int = 0
    var imageCacheHits: Int = 0
    var imageCacheMisses: Int = 0
    
    var emailHitRate: Double {
        let total = emailCacheHits + emailCacheMisses
        return total > 0 ? Double(emailCacheHits) / Double(total) : 0
    }
    
    var attachmentHitRate: Double {
        let total = attachmentCacheHits + attachmentCacheMisses
        return total > 0 ? Double(attachmentCacheHits) / Double(total) : 0
    }
    
    var imageHitRate: Double {
        let total = imageCacheHits + imageCacheMisses
        return total > 0 ? Double(imageCacheHits) / Double(total) : 0
    }
}

// MARK: - Email Pagination Manager

/// Manages pagination for large email lists
@MainActor
final class EmailPaginationManager: ObservableObject {
    
    // MARK: - Configuration
    
    let pageSize: Int
    private(set) var currentPage: Int = 0
    
    // MARK: - Published Properties
    
    @Published private(set) var isLoading = false
    @Published private(set) var hasMorePages = true
    @Published private(set) var totalEmails: Int?
    
    // MARK: - Private Properties
    
    private var loadedEmailIds = Set<String>()
    private var cancellables = CancellableTaskManager()
    
    // MARK: - Initialization
    
    init(pageSize: Int = 50) {
        self.pageSize = pageSize
    }
    
    // MARK: - Pagination Control
    
    func reset() {
        currentPage = 0
        hasMorePages = true
        totalEmails = nil
        loadedEmailIds.removeAll()
        cancellables.cancelAll()
    }
    
    func loadNextPage(
        from service: any EmailServiceProtocol
    ) async throws -> [ProcessedEmail] {
        guard !isLoading && hasMorePages else {
            return []
        }
        
        return try await PerformanceMonitor.shared.measure("email_pagination_load_page") {
            isLoading = true
            defer { isLoading = false }
            
            // Calculate pagination parameters
            let startIndex = currentPage * pageSize
            
            // Fetch emails from service
            let emails = try await service.fetchEmails(
                maxResults: pageSize,
                pageToken: nil // Implement page token if service supports it
            )
            
            // Filter out already loaded emails
            let newEmails = emails.filter { !loadedEmailIds.contains($0.id) }
            
            // Update state
            for email in newEmails {
                loadedEmailIds.insert(email.id)
            }
            
            currentPage += 1
            hasMorePages = newEmails.count == pageSize
            
            // Cache the emails
            EmailCacheManager.shared.cacheEmails(newEmails)
            
            return newEmails
        }
    }
    
    func shouldLoadMore(currentItem: ProcessedEmail, items: [ProcessedEmail]) -> Bool {
        // Load more when user scrolls to last 10 items
        guard let index = items.firstIndex(where: { $0.id == currentItem.id }) else {
            return false
        }
        
        return index >= items.count - 10 && hasMorePages && !isLoading
    }
}

// MARK: - Paginated Email List View

struct PaginatedEmailListView: View {
    @StateObject private var paginationManager = EmailPaginationManager(pageSize: 50)
    @StateObject private var cacheManager = EmailCacheManager.shared
    
    let emailService: any EmailServiceProtocol
    @State private var emails: [ProcessedEmail] = []
    @State private var error: Error?
    
    var body: some View {
        VStack(spacing: 0) {
            if emails.isEmpty && !paginationManager.isLoading {
                emptyStateView
            } else {
                emailList
            }
            
            if let error = error {
                errorView(error)
            }
        }
        .trackPerformance("PaginatedEmailList")
        .task {
            await loadInitialPage()
        }
    }
    
    private var emailList: some View {
        List {
            ForEach($emails) { $email in
                EmailRowView(
                    email: email,
                    isSelected: false,
                    onSelectionToggle: { }
                )
                .onAppear {
                    if paginationManager.shouldLoadMore(
                        currentItem: email,
                        items: emails
                    ) {
                        _Concurrency.Task {
                            await loadNextPage()
                        }
                    }
                }
            }
            
            if paginationManager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            }
            
            if !paginationManager.hasMorePages && !emails.isEmpty {
                HStack {
                    Spacer()
                    Text("All emails loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                }
            }
        }
        .listStyle(.inset)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No emails")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Button("Refresh") {
                _Concurrency.Task {
                    await loadInitialPage()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: Error) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button("Dismiss") {
                self.error = nil
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding()
        .background(Color.red.opacity(0.1))
    }
    
    private func loadInitialPage() async {
        paginationManager.reset()
        emails.removeAll()
        
        do {
            let newEmails = try await paginationManager.loadNextPage(from: emailService)
            emails = newEmails
        } catch {
            self.error = error
        }
    }
    
    private func loadNextPage() async {
        do {
            let newEmails = try await paginationManager.loadNextPage(from: emailService)
            emails.append(contentsOf: newEmails)
        } catch {
            self.error = error
        }
    }
}

// MARK: - Note
// EmailRowView is defined in GmailView.swift and requires:
// - email: ProcessedEmail
// - isSelected: Bool
// - onSelectionToggle: () -> Void

// MARK: - Protocol Extension for Pagination Support

extension EmailServiceProtocol {
    /// Fetch emails with pagination support
    func fetchEmails(
        maxResults: Int,
        pageToken: String?
    ) async throws -> [ProcessedEmail] {
        // Default implementation - services can override
        // This assumes the service has a method to fetch emails
        // In reality, you'd implement this in each service
        return []
    }
}
