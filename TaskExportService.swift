//
//  TaskExportService.swift
//  Diligence
//
//  Created on 11/12/25.
//  Service for exporting tasks to Excel format with multiple sheets
//

import Foundation
import AppKit
import SwiftData

/// Service for exporting tasks to Excel format with multiple sheets
struct TaskExportService {
    
    // MARK: - Export Format
    
    /// The format for exported files
    enum ExportFormat {
        case csv
        case xlsx
        
        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .xlsx: return "xlsx"
            }
        }
        
        var mimeType: String {
            switch self {
            case .csv: return "text/csv"
            case .xlsx: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            }
        }
    }
    
    // MARK: - Date Formatters
    
    /// Date formatter for export: dd-MMM-yy format (e.g., "13-Nov-25")
    private static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    /// Date-time formatter for filename: YYYY-MM-DD_HHmmss
    private static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    // MARK: - Export Methods
    
    /// Exports tasks to Excel format with multiple sheets
    ///
    /// Creates an Excel file with:
    /// - Summary sheet: Tasks due by end of next week with totals per section
    /// - One sheet per section with all tasks in that section
    ///
    /// - Parameters:
    ///   - tasks: Array of tasks to export
    ///   - sections: Array of sections for section name lookup
    /// - Returns: Tuple containing the Excel data and suggested filename
    /// - Throws: Export errors
    static func exportToExcel(tasks: [DiligenceTask], sections: [DiligenceTaskSection]) throws -> (data: Data, filename: String) {
        print("📊 Starting Excel export...")
        print("   Tasks: \(tasks.count)")
        print("   Sections: \(sections.count)")
        
        // Filter tasks: only include tasks that are assigned to a section
        let filteredTasks = tasks.filter { $0.sectionID != nil }
        print("   Filtered tasks (with sections): \(filteredTasks.count)")
        
        // Check if there are any tasks to export after filtering
        guard !filteredTasks.isEmpty else {
            print("❌ No tasks with sections to export")
            throw ExportError.noTasksInSections
        }
        
        // Generate Excel XML
        print("   Generating Excel XML...")
        let excelXML = generateExcelXML(from: filteredTasks, sections: sections)
        print("   XML generated successfully (\(excelXML.count) characters)")
        
        guard let data = excelXML.data(using: .utf8) else {
            print("❌ Failed to encode XML to UTF-8")
            throw ExportError.encodingFailed
        }
        
        let filename = generateFilename(format: .xlsx)
        print("✅ Export data ready: \(filename)")
        
        return (data, filename)
    }
    
    /// Legacy CSV export method (kept for backward compatibility)
    ///
    /// - Parameters:
    ///   - tasks: Array of tasks to export
    ///   - sections: Array of sections for section name lookup
    /// - Returns: Tuple containing the CSV data and suggested filename
    /// - Throws: Export errors
    static func exportToCSV(tasks: [DiligenceTask], sections: [DiligenceTaskSection]) throws -> (data: Data, filename: String) {
        // Filter tasks: only include tasks that are assigned to a section
        let filteredTasks = tasks.filter { $0.sectionID != nil }
        
        // Check if there are any tasks to export after filtering
        guard !filteredTasks.isEmpty else {
            throw ExportError.noTasksInSections
        }
        
        // Sort tasks by due date (tasks with due dates first, sorted earliest to latest, then tasks without due dates)
        let sortedTasks = filteredTasks.sorted { task1, task2 in
            switch (task1.dueDate, task2.dueDate) {
            case (let date1?, let date2?):
                // Both have due dates - sort by date (earliest first)
                return date1 < date2
            case (nil, _?):
                // task1 has no due date, task2 has due date - task2 comes first
                return false
            case (_?, nil):
                // task1 has due date, task2 has no due date - task1 comes first
                return true
            case (nil, nil):
                // Neither has due date - maintain original order (stable sort)
                return false
            }
        }
        
        let csvString = generateCSVString(from: sortedTasks, sections: sections)
        
        guard let data = csvString.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        let filename = generateFilename(format: .csv)
        
        return (data, filename)
    }
    
    // MARK: - Excel XML Generation
    
    /// Generates Excel XML format with multiple worksheets
    private static func generateExcelXML(from tasks: [DiligenceTask], sections: [DiligenceTaskSection]) -> String {
        var xml = """
        <?xml version="1.0"?>
        <?mso-application progid="Excel.Sheet"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
         xmlns:o="urn:schemas-microsoft-com:office:office"
         xmlns:x="urn:schemas-microsoft-com:office:excel"
         xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
         xmlns:html="http://www.w3.org/TR/REC-html40">
         <Styles>
          <Style ss:ID="Default" ss:Name="Normal">
           <Alignment ss:Vertical="Bottom"/>
           <Borders/>
           <Font ss:FontName="Calibri" ss:Size="11" ss:Color="#000000"/>
           <Interior/>
           <NumberFormat/>
           <Protection/>
          </Style>
          <Style ss:ID="Header">
           <Font ss:FontName="Calibri" ss:Size="11" ss:Bold="1"/>
           <Interior ss:Color="#D9D9D9" ss:Pattern="Solid"/>
          </Style>
          <Style ss:ID="Currency">
           <NumberFormat ss:Format="&quot;$&quot;#,##0.00"/>
          </Style>
          <Style ss:ID="Date">
           <NumberFormat ss:Format="dd-mmm-yy"/>
          </Style>
          <Style ss:ID="TotalRow">
           <Font ss:FontName="Calibri" ss:Size="11" ss:Bold="1"/>
           <Borders>
            <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="2"/>
           </Borders>
          </Style>
         </Styles>
        
        """
        
        print("   Calculating end of next week...")
        // Calculate end of next week
        let endOfNextWeek = calculateEndOfNextWeek()
        print("   End of next week: \(endOfNextWeek)")
        
        print("   Generating summary worksheet...")
        // Generate summary worksheet
        xml += generateSummaryWorksheet(tasks: tasks, sections: sections, endOfNextWeek: endOfNextWeek)
        
        print("   Generating section worksheets...")
        // Generate one worksheet per section
        let sectionsWithTasks = sections.filter { section in
            tasks.contains(where: { $0.sectionID == section.id })
        }.sorted { $0.sortOrder < $1.sortOrder }
        
        print("   Sections with tasks: \(sectionsWithTasks.count)")
        
        for section in sectionsWithTasks {
            print("      - Section: \(section.title)")
            let sectionTasks = tasks.filter { $0.sectionID == section.id }
            xml += generateSectionWorksheet(section: section, tasks: sectionTasks)
        }
        
        xml += """
        </Workbook>
        """
        
        print("   XML generation complete")
        return xml
    }
    
    /// Calculates the end of next week (Saturday at 23:59:59)
    private static func calculateEndOfNextWeek() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Get the start of next week (Sunday)
        guard let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let startOfNextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfThisWeek) else {
            // Fallback: 14 days from now
            return calendar.date(byAdding: .day, value: 14, to: now) ?? now
        }
        
        // Get Saturday of next week (day 6 after Sunday start)
        guard let endOfNextWeek = calendar.date(byAdding: .day, value: 6, to: startOfNextWeek),
              let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfNextWeek) else {
            return calendar.date(byAdding: .day, value: 14, to: now) ?? now
        }
        
        return endOfDay
    }
    
    /// Generates the summary worksheet with tasks due by end of next week
    private static func generateSummaryWorksheet(tasks: [DiligenceTask], sections: [DiligenceTaskSection], endOfNextWeek: Date) -> String {
        var xml = """
         <Worksheet ss:Name="Summary">
          <Table>
           <Column ss:Width="80"/>
           <Column ss:Width="200"/>
           <Column ss:Width="80"/>
           <Column ss:Width="200"/>
           <Column ss:Width="80"/>
           <Column ss:Width="120"/>
           <Column ss:Width="80"/>
        
        """
        
        // Header row
        xml += """
           <Row ss:StyleID="Header">
            <Cell><Data ss:Type="String">Due Date</Data></Cell>
            <Cell><Data ss:Type="String">Name</Data></Cell>
            <Cell><Data ss:Type="String">Amount</Data></Cell>
            <Cell><Data ss:Type="String">Notes</Data></Cell>
            <Cell><Data ss:Type="String">Priority</Data></Cell>
            <Cell><Data ss:Type="String">Section</Data></Cell>
            <Cell><Data ss:Type="String">Completed</Data></Cell>
           </Row>
        
        """
        
        // Filter tasks due by end of next week, sort by due date
        let upcomingTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate <= endOfNextWeek && task.sectionID != nil
        }.sorted { task1, task2 in
            guard let date1 = task1.dueDate, let date2 = task2.dueDate else { return false }
            return date1 < date2
        }
        
        // Track section totals
        var sectionTotals: [String: Double] = [:]
        
        // Data rows
        for task in upcomingTasks {
            xml += generateTaskRow(task: task, sections: sections)
            
            // Accumulate section total
            if let sectionID = task.sectionID, let amount = task.amount, amount > 0 {
                sectionTotals[sectionID, default: 0] += amount
            }
        }
        
        // Add section totals
        xml += """
           <Row/>
           <Row ss:StyleID="TotalRow">
            <Cell ss:Index="5"><Data ss:Type="String">Section Totals:</Data></Cell>
           </Row>
        
        """
        
        let sortedSections = sections
            .filter { sectionTotals[$0.id] != nil }
            .sorted { $0.sortOrder < $1.sortOrder }
        
        var grandTotal: Double = 0
        for section in sortedSections {
            let total = sectionTotals[section.id] ?? 0
            grandTotal += total
            xml += """
               <Row>
                <Cell ss:Index="5"><Data ss:Type="String">\(xmlEscape(section.title))</Data></Cell>
                <Cell ss:StyleID="Currency"><Data ss:Type="Number">\(total)</Data></Cell>
               </Row>
            
            """
        }
        
        // Grand total
        xml += """
           <Row ss:StyleID="TotalRow">
            <Cell ss:Index="5"><Data ss:Type="String">Grand Total:</Data></Cell>
            <Cell ss:StyleID="Currency"><Data ss:Type="Number">\(grandTotal)</Data></Cell>
           </Row>
        
        """
        
        xml += """
          </Table>
         </Worksheet>
        
        """
        
        return xml
    }
    
    /// Generates a worksheet for a specific section
    private static func generateSectionWorksheet(section: DiligenceTaskSection, tasks: [DiligenceTask]) -> String {
        // Sanitize sheet name (Excel has restrictions)
        let sheetName = sanitizeSheetName(section.title)
        
        var xml = """
         <Worksheet ss:Name="\(xmlEscape(sheetName))">
          <Table>
           <Column ss:Width="80"/>
           <Column ss:Width="200"/>
           <Column ss:Width="80"/>
           <Column ss:Width="200"/>
           <Column ss:Width="80"/>
           <Column ss:Width="80"/>
        
        """
        
        // Header row
        xml += """
           <Row ss:StyleID="Header">
            <Cell><Data ss:Type="String">Due Date</Data></Cell>
            <Cell><Data ss:Type="String">Name</Data></Cell>
            <Cell><Data ss:Type="String">Amount</Data></Cell>
            <Cell><Data ss:Type="String">Notes</Data></Cell>
            <Cell><Data ss:Type="String">Priority</Data></Cell>
            <Cell><Data ss:Type="String">Completed</Data></Cell>
           </Row>
        
        """
        
        // Sort tasks by due date
        let sortedTasks = tasks.sorted { task1, task2 in
            switch (task1.dueDate, task2.dueDate) {
            case (let date1?, let date2?):
                return date1 < date2
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            case (nil, nil):
                return false
            }
        }
        
        // Data rows
        var sectionTotal: Double = 0
        for task in sortedTasks {
            xml += generateTaskRow(task: task, sections: [], includeSection: false)
            if let amount = task.amount, amount > 0 {
                sectionTotal += amount
            }
        }
        
        // Section total
        if sectionTotal > 0 {
            xml += """
               <Row/>
               <Row ss:StyleID="TotalRow">
                <Cell ss:Index="2"><Data ss:Type="String">Total:</Data></Cell>
                <Cell ss:StyleID="Currency"><Data ss:Type="Number">\(sectionTotal)</Data></Cell>
               </Row>
            
            """
        }
        
        xml += """
          </Table>
         </Worksheet>
        
        """
        
        return xml
    }
    
    /// Generates a task row in Excel XML format
    private static func generateTaskRow(task: DiligenceTask, sections: [DiligenceTaskSection], includeSection: Bool = true) -> String {
        var xml = "   <Row>\n"
        
        // Due Date
        if let dueDate = task.dueDate {
            let dateString = xmlEscape(exportDateFormatter.string(from: dueDate))
            xml += "    <Cell ss:StyleID=\"Date\"><Data ss:Type=\"String\">\(dateString)</Data></Cell>\n"
        } else {
            xml += "    <Cell><Data ss:Type=\"String\"></Data></Cell>\n"
        }
        
        // Name
        xml += "    <Cell><Data ss:Type=\"String\">\(xmlEscape(task.title))</Data></Cell>\n"
        
        // Amount
        if let amount = task.amount, amount > 0 {
            xml += "    <Cell ss:StyleID=\"Currency\"><Data ss:Type=\"Number\">\(amount)</Data></Cell>\n"
        } else {
            xml += "    <Cell><Data ss:Type=\"String\"></Data></Cell>\n"
        }
        
        // Notes
        xml += "    <Cell><Data ss:Type=\"String\">\(xmlEscape(task.taskDescription))</Data></Cell>\n"
        
        // Priority
        xml += "    <Cell><Data ss:Type=\"String\">\(xmlEscape(formatPriority(task.priority)))</Data></Cell>\n"
        
        // Section (only for summary sheet)
        if includeSection {
            let sectionName = formatSection(task.sectionID, sections: sections)
            xml += "    <Cell><Data ss:Type=\"String\">\(xmlEscape(sectionName))</Data></Cell>\n"
        }
        
        // Completed
        xml += "    <Cell><Data ss:Type=\"String\">\(task.isCompleted ? "Yes" : "No")</Data></Cell>\n"
        
        xml += "   </Row>\n"
        
        return xml
    }
    
    /// Sanitizes a sheet name for Excel compatibility
    private static func sanitizeSheetName(_ name: String) -> String {
        // Excel sheet name restrictions:
        // - Max 31 characters
        // - Cannot contain: \ / ? * [ ]
        // - Cannot be blank
        var sanitized = name
            .replacingOccurrences(of: "\\", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "[", with: "(")
            .replacingOccurrences(of: "]", with: ")")
        
        if sanitized.count > 31 {
            sanitized = String(sanitized.prefix(31))
        }
        
        if sanitized.isEmpty {
            sanitized = "Sheet"
        }
        
        return sanitized
    }
    
    /// Escapes special XML characters
    private static func xmlEscape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    // MARK: - CSV Generation
    
    /// Generates CSV string from tasks
    private static func generateCSVString(from tasks: [DiligenceTask], sections: [DiligenceTaskSection]) -> String {
        var csvLines: [String] = []
        
        // Header row (removed "Created Date")
        let headers = ["Due Date", "Name", "Amount", "Notes", "Priority", "Section", "Completed"]
        csvLines.append(headers.map { escapeCSVField($0) }.joined(separator: ","))
        
        // Data rows
        for task in tasks {
            let row = [
                formatDueDate(task.dueDate),
                escapeCSVField(task.title),
                formatAmountForDisplay(task.amount),
                escapeCSVField(task.taskDescription),
                formatPriority(task.priority),
                formatSection(task.sectionID, sections: sections),
                task.isCompleted ? "Yes" : "No"
            ]
            csvLines.append(row.joined(separator: ","))
        }
        
        return csvLines.joined(separator: "\n")
    }
    
    // MARK: - Formatting Helpers
    
    /// Currency formatter for display: $1,234.56 format
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    /// Formats a due date for export
    private static func formatDueDate(_ date: Date?) -> String {
        guard let date = date else {
            return ""
        }
        return exportDateFormatter.string(from: date)
    }
    
    /// Formats an amount for export (plain number, used internally)
    private static func formatAmount(_ amount: Double?) -> String {
        guard let amount = amount, amount > 0 else {
            return ""
        }
        
        // Format with 2 decimal places, no currency symbol for better compatibility
        return String(format: "%.2f", amount)
    }
    
    /// Formats an amount for display in CSV: $1,234.56 format
    private static func formatAmountForDisplay(_ amount: Double?) -> String {
        guard let amount = amount, amount > 0 else {
            return ""
        }
        
        return currencyFormatter.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }
    
    /// Formats section name from ID
    private static func formatSection(_ sectionID: String?, sections: [DiligenceTaskSection]) -> String {
        guard let sectionID = sectionID,
              let section = sections.first(where: { $0.id == sectionID }) else {
            return ""
        }
        return section.title
    }
    
    /// Formats priority for export
    private static func formatPriority(_ priority: TaskPriority) -> String {
        // Use the raw value to determine priority name
        // Raw values: None=0, Low=1, Medium=2, High=3
        switch priority.rawValue {
        case 0: return "None"
        case 1: return "Low"
        case 2: return "Medium"
        case 3: return "High"
        default: return "Medium"
        }
    }
    
    /// Alternative: Format priority from raw value directly
    private static func formatPriorityFromRawValue(_ rawValue: Int) -> String {
        switch rawValue {
        case 0: return "None"
        case 1: return "Low"
        case 2: return "Medium"
        case 3: return "High"
        default: return "Medium"
        }
    }
    
    /// Escapes a CSV field value (handles commas, quotes, newlines)
    private static func escapeCSVField(_ field: String) -> String {
        // If field contains comma, quote, or newline, wrap in quotes and escape internal quotes
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
    
    /// Generates a filename with timestamp
    private static func generateFilename(format: ExportFormat) -> String {
        let timestamp = filenameDateFormatter.string(from: Date())
        return "Tasks_Export_\(timestamp).\(format.fileExtension)"
    }
    
    // MARK: - Excel Opening
    
    /// Opens the exported file directly in Microsoft Excel
    ///
    /// - Parameters:
    ///   - data: The file data (CSV or Excel XML)
    ///   - filename: The suggested filename
    ///   - taskCount: Number of tasks exported (for success message)
    @MainActor
    static func openInExcel(data: Data, filename: String, taskCount: Int = 0) {
        // Create file in temporary directory
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)
        
        do {
            // Write file
            try data.write(to: fileURL)
            
            // Try to open with Microsoft Excel specifically
            let excelBundleID = "com.microsoft.Excel"
            
            // Check if Excel is installed
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: excelBundleID) != nil {
                // Open with Excel
                NSWorkspace.shared.open([fileURL], 
                                       withApplicationAt: NSWorkspace.shared.urlForApplication(withBundleIdentifier: excelBundleID)!,
                                       configuration: NSWorkspace.OpenConfiguration()) { _, error in
                    if let error = error {
                        print("❌ Failed to open in Excel: \(error)")
                        DispatchQueue.main.async {
                            showErrorAlert(message: "Failed to open in Excel: \(error.localizedDescription)")
                        }
                    } else {
                        print("✅ Successfully opened file in Excel")
                        DispatchQueue.main.async {
                            showSuccessAlert(taskCount: taskCount)
                        }
                    }
                }
            } else {
                // Excel not found - try to open with default handler
                print("⚠️ Microsoft Excel not found, opening with default application")
                if NSWorkspace.shared.open(fileURL) {
                    print("✅ Successfully opened file with default application")
                    showSuccessAlert(taskCount: taskCount)
                } else {
                    print("❌ Failed to open file")
                    showErrorAlert(message: "Could not open file. Microsoft Excel may not be installed.")
                }
            }
        } catch {
            print("❌ Failed to write temporary file: \(error)")
            showErrorAlert(message: "Failed to create export file: \(error.localizedDescription)")
        }
    }
    
    /// Shows an error alert
    @MainActor
    private static func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Export Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Shows a success alert
    @MainActor
    static func showSuccessAlert(taskCount: Int) {
        let alert = NSAlert()
        alert.messageText = "Export Successful"
        alert.informativeText = "Successfully exported \(taskCount) task\(taskCount == 1 ? "" : "s")."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Export Error

enum ExportError: LocalizedError {
    case noTasks
    case noTasksInSections
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .noTasks:
            return "No tasks to export"
        case .noTasksInSections:
            return "No tasks assigned to sections. Only tasks with a section can be exported."
        case .encodingFailed:
            return "Failed to encode export data"
        }
    }
}
