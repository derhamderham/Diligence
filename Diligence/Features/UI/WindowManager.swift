//
//  WindowManager.swift
//  Diligence
//
//  Window sizing and state management for main app window
//

import SwiftUI
import AppKit
import Foundation
import Combine

// MARK: - Window State Manager

class MainWindowStateManager: ObservableObject {
    static let shared = MainWindowStateManager()
    
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let windowFrame = "MainWindowFrame"
        static let isFirstLaunch = "IsFirstLaunch"
    }
    
    private init() {}
    
    // MARK: - Default Window Properties
    
    private struct DefaultWindowSize {
        static let width: CGFloat = 800
        static let height: CGFloat = 600
        static let minWidth: CGFloat = 480
        static let minHeight: CGFloat = 500
        static let maxWidth: CGFloat = 1400
        static let maxHeight: CGFloat = 1000
        static let screenMargin: CGFloat = 100 // Increased margin from screen edges
    }
    
    // Public access to constants for external use
    static let minimumWindowWidth: CGFloat = 480
    
    // MARK: - Screen-Aware Window Sizing
    
    func getInitialWindowFrame() -> NSRect {
        // If this isn't the first launch and we have saved frame, use it
        if !isFirstLaunch(), let savedFrame = restoreWindowFrame() {
            let validatedFrame = validateFrameForCurrentScreens(savedFrame)
            if !validatedFrame.isEmpty {
                return validatedFrame
            }
        }
        
        // Otherwise, create a new appropriately-sized frame
        return createDefaultWindowFrame()
    }
    
    private func createDefaultWindowFrame() -> NSRect {
        // Try to determine the best screen to place the window on
        let targetScreen = findBestScreen()
        
        let screenFrame = targetScreen.visibleFrame
        let screenSize = screenFrame.size
        
        // Calculate appropriate window size that fits on screen with margins
        let margin = DefaultWindowSize.screenMargin
        let maxWidth = screenSize.width - (margin * 2)
        let maxHeight = screenSize.height - (margin * 2)
        
        // Use default size, but constrain to screen bounds and our maximum sizes
        let windowWidth = min(DefaultWindowSize.width, min(maxWidth, DefaultWindowSize.maxWidth))
        let windowHeight = min(DefaultWindowSize.height, min(maxHeight, DefaultWindowSize.maxHeight))
        
        // Ensure minimum sizes are respected
        let finalWidth = max(windowWidth, DefaultWindowSize.minWidth)
        let finalHeight = max(windowHeight, DefaultWindowSize.minHeight)
        
        // Center the window on the target screen
        let x = screenFrame.origin.x + (screenFrame.size.width - finalWidth) / 2
        let y = screenFrame.origin.y + (screenFrame.size.height - finalHeight) / 2
        
        let frame = NSRect(x: x, y: y, width: finalWidth, height: finalHeight)
        
        print("🪟 MainWindow: Created default frame \(frame) on screen \(screenFrame)")
        
        return frame
    }
    
    private func findBestScreen() -> NSScreen {
        // Prefer screen with mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        let screenWithMouse = NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
        
        // Fallback to main screen, then any screen
        return screenWithMouse ?? NSScreen.main ?? NSScreen.screens.first ?? {
            // Ultimate fallback if no screens are detected
            return NSScreen()
        }()
    }
    
    // MARK: - Frame Validation
    
    private func validateFrameForCurrentScreens(_ frame: NSRect) -> NSRect {
        // Check if the saved frame is still valid for current screen setup
        let screens = NSScreen.screens
        
        guard !screens.isEmpty else {
            print("🪟 MainWindow: No screens available for validation")
            return NSRect.zero
        }
        
        // Ensure the frame intersects with at least one screen
        for screen in screens {
            let screenFrame = screen.visibleFrame
            if screenFrame.intersects(frame) {
                // Make sure the frame is mostly on screen
                let intersection = screenFrame.intersection(frame)
                let intersectionArea = intersection.width * intersection.height
                let frameArea = frame.width * frame.height
                
                // If at least 70% of the window would be visible, it's valid
                if intersectionArea >= (frameArea * 0.7) {
                    // Additional check: ensure title bar is accessible
                    let titleBarPoint = NSPoint(x: frame.midX, y: frame.maxY - 25)
                    if screenFrame.contains(titleBarPoint) {
                        // Final validation: ensure the frame isn't too large for the screen
                        let constrainedFrame = NSRect(
                            x: max(frame.origin.x, screenFrame.minX),
                            y: max(frame.origin.y, screenFrame.minY),
                            width: min(frame.width, screenFrame.width),
                            height: min(frame.height, screenFrame.height)
                        )
                        
                        // Only apply constraints if they significantly change the frame
                        if abs(constrainedFrame.width - frame.width) > 50 || 
                           abs(constrainedFrame.height - frame.height) > 50 {
                            print("🪟 MainWindow: Frame constrained to screen bounds")
                            return constrainedFrame
                        }
                        
                        print("🪟 MainWindow: Saved frame is valid for current screens")
                        return frame
                    }
                }
            }
        }
        
        print("🪟 MainWindow: Saved frame is not valid for current screen configuration")
        // Frame is not valid for current screens, return empty rect
        // This will trigger creation of a new default frame
        return NSRect.zero
    }
    
    // MARK: - Frame Persistence
    
    func saveWindowFrame(_ frame: NSRect) {
        let frameData = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        userDefaults.set(frameData, forKey: Keys.windowFrame)
        
        // Mark that we've saved a frame (no longer first launch)
        setFirstLaunchCompleted()
    }
    
    private func restoreWindowFrame() -> NSRect? {
        guard let frameData = userDefaults.dictionary(forKey: Keys.windowFrame) else {
            return nil
        }
        
        guard let x = frameData["x"] as? Double,
              let y = frameData["y"] as? Double,
              let width = frameData["width"] as? Double,
              let height = frameData["height"] as? Double else {
            return nil
        }
        
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    // MARK: - First Launch Detection
    
    private func isFirstLaunch() -> Bool {
        return !userDefaults.bool(forKey: Keys.isFirstLaunch)
    }
    
    private func setFirstLaunchCompleted() {
        userDefaults.set(true, forKey: Keys.isFirstLaunch)
    }
    
    // MARK: - Debug and Management Utilities
    
    func resetWindowState() {
        print("🪟 MainWindow: Resetting all window state")
        userDefaults.removeObject(forKey: Keys.windowFrame)
        userDefaults.removeObject(forKey: Keys.isFirstLaunch)
        userDefaults.synchronize()
    }
    
    func getCurrentScreenInfo() -> String {
        let screens = NSScreen.screens
        var info = "🖥️ Available screens:\n"
        for (index, screen) in screens.enumerated() {
            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            info += "  Screen \(index): \(frame) (visible: \(visibleFrame))\n"
            if screen == NSScreen.main {
                info += "    ^ Main screen\n"
            }
        }
        return info
    }
    
    func debugCurrentWindowState() -> String {
        if let savedFrame = restoreWindowFrame() {
            let validatedFrame = validateFrameForCurrentScreens(savedFrame)
            let isValid = !validatedFrame.isEmpty
            return """
            🪟 Current window state:
            Saved frame: \(savedFrame)
            Is valid: \(isValid)
            First launch: \(isFirstLaunch())
            \(getCurrentScreenInfo())
            """
        } else {
            return """
            🪟 Current window state:
            No saved frame found
            First launch: \(isFirstLaunch())
            \(getCurrentScreenInfo())
            """
        }
    }
    
    // MARK: - Window Configuration
    
    func configureWindow(_ window: NSWindow) {
        let initialFrame = getInitialWindowFrame()
        
        print("🪟 MainWindow: Configuring window with frame \(initialFrame)")
        
        // Set minimum and maximum sizes BEFORE setting frame
        window.minSize = NSSize(width: DefaultWindowSize.minWidth, height: DefaultWindowSize.minHeight)
        window.maxSize = NSSize(width: DefaultWindowSize.maxWidth, height: DefaultWindowSize.maxHeight)
        
        // Set window frame
        window.setFrame(initialFrame, display: true)
        
        // Enable auto-save for frame (this provides additional persistence)
        window.setFrameAutosaveName("DiligenceMainWindow")
        
        // Set up window properties
        window.title = "Diligence"
        window.isRestorable = true
        window.tabbingMode = .preferred
        
        // Ensure window is resizable
        if !window.styleMask.contains(.resizable) {
            window.styleMask.insert(.resizable)
        }
        
        // Set up delegate for frame tracking
        if window.delegate == nil {
            window.delegate = MainWindowDelegate.shared
        }
        
        print("🪟 MainWindow: Configuration complete. Final frame: \(window.frame)")
    }
    
    // MARK: - Public Interface
    
    /// Call this method to manually configure a specific window if the automatic detection fails
    func configureSpecificWindow(_ window: NSWindow) {
        print("🪟 MainWindow: Manually configuring specific window: \(window.title)")
        configureWindow(window)
    }
    
    /// Call this to reconfigure all main app windows (useful after external window creation)
    func reconfigureMainWindows() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let allWindows = NSApplication.shared.windows
            for window in allWindows {
                // Look for main app windows (not settings windows or panels)
                if window.title == "Diligence" || 
                   (window.title.isEmpty && window.canBecomeMain && window.level == .normal) {
                    print("🪟 MainWindow: Reconfiguring window: \(window.title)")
                    self.configureWindow(window)
                }
            }
        }
    }
}

