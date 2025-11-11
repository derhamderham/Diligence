//
//  AILLMSettingsView.swift
//  Diligence
//
//  AI Assistant and Language Model configuration
//

import SwiftUI
import AppKit

struct AILLMSettingsView: View {
    // AI Feature Toggle
    @State private var llmFeatureEnabled: Bool = UserDefaults.standard.llmFeatureEnabled
    
    // Jan.ai Settings
    @State private var llmBaseURL: String = UserDefaults.standard.customLLMBaseURL ?? LLMConfiguration.janAIBaseURL
    @State private var llmAPIKey: String = UserDefaults.standard.llmAPIKey ?? ""
    @State private var selectedLLMModel: String = UserDefaults.standard.selectedLLMModel
    @State private var llmTemperature: Double = UserDefaults.standard.llmTemperature
    @State private var llmMaxTokens: Int = UserDefaults.standard.llmMaxTokens
    @State private var llmAutoDetectModel: Bool = UserDefaults.standard.llmAutoDetectModel
    @State private var llmStreamingEnabled: Bool = UserDefaults.standard.llmStreamingEnabled
    
    // Enhanced AI Service
    @StateObject private var enhancedAIService = EnhancedAIEmailService()
    @StateObject private var llmService = LLMService()
    
    // UI State
    @State private var connectionStatus: Bool? = nil
    @State private var connectionError: String?
    @State private var availableModels: [String] = LLMConfiguration.availableModels
    @State private var isDetectingModel = false
    @State private var isTestingConnection = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModernSettingsSection(title: "AI Assistant") {
                ModernSettingsRow(
                    title: "Enable AI Features",
                    description: "Enable AI-powered email analysis and task generation"
                ) {
                    Toggle("", isOn: $llmFeatureEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: llmFeatureEnabled) { _, newValue in
                            UserDefaults.standard.llmFeatureEnabled = newValue
                        }
                }
            }
            
