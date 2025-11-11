//
//  TasksSettingsView.swift
//  Diligence
//
//  Task management and Reminders sync settings
//

import SwiftUI
import AppKit

struct TasksSettingsView: View {
    @AppStorage("defaultTaskDueDate") private var defaultTaskDueDate = 7
    @AppStorage("includeEmailBodyInTask") private var includeEmailBodyInTask = true
    @AppStorage("autoCreateTasks") private var autoCreateTasks = false
    @AppStorage("taskSyncFrequency") private var taskSyncFrequency = 5
    @AppStorage("showCompletedTasks") private var showCompletedTasks = true
    @AppStorage("taskNotifications") private var taskNotifications = true
    @AppStorage("taskSoundAlerts") private var taskSoundAlerts = false
    
    @StateObject private var remindersService = RemindersService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModernSettingsSection(title: "Task Creation") {
                ModernSettingsRow(
                    title: "Default due date",
                    description: "Number of days from now to set as default due date"
                ) {
                    Stepper(value: $defaultTaskDueDate, in: 1...30) {
                        Text("\(defaultTaskDueDate) days")
                            .font(.system(size: 12))
                            .frame(width: 60)
                    }
                    .controlSize(.small)
                }
                
                ModernSettingsRow(
                    title: "Include email body",
                    description: "Include email content in task description when creating from emails"
                ) {
                    Toggle("", isOn: $includeEmailBodyInTask)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                
                ModernSettingsRow(
                    title: "Auto-create tasks",
                    description: "Automatically create tasks from certain email types (invoices, deadlines)"
                ) {
                    Toggle("", isOn: $autoCreateTasks)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            
            ModernSettingsSection(title: "Task Display") {
                ModernSettingsRow(
                    title: "Show completed tasks",
                    description: "Display completed tasks in the task list"
                ) {
                    Toggle("", isOn: $showCompletedTasks)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            
            ModernSettingsSection(title: "Reminders Sync") {
                ModernSettingsRow(
                    title: "Sync frequency",
                    description: "How often to sync tasks with system Reminders (minutes)"
                ) {
                    Picker("", selection: $taskSyncFrequency) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("Manual only").tag(0)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    .controlSize(.small)
                }
                
                ModernSettingsRow(
                    title: "Sync Status",
                    description: remindersService.getSyncStatusText()
                ) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(remindersService.isAuthorized ? .green : .orange)
                            .frame(width: 8, height: 8)
                        
                        Text(remindersService.isAuthorized ? "Active" : "Inactive")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(remindersService.isAuthorized ? .green : .orange)
                    }
                }
            }
            
            // Sync Actions
            if remindersService.isAuthorized {
                HStack {
                    Button("Sync Now") {
                        remindersService.testSync()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Force Full Sync") {
                        // Implement full sync
                        remindersService.testSync()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            ModernSettingsSection(title: "Notifications") {
                ModernSettingsRow(
                    title: "Task notifications",
                    description: "Show system notifications for task reminders and due dates"
                ) {
                    Toggle("", isOn: $taskNotifications)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                
                ModernSettingsRow(
                    title: "Sound alerts",
                    description: "Play sound when task notifications appear"
                ) {
                    Toggle("", isOn: $taskSoundAlerts)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .disabled(!taskNotifications)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    TasksSettingsView()
        .frame(width: 600, height: 400)
        .padding()
}