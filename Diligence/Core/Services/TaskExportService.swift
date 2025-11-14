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

/// Simple data structure for section information (decoupled from SwiftData)
struct ExportSection {
    let id: String
    let title: String
    let sortOrder: Int
    
    init(id: String, title: String, sortOrder: Int) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
    }
}

/// Service for exporting tasks to Excel format with multiple sheets
struct TaskExportService {
    
    // MARK: - Export Format
    
    /// The format for exported files
    enum ExportFormat {
        case csv
        case xlsx      // Modern Office Open XML (not implemented - requires ZIP)
        case excelXML  // Excel 2003 XML (SpreadsheetML) - what we actually use
        
        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .xlsx: return "xlsx"
            case .excelXML: return "xml"  // Excel can open .xml files with SpreadsheetML
            }
        }
        
        var mimeType: String {
            switch self {
            case .csv: return "text/csv"
            case .xlsx: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            case .excelXML: return "application/vnd.ms-excel"
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
    
    /// Date formatter for filename: dd-MMM-yy format matching export format
    private static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yy"
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
    static func exportToExcel(tasks: [DiligenceTask], sections: [ExportSection]) throws -> (data: Data, filename: String) {
        print("📊 Starting Excel export...")
        print("   Tasks: \(tasks.count)")
        print("   Sections: \(sections.count)")
        
        // Debug: Print section details
        if sections.isEmpty {
            print("   ⚠️ WARNING: No sections provided!")
        } else {
            print("   Section details:")
            for section in sections {
                print("      - \(section.title) (ID: \(section.id), Sort: \(section.sortOrder))")
            }
        }
        
        // Filter tasks: only include incomplete tasks that are assigned to a section
        let filteredTasks = tasks.filter { $0.sectionID != nil && !$0.isCompleted }
        print("   Filtered tasks (incomplete with sections): \(filteredTasks.count)")
        
        // IMPORTANT: Deduplicate tasks by title and due date
        // This handles cases where Swift Data might have duplicate records
        var seenTasks = Set<String>()
        let uniqueTasks = filteredTasks.filter { task in
            // Create a unique key from title + due date + section + description
            let dueDateString = task.dueDate?.timeIntervalSince1970.description ?? "none"
            let sectionString = task.sectionID ?? "none"
            let amountString = task.amount?.description ?? "none"
            let key = "\(task.title)|\(dueDateString)|\(sectionString)|\(task.taskDescription)|\(amountString)"
            
            if seenTasks.contains(key) {
                print("   ⚠️ Skipping duplicate task: \(task.title)")
                return false
            }
            seenTasks.insert(key)
            return true
        }
        
        print("   Unique tasks after deduplication: \(uniqueTasks.count)")
        print("   Duplicates removed: \(filteredTasks.count - uniqueTasks.count)")
        
        // Check if there are any tasks to export after filtering
        guard !uniqueTasks.isEmpty else {
            print("❌ No incomplete tasks with sections to export")
            throw ExportError.noTasksInSections
        }
        
        // Generate Excel XML
        print("   Generating Excel XML...")
        let excelXML = generateExcelXML(from: uniqueTasks, sections: sections)
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
    static func exportToCSV(tasks: [DiligenceTask], sections: [ExportSection]) throws -> (data: Data, filename: String) {
        // Filter tasks: only include incomplete tasks that are assigned to a section
        let filteredTasks = tasks.filter { $0.sectionID != nil && !$0.isCompleted }
        
        // IMPORTANT: Deduplicate tasks by title and due date
        // This handles cases where Swift Data might have duplicate records
        var seenTasks = Set<String>()
        let uniqueTasks = filteredTasks.filter { task in
            // Create a unique key from title + due date + section + description
            let dueDateString = task.dueDate?.timeIntervalSince1970.description ?? "none"
            let sectionString = task.sectionID ?? "none"
            let amountString = task.amount?.description ?? "none"
            let key = "\(task.title)|\(dueDateString)|\(sectionString)|\(task.taskDescription)|\(amountString)"
            
            if seenTasks.contains(key) {
                print("⚠️ Skipping duplicate task: \(task.title)")
                return false
            }
            seenTasks.insert(key)
            return true
        }
        
        print("📊 Filtered: \(filteredTasks.count) incomplete tasks with sections")
        print("📊 Unique: \(uniqueTasks.count) tasks after deduplication")
        print("📊 Duplicates removed: \(filteredTasks.count - uniqueTasks.count)")
        
        // Check if there are any tasks to export after filtering
        guard !uniqueTasks.isEmpty else {
            throw ExportError.noTasksInSections
        }
        
        // Sort tasks by due date (tasks with due dates first, sorted earliest to latest, then tasks without due dates)
        let sortedTasks = uniqueTasks.sorted { task1, task2 in
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
    private static func generateExcelXML(from tasks: [DiligenceTask], sections: [ExportSection]) -> String {
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
   <Font ss:FontName="Avenir" ss:Size="11" ss:Color="#000000"/>
   <Interior/>
   <NumberFormat/>
   <Protection/>
  </Style>
  <Style ss:ID="Header">
   <Font ss:FontName="Avenir" ss:Size="11" ss:Bold="1" ss:Color="#FFFFFF"/>
   <Interior ss:Color="#4472C4" ss:Pattern="Solid"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="2" ss:Color="#000000"/>
   </Borders>
  </Style>
  <Style ss:ID="SectionHeader">
   <Font ss:FontName="Avenir" ss:Size="12" ss:Bold="1" ss:Color="#FFFFFF"/>
   <Interior ss:Color="#5B9BD5" ss:Pattern="Solid"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#000000"/>
   </Borders>
  </Style>
  <Style ss:ID="Currency">
   <Font ss:FontName="Avenir" ss:Size="11" ss:Color="#000000"/>
   <NumberFormat ss:Format="&quot;$&quot;#,##0.00"/>
   <Alignment ss:Horizontal="Right"/>
  </Style>
  <Style ss:ID="Date">
   <Font ss:FontName="Avenir" ss:Size="11" ss:Color="#000000"/>
   <NumberFormat ss:Format="dd-mmm-yy"/>
   <Alignment ss:Horizontal="Center"/>
  </Style>
  <Style ss:ID="TotalRow">
   <Font ss:FontName="Avenir" ss:Size="11" ss:Bold="1"/>
   <Interior ss:Color="#E7E6E6" ss:Pattern="Solid"/>
   <Borders>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="2"/>
   </Borders>
   <NumberFormat ss:Format="&quot;$&quot;#,##0.00"/>
  </Style>
  <Style ss:ID="TitleRow">
   <Font ss:FontName="Avenir" ss:Size="14" ss:Bold="1" ss:Color="#1F4E78"/>
   <Alignment ss:Horizontal="Left"/>
  </Style>
  <Style ss:ID="AlternateRow">
   <Font ss:FontName="Avenir" ss:Size="11" ss:Color="#000000"/>
   <Interior ss:Color="#F2F2F2" ss:Pattern="Solid"/>
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
        
        if sectionsWithTasks.isEmpty {
            print("   ⚠️ No sections found with tasks - only Summary tab will be created")
            
            // Debug: Show why no sections matched
            if sections.isEmpty {
                print("      Problem: No sections provided to export!")
            } else if tasks.filter({ $0.sectionID != nil }).isEmpty {
                print("      Problem: No tasks have section assignments!")
            } else {
                print("      Problem: Section IDs don't match!")
                print("      Available section IDs: \(sections.map { $0.id }.joined(separator: ", "))")
                print("      Task section IDs: \(Set(tasks.compactMap { $0.sectionID }).joined(separator: ", "))")
            }
        }
        
        for section in sectionsWithTasks {
            let sectionTasks = tasks.filter { $0.sectionID == section.id }
            print("      - Section: '\(section.title)' (\(section.id)) - \(sectionTasks.count) tasks")
            let worksheetXML = generateSectionWorksheet(section: section, tasks: sectionTasks)
            print("         Generated \(worksheetXML.count) characters of XML")
            xml += worksheetXML
        }
        
        xml += "</Workbook>\n"
        
        print("   XML generation complete")
        return xml
    }
    
    /// Calculates next Saturday (7-13 days away, not the upcoming Saturday)
    ///
    /// Returns the Saturday of NEXT week (not this week), at end of day.
    /// This ensures we always look 7-13 days ahead.
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
        // Sunday = day 0, Monday = day 1, ..., Saturday = day 6
        guard let nextSaturday = calendar.date(byAdding: .day, value: 6, to: startOfNextWeek),
              let endOfSaturday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: nextSaturday) else {
            return calendar.date(byAdding: .day, value: 14, to: now) ?? now
        }
        
        return endOfSaturday
    }
    
    /// Generates the summary worksheet with tasks due by next Saturday, grouped by section
    private static func generateSummaryWorksheet(tasks: [DiligenceTask], sections: [ExportSection], endOfNextWeek: Date) -> String {
        print("      📋 Generating summary worksheet...")
        print("         Input: \(tasks.count) tasks, \(sections.count) sections")
        print("         End of next week: \(endOfNextWeek)")
        
        var xml = " <Worksheet ss:Name=\"Summary - Due by Next Saturday\">\n"
        xml += "  <Table>\n"
        xml += "   <Column ss:Width=\"80\"/>\n"
        xml += "   <Column ss:Width=\"200\"/>\n"
        xml += "   <Column ss:Width=\"100\"/>\n"
        xml += "   <Column ss:Width=\"250\"/>\n"
        xml += "   <Column ss:Width=\"80\"/>\n"
        
        // Add title row with date range
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        xml += "   <Row ss:StyleID=\"TitleRow\">\n"
        xml += "    <Cell ss:MergeAcross=\"4\">\n"
        xml += "     <Data ss:Type=\"String\">Tasks Due by \(xmlEscape(dateFormatter.string(from: endOfNextWeek)))</Data>\n"
        xml += "    </Cell>\n"
        xml += "   </Row>\n"
        xml += "   <Row/>\n"
        
        // Filter tasks due by next Saturday
        let upcomingTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate <= endOfNextWeek && task.sectionID != nil && !task.isCompleted
        }
        
        print("      Summary tab: Found \(upcomingTasks.count) tasks due by \(endOfNextWeek)")
        if upcomingTasks.isEmpty {
            print("      ⚠️ No upcoming tasks found - Summary tab will be empty")
            print("         All tasks count: \(tasks.count)")
            print("         Tasks with due dates: \(tasks.filter { $0.dueDate != nil }.count)")
            print("         Tasks with sections: \(tasks.filter { $0.sectionID != nil }.count)")
            print("         Incomplete tasks: \(tasks.filter { !$0.isCompleted }.count)")
            
            // Debug: Show a few sample tasks
            if tasks.count > 0 {
                print("         Sample tasks (first 3):")
                for (index, task) in tasks.prefix(3).enumerated() {
                    print("            \(index + 1). '\(task.title)'")
                    print("               - Due: \(task.dueDate?.description ?? "nil")")
                    print("               - Section: \(task.sectionID ?? "nil")")
                    print("               - Completed: \(task.isCompleted)")
                }
            }
        } else {
            print("         Sample upcoming tasks:")
            for (index, task) in upcomingTasks.prefix(3).enumerated() {
                print("            \(index + 1). '\(task.title)' - Due: \(task.dueDate!) - Section: \(task.sectionID ?? "nil")")
            }
        }
        
        // Group tasks by section
        let sortedSections = sections
            .filter { section in upcomingTasks.contains(where: { $0.sectionID == section.id }) }
            .sorted { $0.sortOrder < $1.sortOrder }
        
        print("      Sections in summary: \(sortedSections.count)")
        
        // Generate section groups
        for section in sortedSections {
            let sectionTasks = upcomingTasks
                .filter { $0.sectionID == section.id }
                .sorted { task1, task2 in
                    guard let date1 = task1.dueDate, let date2 = task2.dueDate else { return false }
                    return date1 < date2
                }
            
            guard !sectionTasks.isEmpty else { continue }
            
            // Section header
            xml += "   <Row ss:StyleID=\"SectionHeader\">\n"
            xml += "    <Cell ss:MergeAcross=\"4\">\n"
            xml += "     <Data ss:Type=\"String\">\(xmlEscape(section.title)) (\(sectionTasks.count) task\(sectionTasks.count == 1 ? "" : "s"))</Data>\n"
            xml += "    </Cell>\n"
            xml += "   </Row>\n"
            
            // Column headers for this section
            xml += "   <Row ss:StyleID=\"Header\">\n"
            xml += "    <Cell><Data ss:Type=\"String\">Due Date</Data></Cell>\n"
            xml += "    <Cell><Data ss:Type=\"String\">Name</Data></Cell>\n"
            xml += "    <Cell><Data ss:Type=\"String\">Amount</Data></Cell>\n"
            xml += "    <Cell><Data ss:Type=\"String\">Notes</Data></Cell>\n"
            xml += "    <Cell><Data ss:Type=\"String\">Priority</Data></Cell>\n"
            xml += "   </Row>\n"
            
            // Section tasks
            var sectionTotal: Double = 0
            for task in sectionTasks {
                xml += generateSummaryTaskRow(task: task)
                
                if let amount = task.amount, amount > 0 {
                    sectionTotal += amount
                }
            }
            
            // Section total
            if sectionTotal > 0 {
                xml += "   <Row ss:StyleID=\"TotalRow\">\n"
                xml += "    <Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell>\n"
                xml += "    <Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\">\(xmlEscape(section.title)) Total:</Data></Cell>\n"
                xml += "    <Cell ss:StyleID=\"TotalRow\" ss:Formula=\"=SUM(R[-\(sectionTasks.count)]C:R[-1]C)\"><Data ss:Type=\"Number\">\(sectionTotal)</Data></Cell>\n"
                xml += "    <Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell>\n"
                xml += "    <Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell>\n"
                xml += "   </Row>\n"
            }
            
            // Blank row between sections
            xml += "   <Row/>\n"
        }
        
        xml += "  </Table>\n"
        xml += " </Worksheet>\n"
        
        return xml
    }
    
    /// Generates a simplified task row for the summary sheet (without section column)
    private static func generateSummaryTaskRow(task: DiligenceTask) -> String {
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
        
        xml += "   </Row>\n"
        
        return xml
    }
    
    /// Generates a worksheet for a specific section
    private static func generateSectionWorksheet(section: ExportSection, tasks: [DiligenceTask]) -> String {
        // Sanitize sheet name (Excel has restrictions)
        let sheetName = sanitizeSheetName(section.title)
        
        var xml = " <Worksheet ss:Name=\"\(xmlEscape(sheetName))\">\n"
        xml += "  <Table>\n"
        xml += "   <Column ss:Width=\"80\"/>\n"
        xml += "   <Column ss:Width=\"250\"/>\n"
        xml += "   <Column ss:Width=\"100\"/>\n"
        xml += "   <Column ss:Width=\"300\"/>\n"
        xml += "   <Column ss:Width=\"80\"/>\n"
        
        // Title row with section name
        xml += "   <Row ss:StyleID=\"TitleRow\">\n"
        xml += "    <Cell ss:MergeAcross=\"4\">\n"
        xml += "     <Data ss:Type=\"String\">\(xmlEscape(section.title)) - All Tasks</Data>\n"
        xml += "    </Cell>\n"
        xml += "   </Row>\n"
        xml += "   <Row/>\n"
        
        // Header row
        xml += "   <Row ss:StyleID=\"Header\">\n"
        xml += "    <Cell><Data ss:Type=\"String\">Due Date</Data></Cell>\n"
        xml += "    <Cell><Data ss:Type=\"String\">Name</Data></Cell>\n"
        xml += "    <Cell><Data ss:Type=\"String\">Amount</Data></Cell>\n"
        xml += "    <Cell><Data ss:Type=\"String\">Notes</Data></Cell>\n"
        xml += "    <Cell><Data ss:Type=\"String\">Priority</Data></Cell>\n"
        xml += "   </Row>\n"
        
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
        var taskCount = 0
        for task in sortedTasks {
            xml += generateTaskRow(task: task, sections: [], includeSection: false)
            if let amount = task.amount, amount > 0 {
                sectionTotal += amount
            }
            taskCount += 1
        }
        
        // Summary rows
        xml += "   <Row/>\n"
        xml += "   <Row>\n"
        xml += "    <Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\">Total Tasks:</Data></Cell>\n"
        xml += "    <Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\">\(taskCount)</Data></Cell>\n"
        
        if sectionTotal > 0 {
            xml += "    <Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"Number\">\(sectionTotal)</Data></Cell>\n"
        } else {
            xml += "    <Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell>\n"
        }
        
        xml += "    <Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell>\n"
        xml += "    <Cell ss:StyleID=\"TotalRow\"><Data ss:Type=\"String\"></Data></Cell>\n"
        xml += "   </Row>\n"
        xml += "  </Table>\n"
        xml += " </Worksheet>\n"
        
        return xml
    }
    
    /// Generates a task row in Excel XML format
    private static func generateTaskRow(task: DiligenceTask, sections: [ExportSection], includeSection: Bool = true) -> String {
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
        
        // Section (only if requested, for cross-section views)
        if includeSection {
            let sectionName = formatSection(task.sectionID, sections: sections)
            xml += "    <Cell><Data ss:Type=\"String\">\(xmlEscape(sectionName))</Data></Cell>\n"
        }
        
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
    private static func generateCSVString(from tasks: [DiligenceTask], sections: [ExportSection]) -> String {
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
    
    /// Formats an amount for display in CSV: $1234.56 format (no thousands separator to avoid breaking CSV)
    private static func formatAmountForDisplay(_ amount: Double?) -> String {
        guard let amount = amount, amount > 0 else {
            return ""
        }
        
        // Use simple format without thousands separator to avoid breaking CSV columns
        // The comma in $1,234.56 would split into two cells
        return String(format: "$%.2f", amount)
    }
    
    /// Formats section name from ID
    private static func formatSection(_ sectionID: String?, sections: [ExportSection]) -> String {
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
        // Use .xls extension for Excel XML format (better compatibility)
        if format == .xlsx {
            return "Tasks Export - \(timestamp).xls"
        }
        return "Tasks Export - \(timestamp).\(format.fileExtension)"
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
        // Try multiple save locations in order of preference
        let saveLocations: [(name: String, url: URL?)] = [
            ("Downloads", FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first),
            ("Documents", FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first),
            ("Desktop", FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first),
            ("Temporary", FileManager.default.temporaryDirectory)
        ]
        
        var fileURL: URL?
        var savedLocation = "unknown"
        
        // Try each location until one succeeds
        for (locationName, baseURL) in saveLocations {
            guard let directory = baseURL else { continue }
            
            let testURL = directory.appendingPathComponent(filename)
            print("📁 Attempting to save to \(locationName): \(testURL.path)")
            
            do {
                // Try to write file
                try data.write(to: testURL, options: .atomic)
                print("✅ File saved successfully to \(locationName): \(testURL.lastPathComponent)")
                fileURL = testURL
                savedLocation = locationName
                break
            } catch {
                print("⚠️ Failed to save to \(locationName): \(error.localizedDescription)")
                // Continue to next location
            }
        }
        
        // Check if we successfully saved anywhere
        guard let finalURL = fileURL else {
            print("❌ Failed to save file to any location")
            showErrorAlert(message: """
                Failed to create export file in any accessible location.
                
                This may be due to App Sandbox restrictions.
                
                Solution:
                1. In Xcode, select your project
                2. Go to Signing & Capabilities
                3. Add "User Selected File" capability under App Sandbox
                4. Or disable App Sandbox for development
                
                Error: Unable to write to Downloads, Documents, Desktop, or Temp folder
                """)
            return
        }
        
        print("📂 Final save location: \(savedLocation) - \(finalURL.path)")
        
        // Try to open with Microsoft Excel specifically
        let excelBundleID = "com.microsoft.Excel"
        
        // Check if Excel is installed
        if let excelURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: excelBundleID) {
            print("📊 Opening with Microsoft Excel...")
            // Open with Excel
            NSWorkspace.shared.open([finalURL], 
                                   withApplicationAt: excelURL,
                                   configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error = error {
                    print("❌ Failed to open in Excel: \(error)")
                    DispatchQueue.main.async {
                        showErrorAlert(message: "Failed to open in Excel: \(error.localizedDescription)\n\nFile saved to \(savedLocation) folder:\n\(filename)")
                    }
                } else {
                    print("✅ Successfully opened file in Excel - exported \(taskCount) task\(taskCount == 1 ? "" : "s")")
                    print("📂 Location: \(finalURL.path)")
                }
            }
        } else {
            // Excel not found - try to open with default handler
            print("⚠️ Microsoft Excel not found, opening with default application")
            if NSWorkspace.shared.open(finalURL) {
                print("✅ Successfully opened file with default application - exported \(taskCount) task\(taskCount == 1 ? "" : "s")")
                print("📂 Location: \(finalURL.path)")
            } else {
                print("❌ Failed to open file")
                showErrorAlert(message: "Could not open file. File saved to \(savedLocation) folder:\n\(finalURL.path)")
            }
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
            return "No incomplete tasks assigned to sections. Only incomplete tasks with a section can be exported."
        case .encodingFailed:
            return "Failed to encode export data"
        }
    }
}