            if llmFeatureEnabled {
                // AI Provider Selection
                ModernSettingsSection(title: "AI Provider") {
                    ModernSettingsRow(
                        title: "Active Provider",
                        description: "Current AI service being used"
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: enhancedAIService.selectedProvider.icon)
                                .font(.system(size: 12))
                                .foregroundColor(enhancedAIService.currentServiceColor)
                            
                            Text(enhancedAIService.selectedProvider.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(enhancedAIService.currentServiceColor)
                        }
                    }
                    
                    ModernSettingsRow(
                        title: "Provider Status",
                        description: enhancedAIService.currentServiceStatus
                    ) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(enhancedAIService.currentServiceColor)
                                .frame(width: 8, height: 8)
                            
                            Text(enhancedAIService.hasAvailableService ? "Available" : "Unavailable")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(enhancedAIService.currentServiceColor)
                        }
                    }
                }
                
                // AI Provider Selection Buttons
                HStack(spacing: 12) {
                    ForEach(EnhancedAIEmailService.AIProvider.allCases, id: \.self) { provider in
                        Button(action: {
                            enhancedAIService.switchProvider(provider)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: provider.icon)
                                Text(provider.displayName)
                            }
                            .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!enhancedAIService.availableProviders.contains(provider))
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                
                // Apple Intelligence Settings
                if enhancedAIService.selectedProvider == .appleIntelligence {
                    ModernSettingsSection(title: "Apple Intelligence") {
                        ModernSettingsRow(
                            title: "Device Support",
                            description: "Apple Intelligence availability on this device"
                        ) {
                            Text(enhancedAIService.isAppleIntelligenceAvailable ? "Supported" : "Not Available")
                                .font(.system(size: 12))
                                .foregroundColor(enhancedAIService.isAppleIntelligenceAvailable ? .green : .orange)
                        }
                        
                        if !enhancedAIService.isAppleIntelligenceAvailable {
                            ModernSettingsRow(
                                title: "Setup Required",
                                description: "Enable Apple Intelligence in System Settings"
                            ) {
                                Button("Open System Settings") {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                
                // Jan.ai Settings
                if enhancedAIService.selectedProvider == .janAI {
                    ModernSettingsSection(title: "Jan.ai Configuration") {
                        ModernSettingsRow(
                            title: "Server URL",
                            description: "Base URL for Jan.ai local server"
                        ) {
                            VStack(alignment: .trailing, spacing: 4) {
                                TextField("http://localhost:1337", text: $llmBaseURL)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11))
                                    .monospaced()
                                    .frame(width: 200)
                                    .onChange(of: llmBaseURL) { _, newValue in
                                        UserDefaults.standard.customLLMBaseURL = newValue
                                    }
                                
                                Button("Test Connection") {
                                    testConnection()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .disabled(isTestingConnection)
                            }
                        }
                        
                        ModernSettingsRow(
                            title: "Connection Status",
                            description: connectionStatusDescription
                        ) {
                            HStack(spacing: 8) {
                                if isTestingConnection {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.5)
                                        .frame(width: 8, height: 8, alignment: .center)
                                        .fixedSize()
                                } else {
                                    Circle()
                                        .fill(connectionStatusColor)
                                        .frame(width: 8, height: 8)
                                }
                                
                                Text(connectionStatusText)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(connectionStatusColor)
                            }
                        }
                        
                        ModernSettingsRow(
                            title: "Model",
                            description: "Language model to use for AI tasks"
                        ) {
                            VStack(alignment: .trailing, spacing: 4) {
                                Picker("", selection: $selectedLLMModel) {
                                    ForEach(availableModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                                .controlSize(.small)
                                .onChange(of: selectedLLMModel) { _, newValue in
                                    UserDefaults.standard.selectedLLMModel = newValue
                                }
                                
                                HStack(spacing: 8) {
                                    Button("Auto-detect") {
                                        detectCurrentModel()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                    .disabled(isDetectingModel)
                                    
                                    Button("Refresh List") {
                                        refreshModelList()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                            }
                        }
                        
                        ModernSettingsRow(
                            title: "Auto-detect model",
                            description: "Automatically detect the active model from Jan.ai"
                        ) {
                            Toggle("", isOn: $llmAutoDetectModel)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .onChange(of: llmAutoDetectModel) { _, newValue in
                                    UserDefaults.standard.llmAutoDetectModel = newValue
                                }
                        }
                    }
                    
                    ModernSettingsSection(title: "Model Parameters") {
                        ModernSettingsRow(
                            title: "Temperature",
                            description: "Creativity level: 0.0 (focused) to 1.0 (creative)"
                        ) {
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack {
                                    Slider(value: $llmTemperature, in: 0.0...1.0, step: 0.1)
                                        .frame(width: 120)
                                    
                                    Text(String(format: "%.1f", llmTemperature))
                                        .font(.system(size: 11))
                                        .monospaced()
                                        .frame(width: 30)
                                }
                                .onChange(of: llmTemperature) { _, newValue in
                                    UserDefaults.standard.llmTemperature = newValue
                                }
                            }
                        }
                        
                        ModernSettingsRow(
                            title: "Max tokens",
                            description: "Maximum response length"
                        ) {
                            Stepper(value: $llmMaxTokens, in: 100...4000, step: 100) {
                                Text("\(llmMaxTokens)")
                                    .font(.system(size: 12))
                                    .frame(width: 50)
                            }
                            .controlSize(.small)
                            .onChange(of: llmMaxTokens) { _, newValue in
                                UserDefaults.standard.llmMaxTokens = newValue
                            }
                        }
                        
                        ModernSettingsRow(
                            title: "Streaming responses",
                            description: "Stream AI responses as they're generated"
                        ) {
                            Toggle("", isOn: $llmStreamingEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .onChange(of: llmStreamingEnabled) { _, newValue in
                                    UserDefaults.standard.llmStreamingEnabled = newValue
                                }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .onAppear {
            _Concurrency.Task {
                await enhancedAIService.initialize()
                testConnection()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var connectionStatusText: String {
        if isTestingConnection { return "Testing..." }
        guard let status = connectionStatus else { return "Unknown" }
        return status ? "Connected" : "Disconnected"
    }
    
    private var connectionStatusColor: Color {
        if isTestingConnection { return .orange }
        guard let status = connectionStatus else { return .orange }
        return status ? .green : .red
    }
    
    private var connectionStatusDescription: String {
        if isTestingConnection { return "Testing connection to Jan.ai server..." }
        guard let status = connectionStatus else { return "Connection status unknown" }
        if status {
            return "Successfully connected to Jan.ai server"
        } else if let error = connectionError {
            return "Connection failed: \(error)"
        } else {
            return "Cannot connect to Jan.ai server"
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        
        _Concurrency.Task {
            let result = await llmService.checkServiceAvailability(autoDetectModel: false)
            
            await MainActor.run {
                connectionStatus = result
                isTestingConnection = false
                
                if !result {
                    connectionError = "Server not responding"
                } else {
                    connectionError = nil
                }
            }
        }
    }
    
    private func detectCurrentModel() {
        guard !isDetectingModel else { return }
        
        isDetectingModel = true
        
        _Concurrency.Task {
            let detectedModel = await llmService.refreshCurrentModel()
            
            await MainActor.run {
                if let detectedModel = detectedModel, !detectedModel.isEmpty {
                    selectedLLMModel = detectedModel
                    UserDefaults.standard.selectedLLMModel = detectedModel
                }
                isDetectingModel = false
            }
        }
    }
    
    private func refreshModelList() {
        _Concurrency.Task {
            let serverModels = await llmService.getAvailableModelsFromServer()
            
            await MainActor.run {
                if !serverModels.isEmpty {
                    availableModels = serverModels
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AILLMSettingsView()
        .frame(width: 600, height: 500)
        .padding()
}