// MARK: - Window Delegate

class MainWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = MainWindowDelegate()
    private let stateManager = MainWindowStateManager.shared
    
    private override init() {
        super.init()
    }
    
    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        // Debounce saves to avoid excessive UserDefaults writes
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(saveFrameDelayed(_:)), object: window)
        perform(#selector(saveFrameDelayed(_:)), with: window, afterDelay: 0.3)
    }
    
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        // Debounce saves to avoid excessive UserDefaults writes
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(saveFrameDelayed(_:)), object: window)
        perform(#selector(saveFrameDelayed(_:)), with: window, afterDelay: 0.3)
    }
    
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        // Save immediately when closing
        stateManager.saveWindowFrame(window.frame)
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Validate window is still on screen when it becomes key
        guard let window = notification.object as? NSWindow else { return }
        validateWindowPosition(window)
    }
    
    @objc private func saveFrameDelayed(_ window: NSWindow) {
        print("🪟 MainWindow: Saving frame \(window.frame)")
        stateManager.saveWindowFrame(window.frame)
    }
    
    private func validateWindowPosition(_ window: NSWindow) {
        let currentFrame = window.frame
        
        // Quick check if window is mostly visible
        var isVisible = false
        for screen in NSScreen.screens {
            let intersection = screen.visibleFrame.intersection(currentFrame)
            let intersectionArea = intersection.width * intersection.height
            let frameArea = currentFrame.width * currentFrame.height
            
            if intersectionArea >= (frameArea * 0.6) {
                isVisible = true
                break
            }
        }
        
        if !isVisible {
            print("🪟 MainWindow: Window is mostly off-screen, repositioning...")
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let newX = screenFrame.origin.x + (screenFrame.size.width - currentFrame.width) / 2
                let newY = screenFrame.origin.y + (screenFrame.size.height - currentFrame.height) / 2
                
                let newFrame = NSRect(x: newX, y: newY, width: currentFrame.width, height: currentFrame.height)
                window.setFrame(newFrame, display: true, animate: true)
                stateManager.saveWindowFrame(newFrame)
            }
        }
    }
}

