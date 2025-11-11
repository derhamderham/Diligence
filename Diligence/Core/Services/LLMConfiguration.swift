//
//  LLMConfiguration.swift
//  Diligence
//
//  Created by Assistant on 10/30/25.
//

import Foundation

// MARK: - Extensions

extension Array where Element: Equatable {
    func uniqueElements() -> [Element] {
        var uniqueArray: [Element] = []
        for element in self {
            if !uniqueArray.contains(element) {
                uniqueArray.append(element)
            }
        }
        return uniqueArray
    }
}

/// Configuration for Local LLM integration
struct LLMConfiguration {
    
    // MARK: - Jan.ai Configuration
    
    /// Base URL for Jan.ai local server (using IPv4 for better connectivity)
    static let janAIBaseURL = "http://127.0.0.1:1337/v1"
    
    /// Default model names that work well with Jan.ai
    static let availableModels = [
        "llama-3.2-3b-instruct",
        "llama-3.2-1b-instruct", 
        "gemma-2-2b-instruct",
        "phi-3.5-mini-instruct",
        "qwen-2.5-7b-instruct",
        "Jan-v1-4B-Q4_K_M"
    ]
    
    /// Default model to use
    static let defaultModel = "llama-3.2-3b-instruct"
    
    // MARK: - Request Parameters
    
    /// Default temperature for more focused responses
    static let defaultTemperature: Double = 0.7
    
    /// Maximum tokens for response (increased for complete responses)
    static let maxTokens = 2048
    
    /// Request timeout in seconds (increased for large payloads)
    static let timeoutInterval: TimeInterval = 120
    
    /// Timeout for model detection requests (shorter for better UX)
    static let modelDetectionTimeout: TimeInterval = 10
    
    /// Enable streaming responses by default (recommended for Jan.ai)
    static let defaultStreamingEnabled = true
    
    // MARK: - Email Processing
    
    /// Maximum number of emails to send in one request (to avoid token limits)
    static let maxEmailsPerRequest = 15
    
    /// Maximum character length for email body to include (to avoid token limits)
    static let maxEmailBodyLength = 1500
    
    /// Whether to include attachment information in queries
    static let includeAttachmentInfo = true
    
    // MARK: - Model Detection
    
    /// Detects the currently loaded model from jan.ai and updates the selected model
    /// - Parameter baseURL: The base URL to query (defaults to janAIBaseURL)
    /// - Returns: The name of the currently loaded model, if any
    @MainActor
    static func detectCurrentModel(from baseURL: String? = nil) async -> String? {
        let url = baseURL ?? janAIBaseURL
        
        // First try to get the current model from the /models endpoint
        if let currentModel = await getCurrentLoadedModel(from: url) {
            UserDefaults.standard.selectedLLMModel = currentModel
            return currentModel
        }
        
        // If that fails, try to get available models and use the first one
        if let availableModels = await getAvailableModelsFromServer(from: url),
           let firstModel = availableModels.first {
            UserDefaults.standard.selectedLLMModel = firstModel
            return firstModel
        }
        
        return nil
    }
    
