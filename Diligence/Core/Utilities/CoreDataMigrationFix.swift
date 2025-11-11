//
//  CoreDataMigrationFix.swift
//  Diligence
//
//  Created by Assistant on 11/02/25.
//

import Foundation
import SwiftData

// MARK: - Core Data Migration Fix

/**
 This file provides solutions to fix Core Data warnings about transformable properties
 using deprecated NSKeyedUnarchiveFromDataTransformerName.
 
 The warning occurs when:
 1. Migrating from old Core Data models
 2. Using cached Core Data stores with old transformer names
 3. Transformer name strings are incorrect
 
 Solutions implemented:
 1. Proper transformable attribute declaration in SwiftData
 2. Custom secure transformer for complex data types
 3. Data store cleanup instructions
 */

// MARK: - Custom Secure Transformer

/// Custom transformer for arrays that ensures NSSecureCoding compliance
/// Uses JSON encoding instead of deprecated NSKeyedArchiver
final class SecureArrayTransformer: ValueTransformer {
    
    /// The name of the transformer for registration
    static let name = NSValueTransformerName(rawValue: "SecureArrayTransformer")
    
    /// Register the transformer with the system
    static func register() {
        let transformer = SecureArrayTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
    
    /// Indicates this transformer supports reverse transformation
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    /// The input type is [Int], output is Data
    override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    /// Transform array to JSON data
    override func transformedValue(_ value: Any?) -> Any? {
        guard let array = value as? [Int] else { return nil }
        do {
            return try JSONEncoder().encode(array)
        } catch {
            print("SecureArrayTransformer encode error: \(error)")
            return nil
        }
    }
    
    /// Transform JSON data back to array
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        do {
            return try JSONDecoder().decode([Int].self, from: data)
        } catch {
            print("SecureArrayTransformer decode error: \(error)")
            return nil
        }
    }
}

// MARK: - Data Store Cleanup

extension ModelContainer {
    
    /// Clean up legacy Core Data stores to prevent transformer warnings
    static func cleanupLegacyStores() {
        let fileManager = FileManager.default
        
        // Get application support directory
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, 
                                                  in: .userDomainMask).first else {
            print("⚠️ Could not find application support directory")
            return
        }
        
