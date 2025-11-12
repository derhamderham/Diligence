//
//  TaskSearchParser.swift
//  Diligence
//
//  Advanced search query parser with powerful syntax support
//  Created by Assistant on 11/12/25.
//

import Foundation
import SwiftData

// MARK: - Search Query Model

/// Represents a parsed search query with operators and filters
struct SearchQuery {
    var terms: [SearchTerm] = []
    var fieldFilters: [FieldFilter] = []
    var isEmpty: Bool {
        return terms.isEmpty && fieldFilters.isEmpty
    }
}

/// Individual search term with operator
struct SearchTerm {
    enum Operator {
        case and
        case or
        case not
    }
    
    let text: String
    let isExactPhrase: Bool
    let isWildcard: Bool
    let `operator`: Operator
    
    init(text: String, isExactPhrase: Bool = false, isWildcard: Bool = false, operator: Operator = .and) {
        self.text = text
        self.isExactPhrase = isExactPhrase
        self.isWildcard = isWildcard
        self.operator = `operator`
    }
}

/// Field-specific filter for advanced searches
struct FieldFilter {
    enum Field {
        case title
        case description
        case amount
        case section
        case priority
        case status
        case dueDate
    }
    
    enum Comparison {
        case equals
        case contains
        case greaterThan
        case lessThan
        case greaterOrEqual
        case lessOrEqual
    }
    
    let field: Field
    let comparison: Comparison
    let value: String
}

// MARK: - Search Query Parser

/// Parses search strings with advanced syntax into structured queries
class TaskSearchParser {
    
    /// Parse a search string into a structured query
    /// 
    /// Supports:
    /// - AND operator: `payroll tax` or `payroll AND tax`
    /// - OR operator: `payroll OR invoice`
    /// - NOT operator: `payroll NOT tax` or `-tax`
    /// - Exact phrase: `"payroll tax"`
    /// - Wildcards: `pay*` (prefix match)
    /// - Field-specific: `title:payroll`, `amount:>5000`, `priority:high`
    ///
    /// - Parameter searchText: The raw search string from the user
    /// - Returns: A structured SearchQuery object
    static func parse(_ searchText: String) -> SearchQuery {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SearchQuery()
        }
        
        var query = SearchQuery()
        var currentPosition = trimmed.startIndex
        var currentOperator: SearchTerm.Operator = .and
        
        while currentPosition < trimmed.endIndex {
            // Skip whitespace
            while currentPosition < trimmed.endIndex && trimmed[currentPosition].isWhitespace {
                currentPosition = trimmed.index(after: currentPosition)
            }
            
            guard currentPosition < trimmed.endIndex else { break }
            
            // Check for operators
            if let (op, newPos) = parseOperator(in: trimmed, at: currentPosition) {
                currentOperator = op
                currentPosition = newPos
                continue
            }
            
            // Check for exact phrase (quoted text)
            if trimmed[currentPosition] == "\"" {
                if let (phrase, newPos) = parseQuotedPhrase(in: trimmed, at: currentPosition) {
                    query.terms.append(SearchTerm(text: phrase, isExactPhrase: true, operator: currentOperator))
                    currentPosition = newPos
                    currentOperator = .and // Reset to default
                    continue
                }
            }
            
            // Parse next word/term
            if let (word, newPos) = parseWord(in: trimmed, at: currentPosition) {
                // Check if it's a field filter
                if let fieldFilter = parseFieldFilter(word) {
                    query.fieldFilters.append(fieldFilter)
                } else {
                    // Check for NOT prefix
                    var term = word
                    var termOperator = currentOperator
                    
                    if word.hasPrefix("-") {
                        term = String(word.dropFirst())
                        termOperator = .not
                    }
                    
                    // Check for wildcard
                    let isWildcard = term.hasSuffix("*")
                    if isWildcard {
                        term = String(term.dropLast())
                    }
                    
                    if !term.isEmpty {
                        query.terms.append(SearchTerm(text: term, isWildcard: isWildcard, operator: termOperator))
                    }
                }
                
                currentPosition = newPos
                currentOperator = .and // Reset to default
            } else {
                // Unable to parse, skip character
                currentPosition = trimmed.index(after: currentPosition)
            }
        }
        