    /// Gets the currently loaded model from jan.ai
    private static func getCurrentLoadedModel(from baseURL: String) async -> String? {
        // Try IPv4 first, then fallback to original URL
        let testURLs = getTestURLs(from: baseURL)
        
        for testURL in testURLs {
            guard let url = URL(string: "\(testURL)/models") else { continue }
            
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = modelDetectionTimeout
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continue
                }
                
                // Parse the models response to find the currently loaded model
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let modelsData = json["data"] as? [[String: Any]] {
                    
                    // Look for a model that's currently loaded/active
                    for modelInfo in modelsData {
                        if let modelId = modelInfo["id"] as? String,
                           let owned_by = modelInfo["owned_by"] as? String {
                            // In jan.ai, loaded models typically have owned_by set to something other than "system"
                            if owned_by != "system" {
                                return modelId
                            }
                        }
                    }
                    
                    // If no active model found, return the first available model
                    if let firstModel = modelsData.first,
                       let modelId = firstModel["id"] as? String {
                        return modelId
                    }
                }
                
            } catch {
                print("Failed to detect current model from \(testURL): \(error)")
                continue
            }
        }
        
        return nil
    }
    
    /// Gets all available models from the server
    static func getAvailableModelsFromServer(from baseURL: String) async -> [String]? {
        // Try IPv4 first, then fallback to original URL
        let testURLs = getTestURLs(from: baseURL)
        
        for testURL in testURLs {
            guard let url = URL(string: "\(testURL)/models") else { continue }
            
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = modelDetectionTimeout
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continue
                }
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let modelsData = json["data"] as? [[String: Any]] {
                    
                    let modelNames = modelsData.compactMap { modelInfo in
                        modelInfo["id"] as? String
                    }
                    
                    if !modelNames.isEmpty {
                        return modelNames
                    }
                }
                
            } catch {
                print("Failed to get available models from \(testURL): \(error)")
                continue
            }
        }
        
        return nil
    }
    
    /// Helper method to generate test URLs with IPv4 preference
    private static func getTestURLs(from baseURL: String) -> [String] {
        if baseURL.contains("localhost") || baseURL.contains("127.0.0.1") {
            let port = baseURL.components(separatedBy: ":").last?.components(separatedBy: "/").first ?? "1337"
            return [
                "http://127.0.0.1:\(port)/v1", // IPv4 first (preferred)
                baseURL.replacingOccurrences(of: "localhost", with: "127.0.0.1"), // Convert localhost to IPv4
                baseURL // Keep original as last resort
            ].compactMap { $0 }.uniqueElements()
        } else {
            return [baseURL]
        }
    }
    
    /// Checks if model auto-detection should be performed on app launch
    /// - Returns: True if auto-detection is enabled and should run
    static func shouldAutoDetectModel() -> Bool {
        return UserDefaults.standard.llmAutoDetectModel && 
               UserDefaults.standard.llmFeatureEnabled
    }
}

/// User defaults keys for persisting LLM settings
extension UserDefaults {
    private enum Keys {
        static let selectedModel = "LLMSelectedModel"
        static let customBaseURL = "LLMCustomBaseURL"
        static let temperature = "LLMTemperature"
        static let featureEnabled = "LLMFeatureEnabled"
        static let apiKey = "LLMAPIKey"
        static let maxTokens = "LLMMaxTokens"
        static let autoDetectModel = "LLMAutoDetectModel"
        static let streamingEnabled = "LLMStreamingEnabled"
    }
    
    var selectedLLMModel: String {
        get { string(forKey: Keys.selectedModel) ?? LLMConfiguration.defaultModel }
        set { set(newValue, forKey: Keys.selectedModel) }
    }
    
    var customLLMBaseURL: String? {
        get { string(forKey: Keys.customBaseURL) }
        set { set(newValue, forKey: Keys.customBaseURL) }
    }
    
    var llmTemperature: Double {
        get { 
            let temp = double(forKey: Keys.temperature)
            return temp == 0 ? LLMConfiguration.defaultTemperature : temp
        }
        set { set(newValue, forKey: Keys.temperature) }
    }
    
    var llmFeatureEnabled: Bool {
        get { 
            // Default to true if not set
            return object(forKey: Keys.featureEnabled) as? Bool ?? true
        }
        set { set(newValue, forKey: Keys.featureEnabled) }
    }
    
    var llmAPIKey: String? {
        get { string(forKey: Keys.apiKey) }
        set { set(newValue, forKey: Keys.apiKey) }
    }
    
    var llmMaxTokens: Int {
        get { 
            let tokens = integer(forKey: Keys.maxTokens)
            return tokens == 0 ? LLMConfiguration.maxTokens : tokens
        }
        set { set(newValue, forKey: Keys.maxTokens) }
    }
    
    var llmAutoDetectModel: Bool {
        get { 
            // Default to true for automatic model detection
            return object(forKey: Keys.autoDetectModel) as? Bool ?? true
        }
        set { set(newValue, forKey: Keys.autoDetectModel) }
    }
    
    var llmStreamingEnabled: Bool {
        get { 
            // Default to true for streaming responses (recommended for Jan.ai)
            return object(forKey: Keys.streamingEnabled) as? Bool ?? LLMConfiguration.defaultStreamingEnabled
        }
        set { set(newValue, forKey: Keys.streamingEnabled) }
    }
}
