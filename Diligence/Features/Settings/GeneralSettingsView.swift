//
//  GeneralSettingsView.swift
//  Diligence
//
//  General app settings and preferences
//

import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @AppStorage("autoLoadEmails") private var autoLoadEmails = true
    @AppStorage("openGmailInBackground") private var openGmailInBackground = false
    @AppStorage("showEmailSnippets") private var showEmailSnippets = true
    @AppStorage("startMinimized") private var startMinimized = false
    @AppStorage("hideMenuBarIcon") private var hideMenuBarIcon = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModernSettingsSection(title: "Startup Behavior") {
                ModernSettingsRow(
                    title: "Auto-load emails",
                    description: "Automatically load recent emails when Gmail tab is selected"
                ) {
                    Toggle("", isOn: $autoLoadEmails)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                
                ModernSettingsRow(
                    title: "Start minimized",
                    description: "Launch the app in a minimized state"
                ) {
                    Toggle("", isOn: $startMinimized)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            
            ModernSettingsSection(title: "Email Behavior") {
                ModernSettingsRow(
                    title: "Show email snippets",
                    description: "Display email preview text in the email list"
                ) {
                    Toggle("", isOn: $showEmailSnippets)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                
                ModernSettingsRow(
                    title: "Open Gmail in background",
                    description: "Open Gmail links without bringing browser to front"
                ) {
                    Toggle("", isOn: $openGmailInBackground)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            
            ModernSettingsSection(title: "Menu Bar") {
                ModernSettingsRow(
                    title: "Hide menu bar icon",
                    description: "Hide the Diligence icon from the menu bar"
                ) {
                    Toggle("", isOn: $hideMenuBarIcon)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            
            Spacer()
        }
    }
}