// MARK: - SwiftUI Integration

struct WindowManagerView<Content: View>: View {
    let content: Content
    @StateObject private var stateManager = MainWindowStateManager.shared
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .onAppear {
                setupMainWindow()
                setupWindowNotificationHandlers()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                // Revalidate window position when app becomes active
                // This handles cases where external monitors were disconnected
                validateCurrentWindowPosition()
            }
    }
    
    private func setupWindowNotificationHandlers() {
        // Listen for new window creation
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            
            // Check if this is a main app window that needs configuration
            if window.title == "Diligence" || 
               (window.title.isEmpty && window.canBecomeMain && window.level == .normal) {
                
                // Check if window is already properly configured
                let hasAutosaveName = !window.frameAutosaveName.isEmpty
                let hasDelegate = window.delegate is MainWindowDelegate
                let hasProperMinSize = window.minSize.width >= MainWindowStateManager.minimumWindowWidth
                
                if !hasAutosaveName || !hasDelegate || !hasProperMinSize {
                    print("🪟 WindowManagerView: Configuring new main window: \(window.title)")
                    DispatchQueue.main.async {
                        MainWindowStateManager.shared.configureWindow(window)
                    }
                }
            }
        }
        
        // Listen for app activation events that might trigger window creation
        NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Small delay to allow window creation to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                MainWindowStateManager.shared.reconfigureMainWindows()
            }
        }
    }
    
    private func setupMainWindow() {
        // Give SwiftUI time to create the window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Try multiple approaches to find the main app window
            let window = self.findMainApplicationWindow()
            
            if let window = window {
                print("🪟 WindowManagerView: Found main window: \(window.title)")
                self.stateManager.configureWindow(window)
            } else {
                print("🪟 WindowManagerView: Could not find main window, retrying...")
                // Retry after a longer delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let retryWindow = self.findMainApplicationWindow() {
                        print("🪟 WindowManagerView: Found main window on retry: \(retryWindow.title)")
                        self.stateManager.configureWindow(retryWindow)
                    } else {
                        print("🪟 WindowManagerView: Still could not find main window")
                    }
                }
            }
        }
    }
    
    private func findMainApplicationWindow() -> NSWindow? {
        let allWindows = NSApplication.shared.windows
        
        // Strategy 1: Look for ContentView hosting window
        if let contentWindow = allWindows.first(where: { window in
            if window.contentView is NSHostingView<AnyView> {
                return true
            }
            if window.contentViewController is NSHostingController<AnyView> {
                return true
            }
            return false
        }) {
            return contentWindow
        }
        
        // Strategy 2: Look for window with "Diligence" title
        if let titleWindow = allWindows.first(where: { $0.title == "Diligence" }) {
            return titleWindow
        }
        
        // Strategy 3: Look for main window
        if let mainWindow = NSApplication.shared.mainWindow, mainWindow.isVisible {
            return mainWindow
        }
        
        // Strategy 4: Look for key window
        if let keyWindow = NSApplication.shared.keyWindow {
            return keyWindow
        }
        
        // Strategy 5: Take the first visible window that's not a settings or panel window
        if let firstWindow = allWindows.first(where: { window in
            return window.isVisible && 
                   !window.title.contains("Settings") && 
                   window.canBecomeMain &&
                   window.level == .normal
        }) {
            return firstWindow
        }
        
        return nil
    }
    
    private func validateCurrentWindowPosition() {
        DispatchQueue.main.async {
            guard let window = self.findMainApplicationWindow() else {
                print("🪟 WindowManagerView: Could not find main window for position validation")
                return
            }
            
            // If window is mostly off-screen, move it back
            let currentFrame = window.frame
            let screens = NSScreen.screens
            
            var isVisible = false
            var bestScreen: NSScreen?
            var maxIntersectionArea: CGFloat = 0
            
            // Find the screen with the largest intersection
            for screen in screens {
                let screenFrame = screen.visibleFrame
                if screenFrame.intersects(currentFrame) {
                    let intersection = screenFrame.intersection(currentFrame)
                    let intersectionArea = intersection.width * intersection.height
                    
                    if intersectionArea > maxIntersectionArea {
                        maxIntersectionArea = intersectionArea
                        bestScreen = screen
                    }
                    
                    let frameArea = currentFrame.width * currentFrame.height
                    if intersectionArea >= (frameArea * 0.5) {
                        isVisible = true
                    }
                }
            }
            
            if !isVisible {
                print("🪟 WindowManagerView: Window is mostly off-screen, repositioning...")
                // Use the best screen, or fall back to main screen
                let targetScreen = bestScreen ?? NSScreen.main ?? NSScreen.screens.first
                
                if let screen = targetScreen {
                    let screenFrame = screen.visibleFrame
                    let margin: CGFloat = 50
                    
                    // Ensure window fits on screen
                    let maxWidth = screenFrame.width - (margin * 2)
                    let maxHeight = screenFrame.height - (margin * 2)
                    
                    let newWidth = min(currentFrame.width, maxWidth)
                    let newHeight = min(currentFrame.height, maxHeight)
                    
                    // Center on target screen
                    let newX = screenFrame.origin.x + (screenFrame.size.width - newWidth) / 2
                    let newY = screenFrame.origin.y + (screenFrame.size.height - newHeight) / 2
                    
                    let newFrame = NSRect(x: newX, y: newY, width: newWidth, height: newHeight)
                    window.setFrame(newFrame, display: true, animate: true)
                    
                    // Save the corrected position
                    self.stateManager.saveWindowFrame(newFrame)
                    
                    print("🪟 WindowManagerView: Repositioned window to \(newFrame)")
                }
            } else {
                print("🪟 WindowManagerView: Window position is valid")
            }
        }
    }
}
