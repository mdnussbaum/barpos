//
//  ReportExporter.swift
//  BarPOSv2
//
//  Created by Michael Nussbaum on 9/22/25.
//


import SwiftUI
import UIKit
import MessageUI

// MARK: - CSV
struct ReportExporter {
    static func csvData(for r: ShiftReport) -> Data {
        var rows: [String] = []
        func add(_ cols: [CustomStringConvertible]) {
            rows.append(cols.map { "\($0)".replacingOccurrences(of: ",", with: " ") }
                       .joined(separator: ","))
        }
        add(["Section","Field","Value"])
        add(["Bartender","Name", r.bartenderName])
        add(["Bartender","Started", r.startedAt])
        add(["Bartender","Ended", r.endedAt])

        add(["Sales","Tabs", r.tabsCount])
        add(["Sales","Net", r.netSales])
        add(["Sales","Tax", r.taxCollected])
        add(["Sales","Gross", r.grossSales])

        add(["Payments","Cash", r.cashSales])
        add(["Payments","Card", r.cardSales])
        add(["Payments","Other", r.otherSales])

        add(["Cash Recon","Opening", r.openingCash ?? 0])
        add(["Cash Recon","Expected", r.expectedCash])
        add(["Cash Recon","Closing", r.closingCash ?? 0])
        add(["Cash Recon","Over/Short", r.overShort])

        for t in r.tickets {
            add(["Ticket", t.tabName, t.total])
        }
        return rows.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    // MARK: - HTML (used for both printing and PDF)
    static func html(for r: ShiftReport) -> String {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        func money(_ d: Decimal?) -> String { (d ?? 0).currencyString() }
        let items = r.tickets.map {
            "<tr><td>\($0.tabName)</td><td style='text-align:right'>\($0.total.currencyString())</td><td style='text-align:right'>\(df.string(from: $0.closedAt))</td></tr>"
        }.joined()

        // Narrow receipt style (80mm thermal scales nicely)
        return """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body { font: -apple-system-body; }
          .wrap { width: 280pt; margin: 0 auto; }     /* ~80mm */
          h1 { font-size: 16pt; margin: 0 0 8pt 0; }
          section { margin: 8pt 0; }
          table { width: 100%; border-collapse: collapse; }
          td { padding: 2pt 0; vertical-align: top; }
          .mono { font-family: ui-monospace, Menlo, monospace; }
          .hr { border-top: 1px solid #ccc; margin: 6pt 0; }
          .r { text-align: right; }
          .ok { color: #008000; } .bad { color: #C00000; } .zero { color: #666; }
        </style>
        </head>
        <body>
        <div class="wrap">
          <h1>Shift Report</h1>

          <section>
            <div><strong>Bartender:</strong> \(r.bartenderName)</div>
            <div><strong>Started:</strong> \(df.string(from: r.startedAt))</div>
            <div><strong>Ended:</strong> \(df.string(from: r.endedAt))</div>
          </section>

          <div class="hr"></div>

          <section>
            <table>
              <tr><td>Tabs</td><td class="r mono">\(r.tabsCount)</td></tr>
              <tr><td>Net</td><td class="r mono">\(r.netSales.currencyString())</td></tr>
              <tr><td>Tax</td><td class="r mono">\(r.taxCollected.currencyString())</td></tr>
              <tr><td><strong>Gross</strong></td><td class="r mono"><strong>\(r.grossSales.currencyString())</strong></td></tr>
            </table>
          </section>

          <section>
            <table>
              <tr><td>Cash</td><td class="r mono">\(r.cashSales.currencyString())</td></tr>
              <tr><td>Card</td><td class="r mono">\(r.cardSales.currencyString())</td></tr>
              <tr><td>Other</td><td class="r mono">\(r.otherSales.currencyString())</td></tr>
            </table>
          </section>

          <div class="hr"></div>

          <section>
            <table>
              <tr><td>Opening Cash</td><td class="r mono">\(money(r.openingCash))</td></tr>
              <tr><td>Expected Cash</td><td class="r mono">\(r.expectedCash.currencyString())</td></tr>
              <tr><td>Closing Cash</td><td class="r mono">\(money(r.closingCash))</td></tr>
              <tr><td>Over / Short</td><td class="r mono \(r.overShort == 0 ? "zero" : (r.overShort > 0 ? "ok" : "bad"))">\((r.overShort).currencyString())</td></tr>
            </table>
          </section>

          <div class="hr"></div>

          <section>
            <div style="font-weight:600; margin-bottom:4pt">Closed Tickets (\(r.tickets.count))</div>
            <table>
              \(items)
            </table>
          </section>
        </div>
        </body>
        </html>
        """
    }

    // MARK: - Print (AirPrint sheet)
    static func presentPrint(html: String, jobName: String) {
        let fmt = UIMarkupTextPrintFormatter(markupText: html)
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = jobName
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printFormatter = fmt
        controller.present(animated: true, completionHandler: nil)
    }

    // MARK: - PDF (from HTML)
    static func writePDF(html: String, fileName: String = "ShiftReport.pdf") -> URL? {
        let fmt = UIMarkupTextPrintFormatter(markupText: html)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(fmt, startingAtPageAt: 0)

        // Receipt width ~ 280pt, dynamic height
        let pageWidth: CGFloat = 280
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: 1000) // height will expand across pages if needed
        renderer.setValue(pageRect, forKey: "paperRect")
        renderer.setValue(pageRect.insetBy(dx: 12, dy: 12), forKey: "printableRect")

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let pdf = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdf, .zero, nil)
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        do {
            try pdf.write(to: tmp, options: .atomic)
            return tmp
        } catch {
            return nil
        }
    }
}

// MARK: - SwiftUI mail composer wrapper (pre-filled email with attachments)
struct MailView: UIViewControllerRepresentable {
    var subject: String
    var to: [String] = []
    var body: String
    var attachments: [(data: Data, mimeType: String, fileName: String)] = []
    @Environment(\.dismiss) private var dismiss

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailView
        init(_ parent: MailView) { self.parent = parent }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) { self.parent.dismiss() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setSubject(subject)
        vc.setToRecipients(to)
        vc.setMessageBody(body, isHTML: false)
        for a in attachments {
            vc.addAttachmentData(a.data, mimeType: a.mimeType, fileName: a.fileName)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}