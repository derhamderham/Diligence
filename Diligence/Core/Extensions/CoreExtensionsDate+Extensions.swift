//
//  Date+Extensions.swift
//  Diligence
//
//  Date formatting and manipulation utilities
//

import Foundation

// MARK: - Date Formatting Extensions

extension Date {
    /// Standard date formats used throughout the app
    struct Formats {
        /// Full date and time: "HH:mm:ss dd-MMM-yy"
        /// Example: "14:30:45 09-Nov-25"
        static let dateTime: String = "HH:mm:ss dd-MMM-yy"
        
        /// Date only: "dd-MMM-yy"
        /// Example: "09-Nov-25"
        static let dateOnly: String = "dd-MMM-yy"
        
        /// Time only: "HH:mm:ss"
        /// Example: "14:30:45"
        static let timeOnly: String = "HH:mm:ss"
        
        /// ISO 8601 format for API communication
        static let iso8601: String = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        /// Relative date format: "Today", "Yesterday", or date
        /// Example: "Today at 2:30 PM"
        static let relative: String = "relative"
    }
    
    /// Shared date formatters (cached for performance)
    private static var formatters: [String: DateFormatter] = [:]
    private static let formatterQueue = DispatchQueue(label: "com.diligence.dateformatter")
    
    /// Gets a cached date formatter for the given format string
    ///
    /// - Parameter format: The format string (e.g., "dd-MMM-yy")
    /// - Returns: A configured DateFormatter
    private static func formatter(for format: String) -> DateFormatter {
        formatterQueue.sync {
            if let existing = formatters[format] {
                return existing
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale.current
            formatters[format] = formatter
            return formatter
        }
    }
    
    // MARK: - Formatting Methods
    
    /// Formats the date as "HH:mm:ss dd-MMM-yy"
    ///
    /// - Returns: Formatted date string
    func toDateTime() -> String {
        return Date.formatter(for: Formats.dateTime).string(from: self)
    }
    
    /// Formats the date as "dd-MMM-yy"
    ///
    /// - Returns: Formatted date string
    func toDateOnly() -> String {
        return Date.formatter(for: Formats.dateOnly).string(from: self)
    }
    
    /// Formats the date as "HH:mm:ss"
    ///
    /// - Returns: Formatted time string
    func toTimeOnly() -> String {
        return Date.formatter(for: Formats.timeOnly).string(from: self)
    }
    
    /// Formats the date in ISO 8601 format
    ///
    /// - Returns: ISO 8601 formatted string
    func toISO8601() -> String {
        return Date.formatter(for: Formats.iso8601).string(from: self)
    }
    
    /// Formats the date with a custom format
    ///
    /// - Parameter format: Custom date format string
    /// - Returns: Formatted date string
    func format(_ format: String) -> String {
        return Date.formatter(for: format).string(from: self)
    }
    
    /// Returns a relative date string (e.g., "Today at 2:30 PM", "Yesterday", "Nov 7")
    ///
    /// - Returns: Relative date description
    func toRelative() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if today
        if calendar.isDateInToday(self) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            timeFormatter.dateStyle = .none
            return "Today at \(timeFormatter.string(from: self))"
        }
        
        // Check if yesterday
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }
        
        // Check if this week
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
           self > weekAgo {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE" // Day name
            return dayFormatter.string(from: self)
        }
        
        // Default to date only
        return toDateOnly()
    }
    
    // MARK: - Date Manipulation
    
    /// Adds days to the date
    ///
    /// - Parameter days: Number of days to add (can be negative)
    /// - Returns: New date with added days
    func addingDays(_ days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    /// Adds weeks to the date
    ///
    /// - Parameter weeks: Number of weeks to add (can be negative)
    /// - Returns: New date with added weeks
    func addingWeeks(_ weeks: Int) -> Date {
        return Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: self) ?? self
    }
    
    /// Adds months to the date
    ///
    /// - Parameter months: Number of months to add (can be negative)
    /// - Returns: New date with added months
    func addingMonths(_ months: Int) -> Date {
        return Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
    
    /// Adds years to the date
    ///
    /// - Parameter years: Number of years to add (can be negative)
    /// - Returns: New date with added years
    func addingYears(_ years: Int) -> Date {
        return Calendar.current.date(byAdding: .year, value: years, to: self) ?? self
    }
    
    // MARK: - Date Comparisons
    
    /// Returns true if the date is in the past
    var isPast: Bool {
        return self < Date()
    }
    
    /// Returns true if the date is in the future
    var isFuture: Bool {
        return self > Date()
    }
    
    /// Returns true if the date is today
    var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    /// Returns true if the date is tomorrow
    var isTomorrow: Bool {
        return Calendar.current.isDateInTomorrow(self)
    }
    
    /// Returns true if the date is yesterday
    var isYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }
    
    /// Returns true if the date is this week
    var isThisWeek: Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// Returns true if the date is this month
    var isThisMonth: Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, equalTo: Date(), toGranularity: .month)
    }
    
    /// Returns true if the date is this year
    var isThisYear: Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, equalTo: Date(), toGranularity: .year)
    }
    
    // MARK: - Date Components
    
    /// Returns the start of the day (00:00:00)
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    /// Returns the end of the day (23:59:59)
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
    
    /// Returns the start of the week
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    /// Returns the start of the month
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
    
    /// Returns the start of the year
    var startOfYear: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self)
        return calendar.date(from: components) ?? self
    }
    
    // MARK: - Parsing
    
    /// Creates a Date from a string using the specified format
    ///
    /// - Parameters:
    ///   - string: The date string to parse
    ///   - format: The format of the date string
    /// - Returns: Parsed Date, or nil if parsing fails
    static func from(_ string: String, format: String) -> Date? {
        return formatter(for: format).date(from: string)
    }
    
    /// Creates a Date from an ISO 8601 string
    ///
    /// - Parameter string: ISO 8601 formatted string
    /// - Returns: Parsed Date, or nil if parsing fails
    static func fromISO8601(_ string: String) -> Date? {
        return from(string, format: Formats.iso8601)
    }
    
    /// Creates a Date from Gmail's internal date format (milliseconds since epoch)
    ///
    /// - Parameter milliseconds: Milliseconds since Unix epoch
    /// - Returns: Date object
    static func fromGmailTimestamp(_ milliseconds: String) -> Date? {
        guard let ms = Double(milliseconds) else { return nil }
        return Date(timeIntervalSince1970: ms / 1000.0)
    }
}
