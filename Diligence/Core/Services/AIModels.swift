//
//  AIModels.swift
//  Diligence
//
//  Shared models for AI services
//

import Foundation
import FoundationModels

// MARK: - Email Analysis Models

@Generable(description: "Email insights and analysis")
struct EmailInsights {
    @Guide(description: "List of urgent emails requiring immediate attention", .count(1...10))
    var urgentEmails: [String]
    
    @Guide(description: "Action items extracted from emails", .count(1...15))
    var actionItems: [String]
    
    @Guide(description: "Upcoming deadlines and important dates", .count(1...10))
    var upcomingDeadlines: [String]
    
    @Guide(description: "Key communications and important messages", .count(1...10))
    var importantCommunications: [String]
    
    @Guide(description: "Overall summary of email activity")
    var summary: String
}

@Generable(description: "Action item extracted from emails")
struct ActionItem {
    @Guide(description: "The specific action that needs to be taken")
    var task: String
    
    @Guide(description: "Who the action is for or who requested it")
    var assignee: String?
    
    @Guide(description: "When the action is due, if specified")
    var dueDate: String?
    
    @Guide(description: "Priority level: high, medium, or low")
    var priority: String
    
    @Guide(description: "Source email subject line")
    var sourceEmail: String
}

@Generable(description: "List of action items")
struct ActionItemList {
    @Guide(description: "Extracted action items", .count(1...20))
    var items: [ActionItem]
}

@Generable(description: "Email category classification")
struct EmailCategory {
    @Guide(description: "Primary category: work, personal, finance, travel, shopping, notifications, or other")
    var category: String
    
    @Guide(description: "Subcategory for more specific classification")
    var subcategory: String?
    
    @Guide(description: "Confidence level in the categorization: high, medium, or low")
    var confidence: String
    
    @Guide(description: "Brief explanation of why this category was chosen")
    var reasoning: String
}