        return query
    }
    
    // MARK: - Private Parsing Helpers
    
    private static func parseOperator(in text: String, at position: String.Index) -> (SearchTerm.Operator, String.Index)? {
        // Look for "AND", "OR", "NOT" keywords
        let remaining = String(text[position...])
        
        if remaining.uppercased().hasPrefix("AND") {
            let endIndex = text.index(position, offsetBy: 3, limitedBy: text.endIndex) ?? text.endIndex
            return (.and, endIndex)
        }
        
        if remaining.uppercased().hasPrefix("OR") {
            let endIndex = text.index(position, offsetBy: 2, limitedBy: text.endIndex) ?? text.endIndex
            return (.or, endIndex)
        }
        
        if remaining.uppercased().hasPrefix("NOT") {
            let endIndex = text.index(position, offsetBy: 3, limitedBy: text.endIndex) ?? text.endIndex
            return (.not, endIndex)
        }
        
        return nil
    }
    
    private static func parseQuotedPhrase(in text: String, at position: String.Index) -> (String, String.Index)? {
        guard text[position] == "\"" else { return nil }
        
        var currentPos = text.index(after: position)
        var phrase = ""
        
        while currentPos < text.endIndex {
            let char = text[currentPos]
            if char == "\"" {
                // Found closing quote
                let endPos = text.index(after: currentPos)
                return (phrase, endPos)
            }
            phrase.append(char)
            currentPos = text.index(after: currentPos)
        }
        
        // No closing quote found, return the phrase anyway
        return (phrase, text.endIndex)
    }
    
    private static func parseWord(in text: String, at position: String.Index) -> (String, String.Index)? {
        var currentPos = position
        var word = ""
        
        while currentPos < text.endIndex {
            let char = text[currentPos]
            if char.isWhitespace {
                break
            }
            word.append(char)
            currentPos = text.index(after: currentPos)
        }
        
        guard !word.isEmpty else { return nil }
        return (word, currentPos)
    }
    
    private static func parseFieldFilter(_ word: String) -> FieldFilter? {
        // Check for field:value pattern
        guard word.contains(":") else { return nil }
        
        let parts = word.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        
        let fieldName = String(parts[0]).lowercased()
        let value = String(parts[1])
        
        // Determine field
        let field: FieldFilter.Field
        switch fieldName {
        case "title", "name":
            field = .title
        case "desc", "description", "notes":
            field = .description
        case "amount", "price", "cost":
            field = .amount
        case "section", "category":
            field = .section
        case "priority":
            field = .priority
        case "status", "complete", "completed":
            field = .status
        case "due", "duedate", "date":
            field = .dueDate
        default:
            return nil
        }
        
        // Determine comparison operator and value
        var comparison: FieldFilter.Comparison = .contains
        var filterValue = value
        
        if value.hasPrefix(">") {
            comparison = value.hasPrefix(">=") ? .greaterOrEqual : .greaterThan
            filterValue = String(value.dropFirst(value.hasPrefix(">=") ? 2 : 1))
        } else if value.hasPrefix("<") {
            comparison = value.hasPrefix("<=") ? .lessOrEqual : .lessThan
            filterValue = String(value.dropFirst(value.hasPrefix("<=") ? 2 : 1))
        } else if value.hasPrefix("=") {
            comparison = .equals
            filterValue = String(value.dropFirst())
        }
        
        return FieldFilter(field: field, comparison: comparison, value: filterValue)
    }
}

// MARK: - Task Search Filter

/// Filters tasks based on a parsed search query
class TaskSearchFilter {
    
    /// Check if a task matches the search query
    ///
    /// - Parameters:
    ///   - task: The task to evaluate
    ///   - query: The parsed search query
    ///   - sections: Array of sections for section name lookup
    /// - Returns: `true` if the task matches the query
    static func matches(task: DiligenceTask, query: SearchQuery, sections: [TaskSection] = []) -> Bool {
        // Empty query matches everything
        if query.isEmpty {
            return true
        }
        
        var matchesTerms = true
        var matchesFields = true
        
        // Evaluate search terms
        if !query.terms.isEmpty {
            matchesTerms = evaluateTerms(task: task, terms: query.terms, sections: sections)
        }
        
        // Evaluate field filters
        if !query.fieldFilters.isEmpty {
            matchesFields = evaluateFieldFilters(task: task, filters: query.fieldFilters, sections: sections)
        }
        
        return matchesTerms && matchesFields
    }
    
    // MARK: - Private Evaluation Helpers
    
    private static func evaluateTerms(task: DiligenceTask, terms: [SearchTerm], sections: [TaskSection]) -> Bool {
        var result = true
        var hasOr = false
        var orResult = false
        
        for term in terms {
            let termMatches = evaluateSingleTerm(task: task, term: term, sections: sections)
            
            switch term.operator {
            case .and:
                if hasOr {
                    // Complete the OR evaluation
                    result = result && orResult
                    hasOr = false
                    orResult = false
                }
                result = result && termMatches
                
            case .or:
                if !hasOr {
                    hasOr = true
                    orResult = result
                    result = true // Reset for next AND chain
                }
                orResult = orResult || termMatches
                
            case .not:
                if hasOr {
                    // Complete the OR evaluation
                    result = result && orResult
                    hasOr = false
                    orResult = false
                }
                result = result && !termMatches
            }
        }
        
        // Handle trailing OR
        if hasOr {
            result = result && orResult
        }
        
        return result
    }
    