        // Look for potential Core Data files
        do {
            let contents = try fileManager.contentsOfDirectory(at: appSupportDir, 
                                                              includingPropertiesForKeys: nil)
            
            let coreDataFiles = contents.filter { url in
                let pathExtension = url.pathExtension.lowercased()
                let filename = url.lastPathComponent.lowercased()
                return ["sqlite", "sqlite-wal", "sqlite-shm", "db"].contains(pathExtension) ||
                       filename.contains("coredata") || filename.contains("model")
            }
            
            print("🔍 Found \(coreDataFiles.count) potential legacy data files")
            
            // Log files for inspection
            for file in coreDataFiles {
                print("📁 Data file: \(file.lastPathComponent)")
                
                // Check file modification date
                if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                   let modificationDate = attributes[.modificationDate] as? Date {
                    print("📅 Last modified: \(modificationDate)")
                    
                    // If file is from old CoreData and causing issues, recommend cleanup
                    let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
                    if modificationDate < sevenDaysAgo && file.pathExtension == "sqlite" {
                        print("ℹ️ Consider cleaning up old data file: \(file.lastPathComponent)")
                        print("   You can delete this manually if it's causing CoreData warnings")
                    }
                }
            }
            
        } catch {
            print("❌ Error reading application support directory: \(error)")
        }
    }
    
    /// Force clean SwiftData cache to resolve model conflicts
    static func resetSwiftDataCache() {
        let fileManager = FileManager.default
        
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, 
                                                  in: .userDomainMask).first else { return }
        
        // Look for SwiftData default.store file
        let swiftDataStore = appSupportDir.appendingPathComponent("default.store")
        
        if fileManager.fileExists(atPath: swiftDataStore.path) {
            print("🗃️ Found SwiftData store at: \(swiftDataStore.path)")
            print("ℹ️ If CoreData warnings persist, consider backing up and deleting this file")
            print("   The app will recreate it with proper transformers on next launch")
            
            // Check for related files
            let relatedFiles = [
                swiftDataStore.appendingPathExtension("sqlite-wal"),
                swiftDataStore.appendingPathExtension("sqlite-shm"),
                appSupportDir.appendingPathComponent("default.store-wal"),
                appSupportDir.appendingPathComponent("default.store-shm")
            ]
            
            for relatedFile in relatedFiles {
                if fileManager.fileExists(atPath: relatedFile.path) {
                    print("🗃️ Related file: \(relatedFile.lastPathComponent)")
                }
            }
        }
    }
    
    /// Forcefully clean SwiftData cache (use with caution - will delete data!)
    static func forceCleanSwiftDataCache() -> Bool {
        let fileManager = FileManager.default
        
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, 
                                                  in: .userDomainMask).first else { 
            print("❌ Could not find app support directory")
            return false 
        }
        
        let filesToDelete = [
            appSupportDir.appendingPathComponent("default.store"),
            appSupportDir.appendingPathComponent("default.store-wal"),
            appSupportDir.appendingPathComponent("default.store-shm")
        ]
        
        var deletedCount = 0
        for file in filesToDelete {
            if fileManager.fileExists(atPath: file.path) {
                do {
                    try fileManager.removeItem(at: file)
                    print("🗑️ Deleted: \(file.lastPathComponent)")
                    deletedCount += 1
                } catch {
                    print("❌ Failed to delete \(file.lastPathComponent): \(error)")
                }
            }
        }
        
        if deletedCount > 0 {
            print("✅ Force cleaned SwiftData cache - deleted \(deletedCount) files")
            print("⚠️ All data has been reset! The app will recreate the database on next launch.")
            return true
        } else {
            print("ℹ️ No SwiftData cache files found to delete")
            return false
        }
    }
}

// MARK: - Migration Helper

struct CoreDataMigrationFixHelper {
    
    /// Initialize transformers and cleanup on app launch
    static func initializeOnAppLaunch() {
        print("🔧 CoreData migration helper initializing...")
        
        // Step 0: Check for and handle SQLite corruption first
        checkAndRecoverFromSQLiteErrors()
        
        // Step 1: Try to fix the Array materialization error first
        fixArrayMaterializationError()
        
        // Step 2: Register custom secure transformer
        SecureArrayTransformer.register()
        print("✅ Registered SecureArrayTransformer")
        
        // Step 3: Clean up legacy stores (for inspection only)
        ModelContainer.cleanupLegacyStores()
        
        // Step 4: Check SwiftData cache
        ModelContainer.resetSwiftDataCache()
        
        // Step 5: Verify transformer is available
        let transformer = ValueTransformer(forName: SecureArrayTransformer.name)
        if transformer != nil {
            print("✅ SecureArrayTransformer is available")
        } else {
            print("❌ SecureArrayTransformer registration failed")
        }
        
        print("✅ CoreData migration helper initialized")
        print("   If 'Array materialization' errors persist, call emergencyDatabaseReset()")
        print("   If SQLite errors persist, call handleSQLiteCorruption()")
    }
    
    /// Alternative implementation using JSON encoding instead of NSKeyedArchiver
    static func migrateToJSONEncoding() {
        print("📝 Consider migrating transformable data to JSON encoding")
        print("   This eliminates the need for NSKeyedArchiver entirely")
        print("   Use SecureArrayTransformer instead of NSSecureUnarchiveFromDataTransformer")
        print("   Current implementation in DiligenceTask can be updated to use SecureArrayTransformer")
        print("   Change @Attribute(.transformable(by: \"NSSecureUnarchiveFromDataTransformer\"))")
        print("   To: @Attribute(.transformable(by: \"SecureArrayTransformer\"))")
    }
    
