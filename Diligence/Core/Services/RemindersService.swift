//
//  RemindersService.swift
//  Diligence
//
//  Created by derham on 10/28/25.
//

import Foundation
import EventKit
import Combine
import AppKit

// Extension to create NSColor from hex strings
extension NSColor {
    convenience init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&int) else {
            return nil
        }
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, (int >> 8) & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }
}

// Data transfer object for section synchronization
struct SectionSyncData: Equatable, Hashable {
    let id: String
    let title: String
    let color: String? // Store color as hex string - deprecated, will be removed
    let sortOrder: Int
    let reminderID: String? // The section header reminder ID
}
// Data transfer object for task synchronization
struct TaskSyncData: Equatable, Hashable {
    let id: String // Use a string ID instead of PersistentIdentifier
    let title: String
    let description: String
    let isCompleted: Bool
    let dueDate: Date?
    let reminderID: String?
    let isFromEmail: Bool
    let emailSender: String?
    let emailSubject: String?
    let sectionID: String? // Link to section
    let recurrencePattern: RecurrencePattern?
    let recurrenceDescription: String
    let isRecurringInstance: Bool
}

@MainActor
class RemindersService: ObservableObject {
    private var eventStore = EKEventStore()
    // Store calendar IDs instead of objects to avoid expensive equality checks
    private var diligenceCalendarIDs: [String: String] = [:] // sectionID -> calendar ID
    private var defaultCalendarID: String? // For unsectioned tasks
    private let defaultListName = "Diligence - Tasks"
    private let diligenceCalendarIDKey = "DiligenceDefaultCalendarID"
    private let sectionCalendarIDsKey = "DiligenceSectionCalendarIDs"
    private let diligenceListPrefix = "Diligence - " // Prefix for all Diligence-created lists
    private let diligenceMetadataKey = "DiligenceCreated" // Custom metadata to identify our lists (unused, reserved)
    
    // XPC Connection management
    private var connectionRetryCount = 0
    private let maxRetryCount = 3
    private var isReconnecting = false
    
