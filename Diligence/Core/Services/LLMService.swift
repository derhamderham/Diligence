//
//  LLMService.swift
//  Diligence
//
//  Created by Assistant on 10/30/25.
//

import Foundation
import Combine

@MainActor
class LLMService: LLMServiceProtocol, ObservableObject {
    
    // MARK: - Configuration
    
    /// Base URL for the LLM API (configurable)
    private var baseURL: String {
        return UserDefaults.standard.customLLMBaseURL ?? LLMConfiguration.janAIBaseURL
    }
    
    /// Current model name (configurable)
    private var modelName: String {
        return UserDefaults.standard.selectedLLMModel
    }
    
    /// Temperature setting (configurable)
    private var temperature: Double {
        return UserDefaults.standard.llmTemperature
    }
    
    /// API Key (configurable)
    private var apiKey: String? {
        return UserDefaults.standard.llmAPIKey
    }
    
    /// Max tokens (configurable)
    private var maxTokens: Int {
        return UserDefaults.standard.llmMaxTokens
    }
    
    /// Check if LLM feature is enabled
    private var isLLMFeatureEnabled: Bool {
        return UserDefaults.standard.llmFeatureEnabled
    }
    
    /// Check if streaming is enabled - force to true for this implementation
    private var isStreamingEnabled: Bool {
        return true // Always use streaming
    }
    
    // MARK: - Error Types
    