    private static func evaluateSingleTerm(task: DiligenceTask, term: SearchTerm, sections: [TaskSection]) -> Bool {
        let searchText = term.text.lowercased()
        
        // Build searchable content
        var searchableContent = [
            task.title.lowercased(),
            task.taskDescription.lowercased()
        ]
        
        // Add email fields
        if let emailSubject = task.emailSubject {
            searchableContent.append(emailSubject.lowercased())
        }
        if let emailSender = task.emailSender {
            searchableContent.append(emailSender.lowercased())
        }
        
        // Add section name
        if let sectionID = task.sectionID,
           let section = sections.first(where: { $0.id == sectionID }) {
            searchableContent.append(section.title.lowercased())
        }
        
        // Add amount as string
        if let amount = task.amount {
            searchableContent.append(String(format: "%.2f", amount))
            searchableContent.append("$\(String(format: "%.2f", amount))")
        }
        
        // Add priority
        searchableContent.append(task.priority.displayName.lowercased())
        
        // Add status
        searchableContent.append(task.isCompleted ? "completed" : "incomplete")
        searchableContent.append(task.isCompleted ? "complete" : "todo")
        
        // Perform matching
        if term.isExactPhrase {
            // Exact phrase matching
            return searchableContent.contains { $0.contains(searchText) }
        } else if term.isWildcard {
            // Prefix matching for wildcards
            return searchableContent.contains { content in
                content.split(separator: " ").contains { $0.hasPrefix(searchText) }
            }
        } else {
            // Simple substring matching
            return searchableContent.contains { $0.contains(searchText) }
        }
    }
    
    private static func evaluateFieldFilters(task: DiligenceTask, filters: [FieldFilter], sections: [TaskSection]) -> Bool {
        for filter in filters {
            if !evaluateSingleFilter(task: task, filter: filter, sections: sections) {
                return false
            }
        }
        return true
    }
    
    private static func evaluateSingleFilter(task: DiligenceTask, filter: FieldFilter, sections: [TaskSection]) -> Bool {
        let filterValue = filter.value.lowercased()
        
        switch filter.field {
        case .title:
            return compareString(task.title.lowercased(), filter.comparison, filterValue)
            
        case .description:
            return compareString(task.taskDescription.lowercased(), filter.comparison, filterValue)
            
        case .amount:
            guard let amount = task.amount else { return false }
            return compareNumeric(amount, filter.comparison, filterValue)
            
        case .section:
            guard let sectionID = task.sectionID,
                  let section = sections.first(where: { $0.id == sectionID }) else {
                return filterValue == "none" || filterValue == "null"
            }
            return compareString(section.title.lowercased(), filter.comparison, filterValue)
            
        case .priority:
            let priorityName = task.priority.displayName.lowercased()
            return compareString(priorityName, filter.comparison, filterValue)
            
        case .status:
            let statusText = task.isCompleted ? "completed" : "incomplete"
            let altStatusText = task.isCompleted ? "complete" : "todo"
            return filterValue == statusText || filterValue == altStatusText
            
        case .dueDate:
            guard let dueDate = task.dueDate else { return false }
            return compareDates(dueDate, filter.comparison, filterValue)
        }
    }
    
    private static func compareString(_ value: String, _ comparison: FieldFilter.Comparison, _ target: String) -> Bool {
        switch comparison {
        case .equals:
            return value == target
        case .contains:
            return value.contains(target)
        default:
            return value.contains(target)
        }
    }
    
    private static func compareNumeric(_ value: Double, _ comparison: FieldFilter.Comparison, _ target: String) -> Bool {
        guard let targetValue = Double(target) else { return false }
        
        switch comparison {
        case .equals:
            return abs(value - targetValue) < 0.01 // Floating point comparison
        case .greaterThan:
            return value > targetValue
        case .lessThan:
            return value < targetValue
        case .greaterOrEqual:
            return value >= targetValue
        case .lessOrEqual:
            return value <= targetValue
        default:
            return false
        }
    }
    
    private static func compareDates(_ date: Date, _ comparison: FieldFilter.Comparison, _ target: String) -> Bool {
        // Support relative dates: "today", "tomorrow", "yesterday"
        let calendar = Calendar.current
        let targetDate: Date?
        
        switch target.lowercased() {
        case "today":
            targetDate = calendar.startOfDay(for: Date())
        case "tomorrow":
            targetDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
        case "yesterday":
            targetDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))
        default:
            // Try to parse as date string
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            targetDate = formatter.date(from: target)
        }
        
        guard let target = targetDate else { return false }
        
        switch comparison {
        case .equals:
            return calendar.isDate(date, inSameDayAs: target)
        case .greaterThan:
            return date > target
        case .lessThan:
            return date < target
        case .greaterOrEqual:
            return date >= target || calendar.isDate(date, inSameDayAs: target)
        case .lessOrEqual:
            return date <= target || calendar.isDate(date, inSameDayAs: target)
        default:
            return false
        }
    }
}

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