    @Published var isAuthorized = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var sections: [SectionSyncData] = []
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success
        case error(String)
        case reconnecting
    }
    
    private let syncInterval: TimeInterval = 300 // reserved
    private var syncTimer: Timer?
    
    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAuthorizationStatus()
        }
        startPeriodicSync()
        setupApplicationLifecycleMonitoring()
    }
    
    // MARK: - Calendar Helper Methods
    
    /// Fetch calendar by ID when needed (avoids storing EKCalendar objects)
    private func getCalendar(forID calendarID: String?) -> EKCalendar? {
        guard let calendarID = calendarID else { return nil }
        return eventStore.calendar(withIdentifier: calendarID)
    }
    
    /// Get calendar for a specific section
    private func getCalendar(forSection sectionID: String) -> EKCalendar? {
        guard let calendarID = diligenceCalendarIDs[sectionID] else { return nil }
        return eventStore.calendar(withIdentifier: calendarID)
    }
    
    /// Get the default calendar
    private func getDefaultCalendar() -> EKCalendar? {
        guard let calendarID = defaultCalendarID else { return nil }
        return eventStore.calendar(withIdentifier: calendarID)
    }
    
    /// Computed property for convenient access to default calendar
    private var defaultCalendar: EKCalendar? {
        return getDefaultCalendar()
    }
    
    private func setupApplicationLifecycleMonitoring() {
        // Monitor app lifecycle to detect when XPC connections might be invalidated
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            _Concurrency.Task { @MainActor [weak self] in
                self?.handleAppBecameActive()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            _Concurrency.Task { @MainActor [weak self] in
                self?.handleAppWillResignActive()
            }
        }
        
        // Monitor system wake/sleep cycles which can invalidate XPC connections
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            _Concurrency.Task { @MainActor [weak self] in
                print("📝 System woke up - checking Reminders connection")
                self?.connectionRetryCount = 0 // Reset retry counter
                self?.checkAuthorizationStatus()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            _Concurrency.Task { @MainActor [weak self] in
                print("📝 System going to sleep - preparing for potential connection loss")
            }
        }
    }
    
    private func handleAppBecameActive() {
        print("📝 App became active - checking Reminders connection")
        
        // Reset retry counter when app becomes active
        connectionRetryCount = 0
        
        // Verify the connection is still valid by checking authorization
        checkAuthorizationStatus()
        
        // If we have tasks to sync, do a quick validation sync
        if isAuthorized {
            _Concurrency.Task {
                await validateXPCConnection()
            }
        }
    }
    
    private func validateXPCConnection() async {
        do {
            print("📝 Validating XPC connection to Reminders...")
            
            // Simple validation - try to access calendars with timeout
            let calendarsTask = _Concurrency.Task {
                return eventStore.calendars(for: .reminder)
            }
            
            // Set a timeout for the validation
            let timeoutTask = _Concurrency.Task {
                do {
                    try await _Concurrency.Task.sleep(nanoseconds: 3_000_000_000) // 3 second timeout
                    throw NSError(domain: "RemindersService", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Connection validation timeout"])
                } catch is CancellationError {
                    // Task was cancelled, which is expected - rethrow as timeout error
                    throw NSError(domain: "RemindersService", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Connection validation timeout"])
                }
            }
            
            let calendars = try await withThrowingTaskGroup(of: [EKCalendar].self) { group in
                group.addTask { try await calendarsTask.value }
                group.addTask { _ = try await timeoutTask.value; return [] }
                
                for try await result in group {
                    group.cancelAll()
                    return result
                }
                return []
            }
            
            print("📝 Reminders connection validated successfully - found \(calendars.count) calendars")
            
            // If we got here, connection is good
            if syncStatus == .reconnecting {
                syncStatus = .success
            }
            
        } catch {
            print("📝 XPC connection validation failed: \(error.localizedDescription)")
            
            // Try to handle the connection error
            let handled = await handleXPCConnectionError(error)
            if !handled {
                print("📝 Failed to recover from connection validation error")
            }
        }
    }
    
    private func handleAppWillResignActive() {
        print("📝 App will resign active - preparing for potential XPC disconnection")
        // Don't reset anything here, just log for debugging
    }
    
    deinit {
        // Clean up timer
        syncTimer?.invalidate()
        syncTimer = nil
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - XPC Connection Management
    
    private func handleXPCConnectionError(_ error: Error) async -> Bool {
        guard !isReconnecting else {
            print("📝 Already reconnecting, skipping...")
            return false
        }
        
        let errorMessage = error.localizedDescription.lowercased()
        let errorCode = (error as NSError).code
        
        // Enhanced XPC error detection
        let isXPCError = errorMessage.contains("xpc") ||
        errorMessage.contains("connection") ||
        errorMessage.contains("invalidated") ||
        errorMessage.contains("interrupted") ||
        errorCode == 4099 || // Connection invalid
        errorCode == 4097 || // Connection interrupted
        errorMessage.contains("0xa") // Memory address pattern often seen in XPC errors
        
        if isXPCError && connectionRetryCount < maxRetryCount {
            print("📝 XPC connection error detected: \(error.localizedDescription)")
            print("📝 Error code: \(errorCode), attempting reconnection (attempt \(connectionRetryCount + 1)/\(maxRetryCount))")
            connectionRetryCount += 1
            isReconnecting = true
            syncStatus = .reconnecting
            
            // Force garbage collection to clean up old connections
            autoreleasepool {
                // Recreate EventStore instance with proper cleanup
            }
            await recreateEventStore()
            
            // Progressive backoff with jitter: 1s, 2s, 3s, etc. + small random delay
            let baseDelay = UInt64(connectionRetryCount * 1_000_000_000)
            let jitter = UInt64.random(in: 0...500_000_000) // 0-0.5s jitter
            let backoffDelay = baseDelay + jitter
            
            print("📝 Waiting \(Double(backoffDelay) / 1_000_000_000.0)s before reconnection attempt...")
            try? await _Concurrency.Task.sleep(nanoseconds: backoffDelay)
            
            // Re-check authorization and setup
            checkAuthorizationStatus()
            
            // Longer delay for system services to stabilize
            try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000) // 1s
            
            isReconnecting = false
            
            // If still not authorized after setup, consider it a failure
            if !isAuthorized {
                print("📝 Reconnection failed - authorization lost")
                syncStatus = .error("Connection to Reminders lost. Please restart the app.")
                return false
            }
            
            print("📝 XPC reconnection successful")
            syncStatus = .success
            return true
        } else if isXPCError {
            print("📝 XPC connection failed after \(maxRetryCount) attempts")
            print("📝 Final error: \(error.localizedDescription) (code: \(errorCode))")
            syncStatus = .error("Connection to Reminders failed. Please restart the app or check system permissions.")
            connectionRetryCount = 0
            return false
        }
        
        return false
    }
    
    private func recreateEventStore() async {
        print("📝 Recreating EventStore instance...")
        
        // Clean up old instance more thoroughly
        defaultCalendarID = nil
        diligenceCalendarIDs.removeAll()
        
        // Force release the old event store
        eventStore = EKEventStore()
        
        // Give the new EventStore time to initialize and establish connections
        print("📝 Waiting for EventStore to initialize...")
        try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // Verify the new instance can access basic functionality
        do {
            let sources = eventStore.sources
            print("📝 New EventStore initialized with \(sources.count) sources")
            
            // Try to access calendars to test the connection
            let calendars = eventStore.calendars(for: .reminder)
            print("📝 New EventStore can access \(calendars.count) reminder calendars")
            
            // Additional stability wait
            try? await _Concurrency.Task.sleep(nanoseconds: 250_000_000) // 0.25s
        } catch {
            print("📝 Warning: New EventStore might not be fully ready: \(error)")
            // Give it more time
            try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000) // 1s
        }
        
        print("📝 EventStore recreation complete")
    }
    
    // Enhanced retry wrapper with better XPC handling
    private func executeWithXPCRetry<T>(_ operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        var attemptCount = 0
        
        while attemptCount <= maxRetryCount {
            do {
                return try await operation()
            } catch {
                lastError = error
                attemptCount += 1
                
                // Enhanced error analysis
                let errorMessage = error.localizedDescription.lowercased()
                let errorCode = (error as NSError).code
                
                // Check if this is an XPC error we can handle
                let isXPCError = errorMessage.contains("xpc") ||
                errorMessage.contains("connection") ||
                errorMessage.contains("invalidated") ||
                errorMessage.contains("interrupted") ||
                errorMessage.contains("0xa") || // Memory address pattern
                errorCode == 4099 || // Connection invalid
                errorCode == 4097    // Connection interrupted
                
                if isXPCError && attemptCount <= maxRetryCount {
                    print("📝 XPC error in operation (attempt \(attemptCount)/\(maxRetryCount)): \(error.localizedDescription)")
                    print("📝 Error code: \(errorCode)")
                    
                    // Try to handle the XPC error
                    let handled = await handleXPCConnectionError(error)
                    if !handled {
                        print("📝 XPC error handler failed, breaking retry loop")
                        break // Can't handle, give up
                    }
                    
                    // Brief pause before retrying the operation
                    let retryDelay = UInt64(200_000_000 * attemptCount) // Increasing delay: 0.2s, 0.4s, 0.6s
                    try? await _Concurrency.Task.sleep(nanoseconds: retryDelay)
                    print("📝 Retrying operation after XPC recovery...")
                    continue
                } else {
                    // Non-XPC error or max retries reached
                    print("📝 Non-XPC error or max retries reached: \(error.localizedDescription)")
                    break
                }
            }
        }
        
        // If we get here, all retries failed
        if let lastError {
            print("📝 All retry attempts failed, throwing last error: \(lastError.localizedDescription)")
            throw lastError
        } else {
            throw NSError(domain: "RemindersService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred during retry attempts"])
        }
    }
    
    // Bridge to call async handleXPCConnectionError from sync context used by executeWithRetry
    private func awaitTryHandle(_ error: Error) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var handled = false
        _Concurrency.Task { [weak self] in
            handled = await self?.handleXPCConnectionError(error) ?? false
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5)
        return handled
    }
    
    // MARK: - Authorization
    
    private func checkAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        
        switch status {
        case .fullAccess:
            isAuthorized = true
            _Concurrency.Task {
                await setupDiligenceList()
            }
        case .notDetermined:
            requestAccess()
        case .denied, .restricted:
            isAuthorized = false
            syncStatus = .error("Reminders access denied. Please enable in System Settings.")
        case .writeOnly:
            isAuthorized = false
            syncStatus = .error("Only write access granted. Full access is needed for sync.")
        @unknown default:
            isAuthorized = false
            syncStatus = .error("Unknown authorization status")
        }
    }
    
    func requestAccess() {
        print("📝 Requesting Reminders access...")
        
        if #available(macOS 14.0, iOS 17.0, *) {
            eventStore.requestFullAccessToReminders { [weak self] granted, error in
                _Concurrency.Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    print("📝 Full access request completed - Granted: \(granted)")
                    
                    if let error = error {
                        print("📝 Authorization error: \(error)")
                        self.syncStatus = .error("Authorization error: \(error.localizedDescription)")
                        self.isAuthorized = false
                        return
                    }
                    
                    if granted {
                        self.isAuthorized = true
                        // We are already on MainActor; call async method directly.
                        await self.setupDiligenceList()
                        print("📝 Full Reminders access granted")
                    } else {
                        self.isAuthorized = false
                        self.syncStatus = .error("Full Reminders access denied. Please grant access in System Settings > Privacy & Security > Calendars.")
                        print("📝 Full Reminders access denied by user")
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .reminder) { [weak self] granted, error in
                _Concurrency.Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    print("📝 Legacy access request completed - Granted: \(granted)")
                    
                    if let error = error {
                        print("📝 Authorization error: \(error)")
                        self.syncStatus = .error("Authorization error: \(error.localizedDescription)")
                        self.isAuthorized = false
                        return
                    }
                    
                    if granted {
                        self.isAuthorized = true
                        await self.setupDiligenceList()
                        print("📝 Reminders access granted")
                    } else {
                        self.isAuthorized = false
                        self.syncStatus = .error("Reminders access denied. Please grant access in System Preferences > Security & Privacy > Privacy > Calendars.")
                        print("📝 Reminders access denied by user")
                    }
                }
            }
        }
    }
    
    // MARK: - Diligence List Management
    
    private func isDiligenceCalendar(_ calendar: EKCalendar) -> Bool {
        let hasCorrectPrefix = calendar.title.hasPrefix(diligenceListPrefix)
        let isTrackedDefault = calendar.calendarIdentifier == defaultCalendarID
        let isTrackedSection = diligenceCalendarIDs.values.contains(calendar.calendarIdentifier)
        return hasCorrectPrefix || isTrackedDefault || isTrackedSection
    }
    
    private func getDiligenceCalendars() -> [EKCalendar] {
        let all = eventStore.calendars(for: .reminder)
        return all.filter { isDiligenceCalendar($0) }
    }
    
    private func shouldManageCalendar(_ calendar: EKCalendar) -> Bool {
        return isDiligenceCalendar(calendar)
    }
    
    // MARK: - Diligence List Setup
    
    private func setupDiligenceList() async {
        guard isAuthorized else {
            print("📝 Cannot setup Diligence lists - not authorized")
            return
        }
        
        print("📝 Setting up Diligence default list...")
        await setupDefaultList()
        restoreSectionLists()
    }
    
    private func setupDefaultList() async {
        if let savedCalendarID = UserDefaults.standard.string(forKey: diligenceCalendarIDKey) {
            print("📝 Looking for existing default calendar with saved ID: \(savedCalendarID)")
            
            // Defensive check: Verify the calendar still exists
            if let existingCalendar = eventStore.calendar(withIdentifier: savedCalendarID) {
                if isDiligenceCalendar(existingCalendar) {
                    defaultCalendarID = existingCalendar.calendarIdentifier
                    print("📝 Successfully restored default Diligence list from saved ID")
                    return
                } else {
                    print("📝 ⚠️ Saved calendar ID points to non-Diligence calendar, clearing...")
                    UserDefaults.standard.removeObject(forKey: diligenceCalendarIDKey)
                }
            } else {
                print("📝 ⚠️ Saved default calendar ID \(savedCalendarID) no longer exists - removing stale reference")
                UserDefaults.standard.removeObject(forKey: diligenceCalendarIDKey)
            }
        }
        
        // Check by name among Diligence calendars
        let dCalendars = getDiligenceCalendars()
        if let existingCalendar = dCalendars.first(where: { $0.title == defaultListName }) {
            defaultCalendarID = existingCalendar.calendarIdentifier
            UserDefaults.standard.set(existingCalendar.calendarIdentifier, forKey: diligenceCalendarIDKey)
            print("📝 Found existing default Diligence list by name and saved ID: \(existingCalendar.calendarIdentifier)")
            return
        }
        
        // Create
        print("📝 Creating new default Diligence list...")
        let newCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
        newCalendar.title = defaultListName
        newCalendar.cgColor = NSColor.systemBlue.cgColor
        
        if let defaultSource = eventStore.defaultCalendarForNewReminders()?.source {
            newCalendar.source = defaultSource
            print("📝 Using default source for new calendar")
        } else if let firstSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = firstSource
            print("📝 Using local source for new calendar")
        } else {
            print("📝 Error: No suitable source found for creating reminders list")
            syncStatus = .error("No suitable source found for creating reminders list")
            return
        }
        
        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            defaultCalendarID = newCalendar.calendarIdentifier
            UserDefaults.standard.set(newCalendar.calendarIdentifier, forKey: diligenceCalendarIDKey)
            print("📝 Successfully created new default Diligence list with ID: \(newCalendar.calendarIdentifier)")
        } catch {
            print("📝 Error creating default Diligence list: \(error)")
            syncStatus = .error("Failed to create default Diligence list: \(error.localizedDescription)")
        }
    }
    
    private func restoreSectionLists() {
        guard let sectionCalendarData = UserDefaults.standard.data(forKey: sectionCalendarIDsKey),
              let sectionCalendarIDs = try? JSONDecoder().decode([String: String].self, from: sectionCalendarData) else {
            print("📝 No section calendars to restore")
            return
        }
        
        var validSectionCalendarIDs: [String: String] = [:]
        
        for (sectionID, calendarID) in sectionCalendarIDs {
            // Defensive check: Verify calendar exists before accessing
            if eventStore.calendar(withIdentifier: calendarID) != nil {
                diligenceCalendarIDs[sectionID] = calendarID
                validSectionCalendarIDs[sectionID] = calendarID
                print("📝 Restored section calendar ID for section: \(sectionID)")
            } else {
                print("📝 ⚠️ Section calendar with ID \(calendarID) for section \(sectionID) no longer exists - will be removed from cache")
            }
        }
        
        // Update UserDefaults to remove stale calendar references
        if validSectionCalendarIDs.count != sectionCalendarIDs.count {
            print("📝 Cleaning up \(sectionCalendarIDs.count - validSectionCalendarIDs.count) stale calendar reference(s)")
            if let cleanedData = try? JSONEncoder().encode(validSectionCalendarIDs) {
                UserDefaults.standard.set(cleanedData, forKey: sectionCalendarIDsKey)
            }
        }
    }
    
    private func saveSectionCalendars() {
        // Already storing IDs, just need to encode them
        if let data = try? JSONEncoder().encode(diligenceCalendarIDs) {
            UserDefaults.standard.set(data, forKey: sectionCalendarIDsKey)
        }
    }
    
    private func getOrCreateSectionCalendar(for section: SectionSyncData) throws -> EKCalendar {
        // Check if we have a cached calendar ID for this section
        if let calendarID = diligenceCalendarIDs[section.id],
           let existingCalendar = eventStore.calendar(withIdentifier: calendarID) {
            let dCalendars = getDiligenceCalendars()
            // Defensive check: Verify the calendar still exists
            if dCalendars.contains(where: { $0.calendarIdentifier == existingCalendar.calendarIdentifier }) {
                return existingCalendar
            } else {
                print("📝 ⚠️ Cached section calendar for '\(section.title)' no longer exists - will recreate")
                diligenceCalendarIDs.removeValue(forKey: section.id)
            }
        }
        
        let sectionListName = "\(diligenceListPrefix)\(section.title)"
        let existingD = getDiligenceCalendars()
        if let existing = existingD.first(where: { $0.title == sectionListName }) {
            diligenceCalendarIDs[section.id] = existing.calendarIdentifier
            saveSectionCalendars()
            print("📝 Found existing section calendar: \(sectionListName)")
            return existing
        }
        
        print("📝 Creating new section calendar: \(sectionListName)")
        let newCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
        newCalendar.title = sectionListName
        
        if let colorHex = section.color, let color = NSColor(hex: colorHex) {
            newCalendar.cgColor = color.cgColor
        } else {
            newCalendar.cgColor = NSColor.systemBlue.cgColor
        }
        
        if let defaultSource = eventStore.defaultCalendarForNewReminders()?.source {
            newCalendar.source = defaultSource
        } else if let firstSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = firstSource
        } else {
            throw NSError(domain: "RemindersService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No suitable source found for creating reminders list"])
        }
        
        try eventStore.saveCalendar(newCalendar, commit: true)
        diligenceCalendarIDs[section.id] = newCalendar.calendarIdentifier
        saveSectionCalendars()
        print("📝 Successfully created section calendar: \(sectionListName)")
        
        return newCalendar
    }
    
    // MARK: - Calendar Reference Validation
    
    /// Validates and cleans up any stale calendar references that no longer exist in the system
    private func validateAndCleanupCalendarReferences() async {
        print("📝 Validating calendar references...")
        
        let allCalendars = eventStore.calendars(for: .reminder)
        let existingCalendarIDs = Set(allCalendars.map { $0.calendarIdentifier })
        
        // Validate default calendar
        if let defaultCalID = defaultCalendarID,
           !existingCalendarIDs.contains(defaultCalID) {
            print("📝 ⚠️ Default calendar no longer exists - clearing reference")
            defaultCalendarID = nil
            UserDefaults.standard.removeObject(forKey: diligenceCalendarIDKey)
        }
        
        // Validate section calendars
        var staleCalendarCount = 0
        for (sectionID, calendarID) in diligenceCalendarIDs {
            if !existingCalendarIDs.contains(calendarID) {
                print("📝 ⚠️ Section calendar for section '\(sectionID)' no longer exists - removing reference")
                diligenceCalendarIDs.removeValue(forKey: sectionID)
                staleCalendarCount += 1
            }
        }
        
        if staleCalendarCount > 0 {
            print("📝 Cleaned up \(staleCalendarCount) stale section calendar reference(s)")
            saveSectionCalendars()
        }
        
        print("📝 Calendar validation complete")
    }
    
    // MARK: - Sync Management
    
    private func startPeriodicSync() {
        print("📝 Periodic sync monitoring started - sync will be triggered by data changes")
    }
    
    func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Task Syncing
    
    nonisolated func syncTasksAndSections(taskData: [TaskSyncData], sectionData: [SectionSyncData]) async {
        await MainActor.run {
            guard self.isAuthorized else {
                print("📝 Cannot sync - not authorized for Reminders access")
                self.syncStatus = .error("Not authorized for Reminders access")
                return
            }
            guard self.syncStatus != .syncing else {
                print("📝 Sync already in progress, skipping...")
                return
            }
            if self.defaultCalendarID == nil {
                print("📝 Cannot sync - no default calendar available, trying to setup...")
                _Concurrency.Task { @MainActor in
                    await self.setupDefaultList()
                    guard self.defaultCalendarID != nil else {
                        self.syncStatus = .error("No default calendar available for sync")
                        return
                    }
                    // Retry sync after setup
                    await self.performSyncWithXPCRetry(taskData: taskData, sectionData: sectionData)
                }
                return
            }
            
            self.syncStatus = .syncing
        }
        
        // Perform the actual sync with XPC retry logic
        await performSyncWithXPCRetry(taskData: taskData, sectionData: sectionData)
    }
    
    private func performSyncWithXPCRetry(taskData: [TaskSyncData], sectionData: [SectionSyncData]) async {
        do {
            try await executeWithXPCRetry {
                await self.performActualSync(taskData: taskData, sectionData: sectionData)
            }
            
            await MainActor.run {
                self.syncStatus = .success
                self.connectionRetryCount = 0 // Reset on successful sync
                print("📝 ✅ Sync completed successfully")
            }
        } catch {
            await MainActor.run {
                print("📝 ❌ Sync failed after retries: \(error)")
                self.syncStatus = .error("Sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func performActualSync(taskData: [TaskSyncData], sectionData: [SectionSyncData]) async {
        print("📝 Starting sync with \(sectionData.count) sections and \(taskData.count) tasks...")
        
        // Defensive validation: Clean up any stale calendar references before syncing
        await validateAndCleanupCalendarReferences()
        
        do {
            var sectionCalendars: [String: EKCalendar] = [:]
            let sortedSections = sectionData.sorted(by: { $0.sortOrder < $1.sortOrder })
            try? await _Concurrency.Task.sleep(nanoseconds: 100_000_000)
            
            // Prepare/create all section calendars (no deferred commit API exists, each save/remove must decide commit)
            for section in sortedSections {
                do {
                    let calendar = try getOrCreateSectionCalendar(for: section)
                    sectionCalendars[section.id] = calendar
                    
                    // Update calendar properties if needed
                    let expectedTitle = "Diligence - \(section.title)"
                    var needsSave = false
                    if calendar.title != expectedTitle {
                        calendar.title = expectedTitle
                        needsSave = true
                    }
                    if let colorHex = section.color, let color = NSColor(hex: colorHex) {
                        if calendar.cgColor != color.cgColor {
                            calendar.cgColor = color.cgColor
                            needsSave = true
                        }
                    }
                    if needsSave {
                        try eventStore.saveCalendar(calendar, commit: true)
                    }
                    print("📝 Prepared section calendar: \(calendar.title) for section: \(section.id)")
                } catch {
                    print("📝 Error processing section \(section.title): \(error)")
                }
            }
            
            // Remove calendars for deleted sections
            let currentSectionIDs = Set(sectionData.map { $0.id })
            let calendarsToRemove = diligenceCalendarIDs.filter { !currentSectionIDs.contains($0.key) }
            for (sectionID, calendarID) in calendarsToRemove {
                if let calendar = eventStore.calendar(withIdentifier: calendarID) {
                    print("📝 Removing calendar for deleted section: \(calendar.title)")
                    do {
                        try eventStore.removeCalendar(calendar, commit: true)
                        diligenceCalendarIDs.removeValue(forKey: sectionID)
                    } catch {
                        print("📝 Error removing calendar for section \(sectionID): \(error)")
                    }
                }
                saveSectionCalendars()
            }
            
            try? await _Concurrency.Task.sleep(nanoseconds: 200_000_000)
            
            // Cleanup orphaned reminders first
            try? await cleanupOrphanedReminders(taskData: taskData, sectionCalendars: sectionCalendars)
            
            // Process tasks
            for task in taskData {
                do {
                    let targetCalendar: EKCalendar
                    if let sectionID = task.sectionID, let sectionCalendar = sectionCalendars[sectionID] {
                        targetCalendar = sectionCalendar
                        print("📝 Task '\(task.title)' assigned to section calendar: \(sectionCalendar.title)")
                    } else if let defaultCal = self.defaultCalendar {
                        targetCalendar = defaultCal
                        print("📝 Task '\(task.title)' assigned to default calendar: \(defaultCal.title)")
                    } else {
                        print("📝 Error: No default calendar available for task '\(task.title)'")
                        continue
                    }
                    
                    if task.reminderID != nil {
                        let moved = try await moveTaskBetweenCalendarsIfNeeded(task: task, targetCalendar: targetCalendar, sectionCalendars: sectionCalendars)
                        if moved {
                            print("📝 Task '\(task.title)' was moved to \(targetCalendar.title)")
                        }
                    }
                    
                    try await syncSingleTaskToCalendar(task: task, calendar: targetCalendar)
                } catch {
                    print("📝 Error syncing task '\(task.title)': \(error)")
                }
            }
            
            // Notify section IDs
            for section in sortedSections {
                if let calendar = sectionCalendars[section.id] {
                    NotificationCenter.default.post(
                        name: Notification.Name("UpdateSectionReminderID"),
                        object: nil,
                        userInfo: [
                            "sectionID": section.id,
                            "reminderID": calendar.calendarIdentifier
                        ]
                    )
                }
            }
            
            self.syncStatus = .success
            self.lastSyncDate = Date()
            self.sections = sectionData
            print("📝 Successfully synced \(sectionData.count) sections and \(taskData.count) tasks with Reminders")
            
        } catch {
            let errorMessage = error.localizedDescription
            print("📝 Sync error: \(error)")
            print("📝 Error details: \(errorMessage)")
            
            // Handle specific connection/interruption errors
            if errorMessage.lowercased().contains("interrupted") || errorMessage.lowercased().contains("connection") {
                self.syncStatus = .error("System service interrupted - please try again")
                _Concurrency.Task { @MainActor in
                    try? await _Concurrency.Task.sleep(nanoseconds: 2_000_000_000)
                    self.checkAuthorizationStatus()
                }
            } else if errorMessage.contains("Missing entitlement") || errorMessage.contains("com.apple.application-identifier") {
                self.syncStatus = .error("Missing entitlements: Add 'Calendars' capability in Xcode project settings")
            } else if errorMessage.lowercased().contains("reminderkit") || errorMessage.lowercased().contains("replica manager") {
                self.syncStatus = .error("Entitlements configuration error: Ensure app has proper calendar access")
            } else if errorMessage.lowercased().contains("sandbox restriction") {
                self.syncStatus = .error("Sandbox restriction: Enable calendars entitlement in project capabilities")
            } else {
                self.syncStatus = .error("Sync failed: \(errorMessage)")
            }
        }
    }
    
    private func moveTaskBetweenCalendarsIfNeeded(
        task: TaskSyncData,
        targetCalendar: EKCalendar,
        sectionCalendars: [String: EKCalendar]
    ) async throws -> Bool {
        guard let reminderID = task.reminderID else {
            return false
        }
        
        var allCalendars = Array(sectionCalendars.values)
        if let defaultCal = self.defaultCalendar {
            allCalendars.append(defaultCal)
        }
        
        // Defensive check: Filter out any calendars that no longer exist
        let existingCalendarIDs = Set(eventStore.calendars(for: .reminder).map { $0.calendarIdentifier })
        let validCalendars = allCalendars.filter { existingCalendarIDs.contains($0.calendarIdentifier) }
        
        if validCalendars.count < allCalendars.count {
            print("📝 ⚠️ Filtered out \(allCalendars.count - validCalendars.count) stale calendar reference(s)")
        }
        
        var seenIdentifiers = Set<String>()
        let uniqueCalendars = validCalendars.compactMap { cal -> EKCalendar? in
            if seenIdentifiers.insert(cal.calendarIdentifier).inserted {
                return cal
            }
            return nil
        }
        
        var existingReminder: EKReminder?
        var currentCalendar: EKCalendar?
        
        for calendar in uniqueCalendars {
            let reminders = try await getExistingReminders(from: calendar)
            if let reminder = reminders.first(where: { $0.calendarItemIdentifier == reminderID }) {
                existingReminder = reminder
                currentCalendar = calendar
                break
            }
        }
        
        guard let reminder = existingReminder,
              let currentCal = currentCalendar else {
            print("📝 ⚠️ Could not find existing reminder with ID \(reminderID) - it may have been deleted")
            return false
        }
        
        if currentCal.calendarIdentifier == targetCalendar.calendarIdentifier {
            print("📝 Task '\(task.title)' is already in correct calendar: \(targetCalendar.title)")
            return false
        }
        
        print("📝 Moving task '\(task.title)' from \(currentCal.title) to \(targetCalendar.title)")
        reminder.calendar = targetCalendar
        try eventStore.save(reminder, commit: true)
        
        return true
    }
    
    private func syncSingleTaskToCalendar(task: TaskSyncData, calendar: EKCalendar) async throws {
        print("📝 DEBUG: Syncing task '\(task.title)' to calendar '\(calendar.title)'")
        print("📝 DEBUG: Task sectionID: \(task.sectionID ?? "nil"), reminderID: \(task.reminderID ?? "nil")")
        
        let existingReminders = try await getExistingReminders(from: calendar)
        print("📝 DEBUG: Found \(existingReminders.count) existing reminders in '\(calendar.title)'")
        
        var existingTasksByTitle: [String: EKReminder] = [:]
        for reminder in existingReminders {
            if let title = reminder.title, !title.isEmpty, existingTasksByTitle[title] == nil {
                existingTasksByTitle[title] = reminder
            }
        }
        
        let reminder: EKReminder
        var isNewReminder = false
        var newReminderID: String?
        
        if let reminderID = task.reminderID,
           let existingReminder = existingReminders.first(where: { $0.calendarItemIdentifier == reminderID }) {
            reminder = existingReminder
            print("📝 Found existing reminder by ID in target calendar: \(task.title)")
        } else if let existingReminder = existingTasksByTitle[task.title] {
            reminder = existingReminder
            newReminderID = reminder.calendarItemIdentifier
            print("📝 Found existing reminder by title in target calendar: \(task.title)")
        } else {
            reminder = EKReminder(eventStore: eventStore)
            reminder.calendar = calendar
            isNewReminder = true
            print("📝 DEBUG: Creating NEW reminder '\(task.title)' in calendar '\(calendar.title)'")
        }
        
        print("📝 DEBUG: About to update reminder properties...")
        print("📝 DEBUG: Reminder calendar: \(reminder.calendar?.title ?? "nil")")
        print("📝 DEBUG: Target calendar: \(calendar.title)")
        
        reminder.title = task.title
        reminder.notes = task.description.isEmpty ? nil : task.description
        reminder.isCompleted = task.isCompleted
        
        if let dueDate = task.dueDate {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
            
            // Note: We don't set alarms here to avoid sandbox/URL-related errors
            // The Reminders app will handle alarm notifications based on the due date
            // Remove any existing alarms to keep it clean
            if let alarms = reminder.alarms, !alarms.isEmpty {
                for alarm in alarms {
                    reminder.removeAlarm(alarm)
                }
            }
        } else {
            reminder.dueDateComponents = nil
            // Remove alarms if no due date
            if let alarms = reminder.alarms, !alarms.isEmpty {
                for alarm in alarms {
                    reminder.removeAlarm(alarm)
                }
            }
        }
        
        // Metadata
        if task.isFromEmail {
            let tagLine = "\n\n--- Created from Email ---"
            let emailNote = "\(tagLine)\nFrom: \(task.emailSender ?? "Unknown")\nSubject: \(task.emailSubject ?? "No subject")"
            if let currentNotes = reminder.notes, !currentNotes.contains(tagLine) {
                reminder.notes = currentNotes + emailNote
            } else if reminder.notes == nil {
                reminder.notes = (task.description.isEmpty ? nil : task.description).map { $0 + emailNote } ?? emailNote
            }
        }
        
        try eventStore.save(reminder, commit: true)
        print("📝 DEBUG: Successfully saved reminder '\(task.title)' to eventStore (commit: true)")
        print("📝 DEBUG: Final reminder calendar: \(reminder.calendar?.title ?? "nil")")
        print("📝 DEBUG: Final reminder ID: \(reminder.calendarItemIdentifier)")
        
        if isNewReminder || newReminderID != nil {
            let reminderIDToStore = reminder.calendarItemIdentifier
            NotificationCenter.default.post(
                name: Notification.Name("UpdateTaskReminderID"),
                object: nil,
                userInfo: [
                    "taskID": task.id,
                    "reminderID": reminderIDToStore
                ]
            )
        }
    }
    
    private func cleanupOrphanedReminders(
        taskData: [TaskSyncData],
        sectionCalendars: [String: EKCalendar]
    ) async throws {
        var allCalendars = Array(sectionCalendars.values)
        if let defaultCal = self.defaultCalendar {
            allCalendars.append(defaultCal)
        }
        
        // Defensive check: Filter out any calendars that no longer exist
        let existingCalendarIDs = Set(eventStore.calendars(for: .reminder).map { $0.calendarIdentifier })
        let validCalendars = allCalendars.filter { existingCalendarIDs.contains($0.calendarIdentifier) }
        
        if validCalendars.count < allCalendars.count {
            print("📝 ⚠️ Skipping \(allCalendars.count - validCalendars.count) non-existent calendar(s) during cleanup")
        }
        
        var seenIdentifiers = Set<String>()
        let uniqueCalendars = validCalendars.compactMap { calendar -> EKCalendar? in
            if seenIdentifiers.insert(calendar.calendarIdentifier).inserted {
                return calendar
            }
            return nil
        }
        
        var tasksByReminderID: [String: TaskSyncData] = [:]
        for task in taskData {
            if let reminderID = task.reminderID {
                tasksByReminderID[reminderID] = task
            }
        }
        
        for calendar in uniqueCalendars {
            do {
                let existingReminders = try await getExistingReminders(from: calendar)
                for reminder in existingReminders {
                    let reminderID = reminder.calendarItemIdentifier
                    if tasksByReminderID[reminderID] == nil {
                        print("📝 Removing orphaned reminder: \(reminder.title ?? "Untitled") from \(calendar.title)")
                        do {
                            try eventStore.remove(reminder, commit: true)
                        } catch {
                            print("📝 ⚠️ Failed to remove orphaned reminder '\(reminder.title ?? "Untitled")': \(error.localizedDescription)")
                            // Continue with other reminders even if one fails
                        }
                    }
                }
            } catch {
                print("📝 ⚠️ Error checking calendar '\(calendar.title)' for orphaned reminders: \(error.localizedDescription)")
                // Continue with other calendars even if one fails
            }
        }
    }
    
    private func getExistingReminders(from calendar: EKCalendar) async throws -> [EKReminder] {
        // Defensive check: Verify calendar still exists before fetching
        let allCalendars = eventStore.calendars(for: .reminder)
        guard allCalendars.contains(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) else {
            print("📝 ⚠️ Calendar '\(calendar.title)' (ID: \(calendar.calendarIdentifier)) no longer exists - skipping fetch")
            return []
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            let predicate = eventStore.predicateForReminders(in: [calendar])
            
            // Timeout guard
            let timeout = DispatchWorkItem {
                continuation.resume(throwing: NSError(
                    domain: "RemindersService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Reminder fetch timed out"]
                ))
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeout)
            
            eventStore.fetchReminders(matching: predicate) { reminders in
                timeout.cancel()
                if let reminders {
                    continuation.resume(returning: reminders)
                } else {
                    print("📝 Warning: No reminders returned for calendar \(calendar.title)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
        
        // MARK: - Connection Recovery
        
        private func handleConnectionInterruption() async {
            print("📝 Handling connection interruption - resetting EventStore...")
            isAuthorized = false
            syncStatus = .idle
            try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000)
            checkAuthorizationStatus()
        }
        
        func retryLastSync() {
            guard syncStatus != .syncing else {
                print("📝 Sync already in progress")
                return
            }
            print("📝 Retrying sync after connection interruption...")
            syncStatus = .idle
        }
        
        // MARK: - Cleanup and Maintenance
        
        nonisolated func cleanupLeakedReminders() async {
            // Check auth on MainActor
            let isAuth = await MainActor.run { self.isAuthorized }
            guard isAuth else {
                print("📝 Cannot cleanup - not authorized for Reminders access")
                return
            }
            
            print("📝 Starting cleanup of reminders in non-Diligence calendars...")
            
            // Capture store and compute calendar subsets safely
            let store: EKEventStore = await MainActor.run { self.eventStore }
            let allCalendars = store.calendars(for: .reminder)
            // isDiligenceCalendar is @MainActor (since the class is), so hop to MainActor to use it
            let nonDiligenceCalendars: [EKCalendar] = await MainActor.run {
                allCalendars.filter { !self.isDiligenceCalendar($0) }
            }
            
            var remindersMoved = 0
            var remindersFound = 0
            
            for calendar in nonDiligenceCalendars {
                do {
                    let reminders = try await getExistingReminders(from: calendar)
                    let possibleDiligenceReminders = reminders.filter { reminder in
                        guard let notes = reminder.notes else { return false }
                        return notes.contains("--- Created from Email ---") ||
                        notes.contains("Diligence") ||
                        (reminder.title?.contains("[Diligence]") == true)
                    }
                    
                    if !possibleDiligenceReminders.isEmpty {
                        remindersFound += possibleDiligenceReminders.count
                        print("📝 Found \(possibleDiligenceReminders.count) possible Diligence reminders in '\(calendar.title)'")
                        
                        // Get default calendar on MainActor
                        let defaultCal: EKCalendar? = await MainActor.run { self.defaultCalendar }
                        
                        if let defaultCal {
                            // Move each reminder on MainActor (mutating EKReminder + saving)
                            var remindersMovedInCalendar = 0
                            for reminder in possibleDiligenceReminders {
                                let moved = await MainActor.run { () -> Bool in
                                    print("📝 Moving reminder '\(reminder.title ?? "Untitled")' to Diligence default calendar")
                                    reminder.calendar = defaultCal
                                    do {
                                        try store.save(reminder, commit: true)
                                        return true
                                    } catch {
                                        print("📝 Error moving reminder: \(error)")
                                        return false
                                    }
                                }
                                if moved { remindersMovedInCalendar += 1 }
                            }
                            remindersMoved += remindersMovedInCalendar
                        }
                    }
                } catch {
                    print("📝 Error checking calendar '\(calendar.title)': \(error)")
                }
            }
            
            if remindersMoved > 0 {
                print("📝 ✅ Successfully moved \(remindersMoved) reminders to Diligence calendars")
            } else if remindersFound == 0 {
                print("📝 ✅ No leaked Diligence reminders found in user calendars")
            } else {
                print("📝 ℹ️  Found \(remindersFound) possible Diligence reminders but couldn't move them")
            }
        }
        
        nonisolated func getDiligenceCalendarSummary() async -> [String: Int] {
            let isAuth = await MainActor.run { self.isAuthorized }
            guard isAuth else { return [:] }
            
            var summary: [String: Int] = [:]
            let diligenceCalendars = await MainActor.run { self.getDiligenceCalendars() }
            
            for calendar in diligenceCalendars {
                do {
                    let reminders = try await getExistingReminders(from: calendar)
                    summary[calendar.title] = reminders.count
                } catch {
                    summary[calendar.title] = -1
                }
            }
            
            return summary
        }
        
        // MARK: - Debug Methods
        
        func debugListAllCalendars() {
            guard isAuthorized else {
                print("📝 DEBUG: Not authorized for Reminders access")
                return
            }
            
            let allCalendars = eventStore.calendars(for: .reminder)
            let diligenceCalendars = getDiligenceCalendars()
            
            print("📝 DEBUG: === ALL REMINDER CALENDARS ===")
            print("📝 Total calendars found: \(allCalendars.count)")
            print("📝 Diligence-managed calendars: \(diligenceCalendars.count)")
            print("")
            
            for calendar in allCalendars {
                let isDiligence = isDiligenceCalendar(calendar)
                let icon = isDiligence ? "✅" : "❌"
                let source = calendar.source?.title ?? "Unknown"
                print("📝 \(icon) '\(calendar.title)' (ID: \(calendar.calendarIdentifier.prefix(8))...) [Source: \(source)]")
                
                if isDiligence {
                    print("📝      → Managed by Diligence")
                } else {
                    print("📝      → User's personal calendar (not managed)")
                }
            }
            
            print("📝 DEBUG: === END CALENDAR LIST ===")
        }
        
        nonisolated func debugVerifyDiligenceOnlySync() async {
            let isAuth = await MainActor.run { self.isAuthorized }
            guard isAuth else {
                print("📝 DEBUG: Not authorized for Reminders access")
                return
            }
            
            print("📝 DEBUG: === DILIGENCE SYNC VERIFICATION ===")
            
            let diligenceCalendars = await MainActor.run { self.getDiligenceCalendars() }
            print("📝 Checking \(diligenceCalendars.count) Diligence calendars for our reminders...")
            
            for calendar in diligenceCalendars {
                do {
                    let reminders = try await getExistingReminders(from: calendar)
                    print("📝 ✅ '\(calendar.title)': \(reminders.count) reminders")
                    
                    let diligenceReminders = reminders.filter { reminder in
                        guard let notes = reminder.notes else { return false }
                        return notes.contains("--- Created from Email ---") ||
                        notes.contains("Diligence") ||
                        (reminder.title?.contains("[Diligence]") == true)
                    }
                    if !diligenceReminders.isEmpty {
                        print("📝      → \(diligenceReminders.count) appear to be Diligence-created")
                    }
                } catch {
                    print("📝 ❌ Error checking '\(calendar.title)': \(error)")
                }
            }
            
            let eventStore = await MainActor.run { self.eventStore }
            let allCalendars = eventStore.calendars(for: .reminder)
            let nonDiligenceCalendars: [EKCalendar] = await MainActor.run {
                allCalendars.filter { !self.isDiligenceCalendar($0) }
            }
            
            if !nonDiligenceCalendars.isEmpty {
                print("📝 Checking \(nonDiligenceCalendars.count) user calendars for any leaked reminders...")
                for calendar in nonDiligenceCalendars {
                    do {
                        let reminders = try await getExistingReminders(from: calendar)
                        if !reminders.isEmpty {
                            print("📝 ℹ️  User calendar '\(calendar.title)': \(reminders.count) reminders (not managed by Diligence)")
                        }
                    } catch {
                        print("📝 ⚠️  Could not check user calendar '\(calendar.title)': \(error)")
                    }
                }
            }
            
            print("📝 DEBUG: === END VERIFICATION ===")
        }
        
        nonisolated func debugListRemindersInCalendar(calendarTitle: String) async {
            let isAuth = await MainActor.run { self.isAuthorized }
            guard isAuth else {
                print("📝 DEBUG: Not authorized for Reminders access")
                return
            }
            
            let eventStore = await MainActor.run { self.eventStore }
            let allCalendars = eventStore.calendars(for: .reminder)
            guard let calendar = allCalendars.first(where: { $0.title == calendarTitle }) else {
                print("📝 DEBUG: Calendar '\(calendarTitle)' not found")
                print("📝 DEBUG: Available calendars: \(allCalendars.map { $0.title })")
                return
            }
            
            do {
                let reminders = try await getExistingReminders(from: calendar)
                print("📝 DEBUG: Calendar '\(calendarTitle)' contains \(reminders.count) reminders:")
                for (index, reminder) in reminders.enumerated() {
                    print("📝 DEBUG:   \(index + 1). '\(reminder.title ?? "Untitled")' (completed: \(reminder.isCompleted))")
                }
            } catch {
                print("📝 DEBUG: Error fetching reminders from '\(calendarTitle)': \(error)")
            }
        }
        
        // MARK: - Manual Sync
        
        func forceSyncNow(taskData: [TaskSyncData], sectionData: [SectionSyncData] = []) {
            print("📝 === FORCE SYNC NOW CALLED ===")
            print("📝 Task data count: \(taskData.count)")
            print("📝 Section data count: \(sectionData.count)")
            print("📝 Is authorized: \(isAuthorized)")
            print("📝 Current sync status: \(syncStatus)")
            
            guard isAuthorized else {
                print("📝 ❌ Cannot sync - not authorized for Reminders access")
                syncStatus = .error("Not authorized for Reminders access. Please grant access in System Settings.")
                return
            }
            
            if taskData.isEmpty && sectionData.isEmpty {
                print("📝 ⚠️ Sync called with no data - will still attempt to verify setup")
            }
            
            print("📝 Starting manual sync with \(sectionData.count) sections and \(taskData.count) tasks")
            _Concurrency.Task { [weak self] in
                await self?.syncTasksAndSections(taskData: taskData, sectionData: sectionData)
            }
        }
        
        func testSync() {
            print("📝 === RUNNING TEST SYNC ===")
            
            guard isAuthorized else {
                print("📝 ❌ Test sync failed - not authorized")
                syncStatus = .error("Not authorized for Reminders access")
                return
            }
            
            _Concurrency.Task {
                do {
                    try await executeWithXPCRetry {
                        self.syncStatus = .syncing
                        
                        // If your project has a real RecurrencePattern, replace .never with the real case.
                        let testTask = TaskSyncData(
                            id: "test-\(UUID().uuidString)",
                            title: "Test Sync - \(Date().formatted())",
                            description: "This is a test task created to verify Reminders sync is working properly.",
                            isCompleted: false,
                            dueDate: Date().addingTimeInterval(3600),
                            reminderID: nil,
                            isFromEmail: false,
                            emailSender: nil,
                            emailSubject: nil,
                            sectionID: nil,
                            recurrencePattern: .never,
                            recurrenceDescription: "",
                            isRecurringInstance: false
                        )
                        
                        await self.syncTasksAndSections(taskData: [testTask], sectionData: [])
                    }
                    print("📝 ✅ Test sync completed successfully")
                } catch {
                    await MainActor.run {
                        print("📝 ❌ Test sync failed: \(error)")
                        self.syncStatus = .error("Test sync failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        nonisolated func syncTasks(taskData: [TaskSyncData]) async {
            await syncTasksAndSections(taskData: taskData, sectionData: [])
        }
        
        // MARK: - Section Management
        
        func getSections() -> [SectionSyncData] {
            return sections.sorted(by: { $0.sortOrder < $1.sortOrder })
        }
        
        func createSection(title: String, sortOrder: Int) -> SectionSyncData {
            return SectionSyncData(
                id: UUID().uuidString,
                title: title,
                color: nil,
                sortOrder: sortOrder,
                reminderID: nil
            )
        }
        
        // MARK: - Status Methods
        
        func getSyncStatusText() -> String {
            switch syncStatus {
            case .idle:
                if let lastSync = lastSyncDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .none
                    formatter.timeStyle = .short
                    return "Last sync: \(formatter.string(from: lastSync))"
                } else {
                    return isAuthorized ? "Ready to sync" : "Reminders access needed"
                }
            case .syncing:
                return "Syncing with Reminders..."
            case .success:
                return "Sync complete"
            case .reconnecting:
                return "Reconnecting to Reminders..."
            case .error(let message):
                let lower = message.lowercased()
                if lower.contains("interrupted") || lower.contains("connection") {
                    return "Connection interrupted - tap to retry"
                } else if lower.contains("sandbox restriction") || lower.contains("4099") {
                    return "Config needed: Enable Calendars in Xcode entitlements"
                } else if lower.contains("missing entitlement") || lower.contains("com.apple.application-identifier") {
                    return "Missing entitlements: Add Calendars capability in Xcode"
                } else if lower.contains("reminderkit") || lower.contains("replica manager") {
                    return "Entitlements error: Check app sandbox and calendars permissions"
                } else {
                    return "Error: \(message)"
                }
            }
        }
        
        func getDiligenceListExists() -> Bool {
            return defaultCalendarID != nil || !diligenceCalendarIDs.isEmpty
        }
        
        nonisolated func enableStrictDiligenceMode() async {
            print("📝 Enabling strict Diligence-only sync mode...")
            await MainActor.run {
                self.debugListAllCalendars()
            }
            await debugVerifyDiligenceOnlySync()
            await cleanupLeakedReminders()
            
            let summary = await getDiligenceCalendarSummary()
            print("📝 Diligence Calendar Summary:")
            for (calendarName, reminderCount) in summary {
                if reminderCount >= 0 {
                    print("📝   • \(calendarName): \(reminderCount) reminders")
                } else {
                    print("📝   • \(calendarName): Error reading reminders")
                }
            }
            
            let prefix = await MainActor.run { self.diligenceListPrefix }
            print("📝 ✅ Strict Diligence-only mode enabled")
            print("📝    Only calendars with names starting with '\(prefix)' will be managed")
        }
        
        func resetDiligenceList() {
            print("📝 Resetting all Diligence calendars...")
            UserDefaults.standard.removeObject(forKey: diligenceCalendarIDKey)
            UserDefaults.standard.removeObject(forKey: sectionCalendarIDsKey)
            defaultCalendarID = nil
            diligenceCalendarIDs.removeAll()
            _Concurrency.Task {
                await setupDiligenceList()
            }
        }
        
        func resetAuthorization() {
            print("📝 Resetting Reminders authorization...")
            isAuthorized = false
            syncStatus = .idle
            lastSyncDate = nil
            defaultCalendarID = nil
            diligenceCalendarIDs.removeAll()
            UserDefaults.standard.removeObject(forKey: diligenceCalendarIDKey)
            UserDefaults.standard.removeObject(forKey: sectionCalendarIDsKey)
            checkAuthorizationStatus()
            print("📝 Authorization reset complete")
        }
        
        // MARK: - Debug Helper
        
        nonisolated func debugCurrentState() async {
            print("📝 DEBUG: === CURRENT STATE DEBUG ===")
            await debugListRemindersInCalendar(calendarTitle: "Diligence - AP")
            await debugListRemindersInCalendar(calendarTitle: "Diligence - Tasks")
            print("📝 DEBUG: === END DEBUG ===")
        }
        
        // MARK: - System Settings
        
        func openSystemSettings() {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                NSWorkspace.shared.open(url)
            }
        }
        
        // MARK: - XPC Connection Health Monitoring
        
        /// Proactively checks XPC connection health and attempts recovery if needed
        nonisolated func performConnectionHealthCheck() async {
            await MainActor.run { [weak self] in
                guard let self = self, self.isAuthorized else {
                    print("📝 Health check skipped - not authorized")
                    return
                }
                
                print("📝 Performing proactive XPC connection health check...")
            }
            
            do {
                // Try a simple EventKit operation with timeout
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try? await _Concurrency.Task.sleep(nanoseconds: 5_000_000_000) // 5s timeout
                        throw NSError(domain: "RemindersService", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Health check timeout"])
                    }
                    
                    group.addTask { @MainActor in
                        let calendars = self.eventStore.calendars(for: .reminder)
                        print("📝 Health check passed - \(calendars.count) calendars accessible")
                    }
                    
                    // Wait for either completion or timeout
                    try await group.next()
                    group.cancelAll()
                }
            } catch {
                print("📝 Health check failed: \(error.localizedDescription)")
                _Concurrency.Task { @MainActor [weak self] in
                    let _ = await self?.handleXPCConnectionError(error)
                }
            }
        }
    }
    