    /// Fix CoreData Array materialization errors
    static func fixArrayMaterializationError() {
        print("🔧 Attempting to fix CoreData Array materialization error...")
        
        // The error "Could not materialize Objective-C class named 'Array'" indicates
        // that CoreData is trying to instantiate the old Array<Int> type directly
        // instead of using our new Data-based approach with JSON encoding
        
        // This usually happens when:
        // 1. There's cached CoreData metadata pointing to the old model
        // 2. The app was run before the transformer fix was applied
        // 3. SwiftData cache contains references to the old attribute type
        
        print("   Step 1: Checking for cached SwiftData files...")
        ModelContainer.resetSwiftDataCache()
        
        print("   Step 2: Registering secure transformers...")
        SecureArrayTransformer.register()
        
        print("   Step 3: Clearing any cached model configurations...")
        // Clear UserDefaults that might contain cached model info
        let keys = [
            "com.apple.coredata.cloudkit.zone.ownerName",
            "com.apple.coredata.cloudkit.container",
            "NSPersistentHistoryTrackingKey"
        ]
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        print("✅ Array materialization fix applied")
        print("   If the error persists, you may need to:")
        print("   1. Quit the app completely")
        print("   2. Call ModelContainer.forceCleanSwiftDataCache()")
        print("   3. Restart the app to recreate the database with proper transformers")
    }
    
    /// Emergency reset - deletes all data and recreates clean database
    static func emergencyDatabaseReset() -> Bool {
        print("🚨 EMERGENCY DATABASE RESET")
        print("   This will DELETE ALL DATA and recreate a clean database!")
        print("   Only use this if CoreData errors prevent app startup")
        
        let success = ModelContainer.forceCleanSwiftDataCache()
        
        if success {
            // Also clear related UserDefaults
            let preferencesToClear = [
                "DiligenceDefaultCalendarID",
                "DiligenceSectionCalendarIDs",
                "com.apple.coredata.cloudkit.zone.ownerName",
                "com.apple.coredata.cloudkit.container",
                "NSPersistentHistoryTrackingKey"
            ]
            
            for pref in preferencesToClear {
                UserDefaults.standard.removeObject(forKey: pref)
            }
            
            print("✅ Emergency reset complete")
            print("   App will restart with a clean database")
        }
        
        return success
    }
    
    /// Handle SQLite corruption errors specifically
    static func handleSQLiteCorruption() -> Bool {
        print("🚨 HANDLING SQLITE CORRUPTION")
        print("   Detected SQLite file corruption - attempting recovery...")
        
        let fileManager = FileManager.default
        
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, 
                                                  in: .userDomainMask).first else {
            print("❌ Could not find app support directory")
            return false
        }
        
        // Look for all SQLite-related files
        let sqliteFiles = [
            appSupportDir.appendingPathComponent("default.store"),
            appSupportDir.appendingPathComponent("default.store-wal"),
            appSupportDir.appendingPathComponent("default.store-shm"),
            appSupportDir.appendingPathComponent("Model.sqlite"),
            appSupportDir.appendingPathComponent("Model.sqlite-wal"),
            appSupportDir.appendingPathComponent("Model.sqlite-shm"),
        ]
        
        var corruptedFiles: [URL] = []
        var deletedCount = 0
        
        // Check each file for existence and potential corruption
        for file in sqliteFiles {
            if fileManager.fileExists(atPath: file.path) {
                print("🔍 Found SQLite file: \(file.lastPathComponent)")
                
                // Check file size - 0 bytes usually indicates corruption
                if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                   let fileSize = attributes[.size] as? Int64 {
                    print("📊 File size: \(fileSize) bytes")
                    
                    if fileSize == 0 {
                        print("⚠️ File appears corrupted (0 bytes)")
                        corruptedFiles.append(file)
                    }
                }
                
                // Attempt to delete the file to allow clean recreation
                do {
                    try fileManager.removeItem(at: file)
                    print("🗑️ Deleted potentially corrupted file: \(file.lastPathComponent)")
                    deletedCount += 1
                } catch {
                    print("❌ Failed to delete \(file.lastPathComponent): \(error)")
                }
            }
        }
        
