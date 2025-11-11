//
//  CoreDataMigrationHelper.swift
//  Diligence
//
//  Created by derham on 11/10/25.
//

import Foundation
import SwiftData
import Combine

struct CoreDataMigrationHelper {
    
    /// Initialize any necessary migration fixes on app launch
    static func initializeOnAppLaunch() {
        print("✅ CoreDataMigrationHelper initialized")
        
        // Check for any stale lock files
        cleanupStaleLockFiles()
    }
    
    /// Handle SQLite database corruption
    static func handleSQLiteCorruption() -> Bool {
        print("🔄 Handling SQLite corruption...")
        
        // Attempt to backup the corrupted database before deletion
        let url = getDatabaseURL()
        let backupURL = getBackupURL()
        
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                // Try to backup
                if !FileManager.default.fileExists(atPath: backupURL.path) {
                    try FileManager.default.copyItem(at: url, to: backupURL)
                    print("📦 Corrupted database backed up to: \(backupURL.path)")
                }
            }
        } catch {
            print("⚠️ Could not backup corrupted database: \(error)")
        }
        
        // Perform reset
        return emergencyDatabaseReset()
    }
    
    /// Emergency database reset - removes all database files
    static func emergencyDatabaseReset() -> Bool {
        print("🚨 Performing emergency database reset")
        
        let url = getDatabaseURL()
        var success = true
        
        // Remove main database file
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                print("✅ Removed main database file")
            }
        } catch {
            print("❌ Failed to remove main database: \(error)")
            success = false
        }
        
        // Remove related files (WAL, SHM)
        let walURL = url.appendingPathExtension("wal")
        let shmURL = url.appendingPathExtension("shm")
        
        for fileURL in [walURL, shmURL] {
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                    print("✅ Removed database auxiliary file: \(fileURL.lastPathComponent)")
                }
            } catch {
                print("⚠️ Could not remove auxiliary file: \(error)")
            }
        }
        
        if success {
            print("✅ Database reset successful")
        } else {
            print("⚠️ Database reset completed with warnings")
        }
        
        return success
    }
    
    /// Clean up stale lock files
    private static func cleanupStaleLockFiles() {
        let url = getDatabaseURL()
        let shmURL = url.appendingPathExtension("shm")
        
        // Check if SHM file exists without corresponding database
        if FileManager.default.fileExists(atPath: shmURL.path) &&
           !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: shmURL)
                print("🧹 Cleaned up stale lock file")
            } catch {
                print("⚠️ Could not clean up stale lock file: \(error)")
            }
        }
    }
    
    /// Get the database URL
    private static func getDatabaseURL() -> URL {
        return URL.applicationSupportDirectory.appending(path: "default.store")
    }
    
    /// Get the backup URL for corrupted databases
    private static func getBackupURL() -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return URL.applicationSupportDirectory.appending(path: "corrupted_backup_\(timestamp).store")
    }
}
