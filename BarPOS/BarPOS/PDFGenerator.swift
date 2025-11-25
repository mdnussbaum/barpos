//
//  PDFGenerator.swift
//  BarPOS
//
//  Created by Michael Nussbaum on 11/21/25.
//


//
//  PDFGenerator.swift
//  BarPOS
//

import Foundation
import UIKit
import PDFKit

struct PDFGenerator {
    
    // MARK: - Shift Report PDF
    static func generateShiftReportPDF(report: ShiftReport, closedTabs: [CloseResult]) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "BarPOS",
            kCGPDFContextAuthor: report.bartenderName,
            kCGPDFContextTitle: "Shift Report - \(report.formattedDate)"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        // Page size: US Letter
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 40
            
            // Title
            yPosition = drawText("SHIFT REPORT", at: CGPoint(x: 40, y: yPosition), 
                                fontSize: 24, bold: true, in: pageRect)
            yPosition += 10
            
            // Bartender & Date
            yPosition = drawText(report.bartenderName, at: CGPoint(x: 40, y: yPosition), 
                                fontSize: 16, bold: true, in: pageRect)
            yPosition = drawText(report.formattedDate, at: CGPoint(x: 40, y: yPosition), 
                                fontSize: 14, bold: false, in: pageRect)
            yPosition = drawText("\(report.formattedStartTime) - \(report.formattedEndTime)", 
                                at: CGPoint(x: 40, y: yPosition), fontSize: 14, bold: false, in: pageRect)
            yPosition += 20
            
            // Divider
            yPosition = drawLine(at: yPosition, in: pageRect)
            yPosition += 15
            
            // Sales Summary
            yPosition = drawText("SALES SUMMARY", at: CGPoint(x: 40, y: yPosition), 
                                fontSize: 18, bold: true, in: pageRect)
            yPosition += 10
            
            yPosition = drawKeyValue("Tabs Closed:", value: "\(report.tabsCount)", 
                                    at: yPosition, in: pageRect)
            yPosition = drawKeyValue("Gross Sales:", value: report.grossSales.currencyString(), 
                                    at: yPosition, in: pageRect)
            yPosition = drawKeyValue("Net Sales:", value: report.netSales.currencyString(), 
                                    at: yPosition, in: pageRect)
            yPosition = drawKeyValue("Tax Collected:", value: report.taxCollected.currencyString(), 
                                    at: yPosition, in: pageRect)
            yPosition += 15
            
            // Payment Breakdown
            yPosition = drawText("PAYMENT BREAKDOWN", at: CGPoint(x: 40, y: yPosition), 
                                fontSize: 18, bold: true, in: pageRect)
            yPosition += 10
            
            yPosition = drawKeyValue("Cash:", value: report.cashSales.currencyString(), 
                                    at: yPosition, in: pageRect)
            yPosition = drawKeyValue("Card:", value: report.cardSales.currencyString(), 
                                    at: yPosition, in: pageRect)
            yPosition = drawKeyValue("Other:", value: report.otherSales.currencyString(), 
                                    at: yPosition, in: pageRect)
            yPosition += 15
            
            // Cash Reconciliation
            if let openingCash = report.openingCash, let closingCash = report.closingCash {
                yPosition = drawText("CASH RECONCILIATION", at: CGPoint(x: 40, y: yPosition), 
                                    fontSize: 18, bold: true, in: pageRect)
                yPosition += 10
                
                yPosition = drawKeyValue("Opening Cash:", value: openingCash.currencyString(), 
                                        at: yPosition, in: pageRect)
                yPosition = drawKeyValue("+ Cash Sales:", value: report.cashSales.currencyString(), 
                                        at: yPosition, in: pageRect)
                
                let expectedCash = openingCash + report.cashSales
                yPosition = drawKeyValue("Expected Cash:", value: expectedCash.currencyString(), 
                                        at: yPosition, in: pageRect)
                yPosition = drawKeyValue("Closing Cash:", value: closingCash.currencyString(), 
                                        at: yPosition, in: pageRect)
                
                let overShort = report.overShort
                                let color: UIColor = overShort >= 0 ? .systemGreen : .systemRed
                                yPosition = drawKeyValue("Over/Short:", value: overShort.currencyString(),
                                                        at: yPosition, in: pageRect, valueColor: color)
                
                yPosition += 15
            }
            
            // Flags
            if let note = report.flagNote {
                yPosition = drawText("⚠️ " + note, at: CGPoint(x: 40, y: yPosition), 
                                    fontSize: 12, bold: false, in: pageRect, color: .systemRed)
                yPosition += 15
            }
            
            // Top Items (if we have closed tabs)
            if !closedTabs.isEmpty {
                yPosition = drawLine(at: yPosition, in: pageRect)
                yPosition += 15
                
                yPosition = drawText("TOP ITEMS SOLD", at: CGPoint(x: 40, y: yPosition), 
                                    fontSize: 18, bold: true, in: pageRect)
                yPosition += 10
                
                let topItems = getTopItems(from: closedTabs, limit: 10)
                for item in topItems {
                    yPosition = drawKeyValue(item.name, value: "\(item.quantity) sold", 
                                            at: yPosition, in: pageRect, fontSize: 12)
                    if yPosition > 720 { break } // Page limit
                }
            }
        }
        
        // Save to temp directory
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "ShiftReport_\(report.formattedFileDate).pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving PDF: \(error)")
            return nil
        }
    }
    
    // MARK: - Helper Drawing Functions
    
    private static func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat, 
                                 bold: Bool, in rect: CGRect, color: UIColor = .black) -> CGFloat {
        let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(at: point)
        
        return point.y + fontSize + 8
    }
    
    private static func drawKeyValue(_ key: String, value: String, at yPosition: CGFloat, 
                                     in rect: CGRect, fontSize: CGFloat = 14, 
                                     valueColor: UIColor = .black) -> CGFloat {
        let keyFont = UIFont.systemFont(ofSize: fontSize)
        let valueFont = UIFont.boldSystemFont(ofSize: fontSize)
        
        let keyAttributes: [NSAttributedString.Key: Any] = [.font: keyFont, .foregroundColor: UIColor.black]
        let valueAttributes: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: valueColor]
        
        let keyString = NSAttributedString(string: key, attributes: keyAttributes)
        let valueString = NSAttributedString(string: value, attributes: valueAttributes)
        
        keyString.draw(at: CGPoint(x: 40, y: yPosition))
        valueString.draw(at: CGPoint(x: rect.width - 150, y: yPosition))
        
        return yPosition + fontSize + 8
    }
    
    private static func drawLine(at yPosition: CGFloat, in rect: CGRect) -> CGFloat {
        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(UIColor.lightGray.cgColor)
        context?.setLineWidth(1.0)
        context?.move(to: CGPoint(x: 40, y: yPosition))
        context?.addLine(to: CGPoint(x: rect.width - 40, y: yPosition))
        context?.strokePath()
        
        return yPosition + 5
    }
    
    private static func getTopItems(from tabs: [CloseResult], limit: Int) -> [(name: String, quantity: Int)] {
        var itemCounts: [String: Int] = [:]
        
        for tab in tabs {
            for line in tab.lines {
                itemCounts[line.productName, default: 0] += line.qty
            }
        }
        
        return itemCounts.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (name: $0.key, quantity: $0.value) }
    }
}

// MARK: - ShiftReport Extensions for Formatting
extension ShiftReport {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: startedAt)
    }
    
    var formattedFileDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.string(from: startedAt)
    }
    
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startedAt)
    }
    
    var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: endedAt)
    }
}