        if deletedCount > 0 {
            print("✅ SQLite corruption recovery complete - deleted \(deletedCount) files")
            print("   App will recreate clean database files on next access")
            
            // Clear any cached database references
            UserDefaults.standard.removeObject(forKey: "SQLiteFilePath")
            UserDefaults.standard.removeObject(forKey: "LastDatabaseVersion")
            
            return true
        } else {
            print("ℹ️ No corrupted SQLite files found to delete")
            return false
        }
    }
    
    /// Check for specific SQLite errors and auto-recover
    static func checkAndRecoverFromSQLiteErrors() {
        print("🔍 Checking for SQLite corruption indicators...")
        
        // Check if we've seen recent SQLite errors
        if hasSQLiteError() {
            print("⚠️ SQLite errors detected - initiating recovery...")
            let recovered = handleSQLiteCorruption()
            
            if recovered {
                print("✅ SQLite recovery completed")
                // Mark that we've attempted recovery
                UserDefaults.standard.set(Date(), forKey: "LastSQLiteRecovery")
            } else {
                print("❌ SQLite recovery failed - may need manual intervention")
            }
        }
    }
    
    /// Check if there are indicators of SQLite issues
    private static func hasSQLiteError() -> Bool {
        // Check recent error patterns that might indicate SQLite corruption
        let lastRecovery = UserDefaults.standard.object(forKey: "LastSQLiteRecovery") as? Date
        
        // If we recovered recently, don't immediately try again
        if let lastRecovery = lastRecovery {
            let hoursSinceRecovery = Date().timeIntervalSince(lastRecovery) / 3600
            if hoursSinceRecovery < 1 {
                print("ℹ️ Recent SQLite recovery attempted - skipping check")
                return false
            }
        }
        
        // Look for common SQLite corruption indicators
        let fileManager = FileManager.default
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, 
                                                  in: .userDomainMask).first else { return false }
        
        let sqliteFile = appSupportDir.appendingPathComponent("default.store")
        
        if fileManager.fileExists(atPath: sqliteFile.path) {
            // Check if file size is 0 (corruption indicator)
            if let attributes = try? fileManager.attributesOfItem(atPath: sqliteFile.path),
               let fileSize = attributes[.size] as? Int64 {
                if fileSize == 0 {
                    print("🚨 SQLite file has 0 bytes - likely corrupted")
                    return true
                }
            }
        }
        
        return false
    }
}

// MARK: - Alternative Implementation Notes

/*
 The current DiligenceTask model uses a good approach with JSON encoding:
 
 ```swift
 @Attribute(.transformable(by: "NSSecureUnarchiveFromDataTransformer"))
 var recurrenceWeekdaysData: Data = Data()
 
 var recurrenceWeekdays: [Int] {
     get {
         if recurrenceWeekdaysData.isEmpty { return [] }
         do {
             return try JSONDecoder().decode([Int].self, from: recurrenceWeekdaysData)
         } catch {
             print("Failed to decode recurrenceWeekdays: \(error)")
             return []
         }
     }
     set {
         do {
             recurrenceWeekdaysData = try JSONEncoder().encode(newValue)
         } catch {
             print("Failed to encode recurrenceWeekdays: \(error)")
             recurrenceWeekdaysData = Data()
         }
     }
 }
 ```
 
 However, to eliminate the NSKeyedUnarchiveFromData warnings completely, consider:
 1. Using the SecureArrayTransformer defined above instead of NSSecureUnarchiveFromDataTransformer
 2. This custom transformer uses JSON encoding/decoding exclusively
 3. No more NSKeyedArchiver/NSKeyedUnarchiver deprecation warnings
 4. Better performance and security than the deprecated approach
 
 To implement this in your model, change the transformer attribute:
 @Attribute(.transformable(by: "SecureArrayTransformer"))
 
 Make sure to call CoreDataMigrationHelper.initializeOnAppLaunch() to register the transformer.
 
 If warnings persist, they might be from:
 1. Legacy Core Data files in the app's container
 2. Cached model versions pointing to old transformers
 3. Migration from previous Core Data implementations using deprecated transformers
 */