    enum LLMError: Error, LocalizedError {
        case invalidURL
        case noResponse
        case invalidResponse
        case networkError(Error)
        case serverError(Int, String)
        case modelNotAvailable
        case modelSessionNotFound(String)
        case requestTooLarge
        case featureDisabled
        case systemDatabaseError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API endpoint URL"
            case .noResponse:
                return "No response from LLM server"
            case .invalidResponse:
                return "Invalid response format from LLM"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .serverError(let code, let message):
                return "Server error (\(code)): \(message)"
            case .modelNotAvailable:
                return "The requested model is not available"
            case .modelSessionNotFound(let modelId):
                return "No running session found for model: \(modelId). Please ensure the model is loaded in your LLM server."
            case .requestTooLarge:
                return "Request too large for the model's context window"
            case .featureDisabled:
                return "LLM feature is disabled in settings"
            case .systemDatabaseError(let error):
                return "System database access error: \(error.localizedDescription). This is usually a temporary macOS system issue."
            }
        }
    }
    
    // MARK: - Request/Response Models
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
        let maxTokens: Int
        let stream: Bool
        
        enum CodingKeys: String, CodingKey {
            case model, messages, temperature, stream
            case maxTokens = "max_tokens"
        }
    }
    
    struct ChatMessage: Codable {
        let role: String
        let content: String?
        
        init(role: String, content: String) {
            self.role = role
            self.content = content
        }
    }
    
    struct ChatResponse: Codable {
        let id: String?
        let object: String?
        let created: Int?
        let model: String?
        let choices: [Choice]
        let usage: Usage?
        
        struct Choice: Codable {
            let index: Int
            let message: ChatMessage?
            let delta: ChatMessage? // For streaming responses
            let finishReason: String?
            
            enum CodingKeys: String, CodingKey {
                case index, message, delta
                case finishReason = "finish_reason"
            }
        }
        
        struct Usage: Codable {
            let promptTokens: Int?
            let completionTokens: Int?
            let totalTokens: Int?
            
            enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
                case totalTokens = "total_tokens"
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Initialize the LLM service and detect current model if enabled
    func initialize() async {
        print("LLMService: Initializing...")
        
        do {
            // Add a small delay to avoid system contention during app launch
            try await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            if LLMConfiguration.shouldAutoDetectModel() {
                await detectAndSetCurrentModel()
            }
            print("LLMService: Initialization completed successfully")
        } catch {
            print("LLMService: Initialization encountered system delay: \(error)")
            // Continue with initialization even if there was a delay
            // Add additional delay if we encountered a system error
            try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            if LLMConfiguration.shouldAutoDetectModel() {
                await detectAndSetCurrentModel()
            }
            print("LLMService: Initialization completed with delay handling")
        }
    }
    
    /// Detect the current model from jan.ai and update settings
    func detectAndSetCurrentModel() async {
        if let detectedModel = await LLMConfiguration.detectCurrentModel(from: baseURL) {
            print("Detected and set current model: \(detectedModel)")
        } else {
            print("Failed to detect current model, using default: \(modelName)")
        }
    }
    
    /// Query emails using the local LLM
    /// - Parameters:
    ///   - query: User's natural language query
    ///   - emails: Array of emails to analyze
    /// - Returns: LLM's response as a string
    func queryEmails(query: String, emails: [ProcessedEmail]) async throws -> String {
        print("🔍 DEBUG: Starting queryEmails with query: \(String(query.prefix(100)))")
        
        // Check if feature is enabled
        guard isLLMFeatureEnabled else {
            print("🔍 DEBUG: LLM feature is disabled")
            throw LLMError.featureDisabled
        }
        
        // Limit emails to avoid token limits
        let limitedEmails = Array(emails.prefix(LLMConfiguration.maxEmailsPerRequest))
        print("🔍 DEBUG: Processing \(limitedEmails.count) emails")
        
        // Prepare the system prompt
        let systemPrompt = createSystemPrompt()
        
        // Prepare the email data with adaptive sizing
        let emailContext = prepareEmailContextWithSizing(limitedEmails, targetMaxSize: 40000) // ~40KB max
        print("🔍 DEBUG: Email context size: \(emailContext.count) characters")
        
        // Create the user message with query and context
        let userMessage = """
        User Query: \(query)
        
        Please provide a complete but succinct response. Be thorough while avoiding unnecessary verbosity.
        
        Email Data:
        \(emailContext)
        """
        
        // Prepare the request
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: userMessage)
        ]
        
        print("🔍 DEBUG: Prepared \(messages.count) messages, calling queryWithModelFallback")
        
        // Try the current model first, then fallback to alternatives
        do {
            let result = try await queryWithModelFallback(messages: messages)
            print("🔍 DEBUG: Successfully got result of length: \(result.count)")
            return result
        } catch {
            print("🔍 DEBUG: queryWithModelFallback failed: \(error)")
            throw error
        }
    }
    
    /// Query with automatic model fallback
    private func queryWithModelFallback(messages: [ChatMessage]) async throws -> String {
        // First, get models that are actually running
        let runningModels = await getRunningModels()
        
        // If no models are running, fall back to the configured models
        let modelsToTry: [String]
        if !runningModels.isEmpty {
            // Prioritize current model if it's running, otherwise use running models
            if runningModels.contains(modelName) {
                modelsToTry = [modelName] + runningModels.filter { $0 != modelName }
            } else {
                modelsToTry = runningModels
            }
        } else {
            // Fall back to configured models
            let availableModels = await getAvailableModelsFromServer()
            modelsToTry = [modelName] + availableModels.filter { $0 != modelName }
        }
        
        var lastError: Error?
        
        for model in modelsToTry {
            let request = ChatRequest(
                model: model,
                messages: messages,
                temperature: temperature,
                maxTokens: maxTokens,
                stream: isStreamingEnabled // Use streaming preference
            )
            
            do {
                let result = try await performChatRequest(request)
                
                // If we successfully used a different model, update the setting
                if model != modelName {
                    print("Successfully switched to model: \(model)")
                    safelyUpdateSelectedModel(model)
                }
                
                return result
            } catch let error as LLMError {
                lastError = error
                
                // If it's a model session not found error, try the next model
                if case .modelSessionNotFound(_) = error {
                    print("Model \(model) session not found, trying next available model...")
                    continue
                }
                
                // For other errors, break and throw
                throw error
            } catch {
                lastError = error
                print("Error with model \(model): \(error.localizedDescription)")
                continue
            }
        }
        
        // If we get here, all models failed
        throw lastError ?? LLMError.modelNotAvailable
    }
    
    /// Check if the LLM service is available and optionally update model
    func checkServiceAvailability(autoDetectModel: Bool = false) async -> Bool {
        guard isLLMFeatureEnabled else { return false }
        
        // Add a small delay to reduce system load
        try? await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Try IPv4 first, then fallback to localhost if needed
        let testURLs: [String]
        if baseURL.contains("localhost") || baseURL.contains("127.0.0.1") {
            let port = baseURL.components(separatedBy: ":").last?.components(separatedBy: "/").first ?? "1337"
            testURLs = [
                "http://127.0.0.1:\(port)/v1", // IPv4 first (preferred)
                baseURL.replacingOccurrences(of: "localhost", with: "127.0.0.1"), // Convert localhost to IPv4
                baseURL // Keep original as last resort
            ].reduce(into: []) { result, url in
                if !result.contains(url) {
                    result.append(url)
                }
            }
        } else {
            testURLs = [baseURL]
        }
        
        for testURL in testURLs {
            guard let url = URL(string: "\(testURL)/models") else { continue }
            
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 3.0 // Quick timeout for availability check
                
                // Add API key if available
                if let apiKey = apiKey, !apiKey.isEmpty {
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                }
                
                let (_, response) = try await URLSession.shared.data(for: request)
                if (response as? HTTPURLResponse)?.statusCode == 200 {
                    // Success! Update base URL if we're using a different one
                    if testURL != baseURL {
                        print("Connection successful using \(testURL) instead of \(baseURL)")
                        // Update UserDefaults temporarily for this session
                        safelyUpdateBaseURL(testURL)
                    }
                    
                    // Auto-detect model if requested
                    if autoDetectModel && LLMConfiguration.shouldAutoDetectModel() {
                        await detectAndSetCurrentModel()
                    }
                    
                    return true
                }
            } catch {
                print("LLM service availability check failed for \(testURL): \(error)")
                continue
            }
        }
        
        return false
    }
    
    /// Set the model name to use
    func setModel(_ model: String) {
        safelyUpdateSelectedModel(model)
    }
    
    /// Get available models
    func getAvailableModels() -> [String] {
        return LLMConfiguration.availableModels
    }
    
    /// Get available models from the server
    func getAvailableModelsFromServer() async -> [String] {
        if let serverModels = await LLMConfiguration.getAvailableModelsFromServer(from: baseURL) {
            return serverModels
        }
        return LLMConfiguration.availableModels
    }
    
    /// Get currently running/loaded models from the server
    func getRunningModels() async -> [String] {
        let effectiveBaseURL = UserDefaults.standard.customLLMBaseURL ?? baseURL
        guard let url = URL(string: "\(effectiveBaseURL)/models") else {
            return []
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            
            if let apiKey = apiKey, !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            
            // Try to parse the models response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let modelsArray = json["data"] as? [[String: Any]] {
                return modelsArray.compactMap { model in
                    model["id"] as? String
                }
            }
            
        } catch {
            print("Failed to fetch running models: \(error)")
        }
        
        return []
    }
    
    /// Check if a specific model is currently loaded/running
    func isModelRunning(_ modelId: String) async -> Bool {
        let runningModels = await getRunningModels()
        return runningModels.contains(modelId)
    }
    
    /// Manually refresh the current model detection
    func refreshCurrentModel() async -> String? {
        return await LLMConfiguration.detectCurrentModel(from: baseURL)
    }
    
    /// Force connection to use IPv4 (127.0.0.1) instead of localhost
    func forceIPv4Connection() {
        let currentBaseURL = UserDefaults.standard.customLLMBaseURL ?? LLMConfiguration.janAIBaseURL
        let ipv4URL = currentBaseURL.replacingOccurrences(of: "localhost", with: "127.0.0.1")
        safelyUpdateBaseURL(ipv4URL)
        print("Forced connection to IPv4: \(ipv4URL)")
    }
    
    /// Test method to debug Jan.ai response format
    func testParseResponse(testResponse: String) throws -> String {
        print("DEBUG: Testing response parsing with sample data")
        return try parseStreamingResponse(testResponse)
    }
    
    /// Debug method to get detailed information about the last request/response
    func debugLastResponse() {
        print("=== LLM SERVICE DEBUG INFO ===")
        print("Base URL: \(baseURL)")
        print("Model Name: \(modelName)")
        print("Streaming Enabled: true (always enabled)")
        print("Feature Enabled: \(isLLMFeatureEnabled)")
        print("Temperature: \(temperature)")
        print("Max Tokens: \(maxTokens)")
        print("API Key Set: \(apiKey != nil && !apiKey!.isEmpty)")
        print("=============================")
    }
    
    /// Get current configuration for debugging
    func getCurrentConfiguration() -> [String: Any] {
        return [
            "baseURL": baseURL,
            "modelName": modelName,
            "temperature": temperature,
            "maxTokens": maxTokens,
            "streamingEnabled": isStreamingEnabled,
            "featureEnabled": isLLMFeatureEnabled,
            "hasAPIKey": apiKey != nil && !apiKey!.isEmpty
        ]
    }
    
    /// Test method for simple streaming queries (for debugging)
    func testStreamingQuery() async throws -> String {
        let testMessages = [
            ChatMessage(role: "system", content: "You are a helpful assistant."),
            ChatMessage(role: "user", content: "Say hello and confirm that streaming is working properly.")
        ]
        
        return try await queryWithModelFallback(messages: testMessages)
    }
    
    // MARK: - Private Methods
    
    /// Safely set a UserDefaults value
    private func safelySetUserDefault<T>(_ value: T, forKey key: String, setter: (T) -> Void) {
        setter(value)
    }
    
    /// Safely update the selected LLM model
    private func safelyUpdateSelectedModel(_ model: String) {
        safelySetUserDefault(model, forKey: "selectedLLMModel") { newModel in
            UserDefaults.standard.selectedLLMModel = newModel
        }
    }
    
    /// Safely update the custom base URL
    private func safelyUpdateBaseURL(_ url: String) {
        safelySetUserDefault(url, forKey: "customLLMBaseURL") { newURL in
            UserDefaults.standard.customLLMBaseURL = newURL
        }
    }
    
    private func createSystemPrompt() -> String {
        return """
        You are an intelligent email assistant that helps users find and analyze information from their emails. 
        
        Your capabilities include:
        - Finding emails by sender, subject, date, or content
        - Summarizing email content
        - Extracting specific information like invoices, dates, or action items
        - Answering questions about email patterns and trends
        - Identifying important or urgent emails
        
        Guidelines:
        - Be succinct but thorough - provide complete answers without unnecessary verbosity
        - When referencing specific emails, include the subject and sender
        - If you can't find relevant information, clearly state that
        - For date-related queries, consider the email timestamps
        - Be helpful but don't make assumptions about information not present in the emails
        - Format your response in a user-friendly way, using bullet points or lists when appropriate
        - Keep your responses focused and to-the-point while ensuring all relevant information is included
        
        The user will provide you with their query followed by their email data.
        """
    }
    
    private func prepareEmailContext(_ emails: [ProcessedEmail]) -> String {
        return prepareEmailContextWithSizing(emails, targetMaxSize: nil)
    }
    
    private func prepareEmailContextWithSizing(_ emails: [ProcessedEmail], targetMaxSize: Int?) -> String {
        let emailData = emails.map { email in
            // Limit email body length to avoid token issues
            let bodyText = email.body.isEmpty ? email.snippet : email.body
            let truncatedBody = String(bodyText.prefix(LLMConfiguration.maxEmailBodyLength))
            
            var emailText = """
            ---
            Subject: \(email.subject)
            From: \(email.sender) (\(email.senderEmail))
            Date: \(formatDate(email.receivedDate))
            
            Body: \(truncatedBody)
            """
            
            // Add attachment information if enabled and present
            if LLMConfiguration.includeAttachmentInfo && !email.attachments.isEmpty {
                let attachmentList = email.attachments.map { attachment in
                    "- \(attachment.filename) (\(attachment.mimeType), \(formatFileSize(attachment.size)))"
                }.joined(separator: "\n")
                
                emailText += "\n\nAttachments:\n\(attachmentList)"
            }
            
            return emailText
        }
        
        let baseContext = """
        Total emails provided: \(emails.count)
        
        """
        
        // If we have a target max size, adaptively reduce content
        if let maxSize = targetMaxSize {
            var joinedData = emailData.joined(separator: "\n\n")
            let fullContext = baseContext + joinedData
            
            if fullContext.utf8.count > maxSize {
                print("Context too large (\(fullContext.utf8.count) bytes), reducing...")
                
                // Reduce email body length progressively
                var reducedBodyLength = LLMConfiguration.maxEmailBodyLength
                while reducedBodyLength > 500 && (baseContext + joinedData).utf8.count > maxSize {
                    reducedBodyLength = max(500, reducedBodyLength - 300)
                    
                    let reducedEmailData = emails.map { email in
                        let bodyText = email.body.isEmpty ? email.snippet : email.body
                        let truncatedBody = String(bodyText.prefix(reducedBodyLength))
                        
                        return """
                        ---
                        Subject: \(email.subject)
                        From: \(email.sender) (\(email.senderEmail))
                        Date: \(formatDate(email.receivedDate))
                        
                        Body: \(truncatedBody)
                        """
                    }
                    
                    joinedData = reducedEmailData.joined(separator: "\n\n")
                }
                
                print("Reduced context to \((baseContext + joinedData).utf8.count) bytes with body length \(reducedBodyLength)")
            }
            
            return baseContext + joinedData
        }
        
        return baseContext + emailData.joined(separator: "\n\n")
    }
    
    private func performChatRequest(_ request: ChatRequest) async throws -> String {
        // Use streaming based on user preference, defaulting to true for Jan.ai compatibility
        let streamingRequest = ChatRequest(
            model: request.model,
            messages: request.messages,
            temperature: request.temperature,
            maxTokens: request.maxTokens,
            stream: isStreamingEnabled
        )
        
        // Use the same base URL that was successful in checkServiceAvailability
        let effectiveBaseURL = UserDefaults.standard.customLLMBaseURL ?? baseURL
        
        guard let url = URL(string: "\(effectiveBaseURL)/chat/completions") else {
            throw LLMError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Always set application/json for Jan.ai compatibility
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add proper headers for streaming
        urlRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        urlRequest.setValue("keep-alive", forHTTPHeaderField: "Connection")
        urlRequest.timeoutInterval = LLMConfiguration.timeoutInterval
        
        // Add API key if available
        if let apiKey = apiKey, !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Encode the request
        let encoder = JSONEncoder()
        do {
            urlRequest.httpBody = try encoder.encode(streamingRequest)
        } catch {
            throw LLMError.networkError(error)
        }
        
        // Create a custom URLSession configuration to reduce system warnings
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false
        configuration.allowsConstrainedNetworkAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.networkServiceType = .default
        
        let customSession = URLSession(configuration: configuration)
        
        // Always use streaming for this implementation
        return try await performStreamingRequest(urlRequest, session: customSession)
    }
    
    private func performStreamingRequest(_ urlRequest: URLRequest, session: URLSession = URLSession.shared) async throws -> String {
        print("🔍 DEBUG: Starting streaming request to: \(urlRequest.url?.absoluteString ?? "unknown")")
        print("🔍 DEBUG: Request headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
        print("🔍 DEBUG: Streaming enabled: \(isStreamingEnabled)")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
            print("🔍 DEBUG: Successfully received response data")
        } catch {
            print("🔍 DEBUG: Network request failed: \(error)")
            // Check if it's a timeout error
            if let nsError = error as NSError?, nsError.code == NSURLErrorTimedOut {
                throw LLMError.networkError(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [
                    NSLocalizedDescriptionKey: "Request timed out. The request may be too large or the server may be overloaded."
                ]))
            }
            throw LLMError.networkError(error)
        }
        
        // Handle HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.noResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            // Check for specific model session not found error
            if errorMessage.contains("No running session found for model_id") {
                // Extract model ID from error message
                var modelId = "unknown"
                
                // Try to extract from error message first
                if let errorComponents = errorMessage.components(separatedBy: "model_id: ").last,
                   let extractedModelId = errorComponents.components(separatedBy: " ").first {
                    modelId = extractedModelId
                } else if let httpBody = urlRequest.httpBody {
                    // Fallback: try to extract from request body
                    do {
                        if let jsonObject = try JSONSerialization.jsonObject(with: httpBody) as? [String: Any],
                           let requestModelId = jsonObject["model"] as? String {
                            modelId = requestModelId
                        }
                    } catch {
                        // Keep "unknown" as fallback
                    }
                }
                
                throw LLMError.modelSessionNotFound(modelId)
            }
            
            // Check for request too large errors
            if httpResponse.statusCode == 400 && (errorMessage.contains("too large") || errorMessage.contains("context") || errorMessage.contains("tokens")) {
                throw LLMError.requestTooLarge
            }
            
            // Log detailed error information for debugging
            print("LLM API Error - Status: \(httpResponse.statusCode), Response: \(errorMessage)")
            
            throw LLMError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        // Parse streaming response
        guard let responseString = String(data: data, encoding: .utf8) else {
            print("🔍 DEBUG: Failed to decode response data as UTF-8")
            throw LLMError.invalidResponse
        }
        
        print("🔍 DEBUG: Raw response length: \(data.count) bytes")
        print("🔍 DEBUG: Response string length: \(responseString.count) characters")
        print("🔍 DEBUG: Response headers: \(httpResponse.allHeaderFields)")
        print("🔍 DEBUG: Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "none")")
        
        // Log a sample of the raw response for debugging
        print("🔍 DEBUG: Raw response sample (first 1000 chars): \(String(responseString.prefix(1000)))")
        
        do {
            let result = try parseStreamingResponse(responseString)
            print("🔍 DEBUG: Successfully parsed response, length: \(result.count)")
            return result
        } catch {
            print("🔍 DEBUG: Failed to parse streaming response: \(error)")
            throw error
        }
    }
    
    private func parseStreamingResponse(_ responseString: String) throws -> String {
        print("🔍 DEBUG: ===== STARTING STREAMING RESPONSE PARSING =====")
        print("🔍 DEBUG: Response length: \(responseString.count) characters")
        
        var content = ""
        var debugInfo: [String] = []
        
        // Log first and last parts for debugging
        let previewLength = min(500, responseString.count)
        print("🔍 DEBUG: First \(previewLength) chars: \(String(responseString.prefix(previewLength)))")
        
        if responseString.count > 500 {
            print("🔍 DEBUG: Last 200 chars: \(String(responseString.suffix(200)))")
        }
        
        // First, try to parse as complete JSON (non-streaming fallback)
        if let jsonData = responseString.data(using: .utf8) {
            do {
                let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: jsonData)
                if let firstChoice = chatResponse.choices.first,
                   let message = firstChoice.message,
                   let messageContent = message.content {
                    print("🔍 DEBUG: Successfully parsed as complete JSON response")
                    return messageContent
                }
            } catch {
                debugInfo.append("Not a complete JSON response: \(error)")
            }
        }
        
        // Parse as streaming format - Jan.ai typically sends newline-separated JSON objects
        let lines = responseString.components(separatedBy: .newlines)
        print("🔍 DEBUG: Processing \(lines.count) lines")
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty {
                continue
            }
            
            if lineIndex < 3 {
                print("🔍 DEBUG: Line \(lineIndex): '\(String(trimmedLine.prefix(100)))'")
            }
            
            var jsonString = trimmedLine
            
            // Handle Server-Sent Events format (data: prefix)
            if trimmedLine.hasPrefix("data: ") {
                jsonString = String(trimmedLine.dropFirst(6))
                
                // Skip [DONE] marker
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                    debugInfo.append("Found [DONE] marker at line \(lineIndex)")
                    break
                }
            }
            // Skip non-JSON SSE headers
            else if trimmedLine.hasPrefix("event:") || 
                    trimmedLine.hasPrefix("id:") || 
                    trimmedLine.hasPrefix("retry:") {
                continue
            }
            // Must look like JSON
            else if !trimmedLine.hasPrefix("{") || !trimmedLine.contains("}") {
                continue
            }
            
            // Try to parse the JSON
            guard let jsonData = jsonString.data(using: .utf8) else {
                debugInfo.append("Failed to convert line \(lineIndex) to data")
                continue
            }
            
            // Try structured parsing first
            do {
                let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: jsonData)
                
                if let firstChoice = chatResponse.choices.first {
                    var chunkContent = ""
                    
                    // Handle streaming delta format
                    if let delta = firstChoice.delta, let deltaContent = delta.content {
                        chunkContent = deltaContent
                        debugInfo.append("Extracted delta content: '\(String(deltaContent.prefix(50)))'")
                    }
                    // Handle complete message format
                    else if let message = firstChoice.message, let messageContent = message.content {
                        chunkContent = messageContent
                        debugInfo.append("Extracted message content: '\(String(messageContent.prefix(50)))'")
                    }
                    
                    content += chunkContent
                }
                
            } catch {
                // Fallback to manual JSON parsing
                debugInfo.append("Structured decode failed for line \(lineIndex), trying manual parsing")
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        if let choices = json["choices"] as? [[String: Any]],
                           let firstChoice = choices.first {
                            
                            var chunkContent = ""
                            
                            // Check delta format
                            if let delta = firstChoice["delta"] as? [String: Any],
                               let deltaContent = delta["content"] as? String {
                                chunkContent = deltaContent
                                debugInfo.append("Manual delta extraction: '\(String(deltaContent.prefix(50)))'")
                            }
                            // Check message format
                            else if let message = firstChoice["message"] as? [String: Any],
                                    let messageContent = message["content"] as? String {
                                chunkContent = messageContent
                                debugInfo.append("Manual message extraction: '\(String(messageContent.prefix(50)))'")
                            }
                            
                            content += chunkContent
                        }
                    }
                } catch {
                    debugInfo.append("Manual JSON parsing also failed for line \(lineIndex): \(error)")
                    continue
                }
            }
        }
        
        // Print debug information
        print("🔍 DEBUG: Parsing complete. Debug info:")
        for info in debugInfo.prefix(10) { // Limit debug output
            print("🔍 DEBUG: - \(info)")
        }
        
        let finalContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if finalContent.isEmpty {
            print("🔍 DEBUG: No content extracted. Full response for analysis:")
            print("🔍 DEBUG: \(responseString)")
            print("🔍 DEBUG: ==========================================")
            throw LLMError.invalidResponse
        }
        
        print("🔍 DEBUG: Successfully extracted \(finalContent.count) characters of content")
        print("🔍 DEBUG: Content preview: '\(String(finalContent.prefix(200)))'")
        print("🔍 DEBUG: Content ending: '\(String(finalContent.suffix(100)))'")
        
        // Check if response seems truncated (ends abruptly without punctuation)
        let lastChar = finalContent.last
        let seemsTruncated = lastChar != nil && 
                            ![".", "!", "?", ":", "\n"].contains(lastChar!) && 
                            finalContent.count > 100
        
        if seemsTruncated {
            print("🔍 DEBUG: WARNING - Response may be truncated (ends with '\(lastChar ?? Character(" "))')")
        }
        
        return finalContent
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}
