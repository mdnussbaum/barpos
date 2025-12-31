import Foundation

extension InventoryVM {

    // ✅ NEW: addLine with optional variant
    func addLine(product: Product, variant: SizeVariant? = nil) {
        mutateActiveTicket { ticket in
            // When variants exist, each variant is a separate line item
            if let variant = variant {
                // With variant: always create new line (Short and Tall don't stack)
                let line = OrderLine(id: UUID(), product: product, qty: 1, selectedVariant: variant)
                ticket.lines.append(line)
            } else {
                // Without variant: stack same products as before
                if let idx = ticket.lines.firstIndex(where: { 
                    $0.product.id == product.id && $0.selectedVariant == nil 
                }) {
                    var line = ticket.lines[idx]
                    line.qty += 1
                    ticket.lines[idx] = line
                } else {
                    let line = OrderLine(id: UUID(), product: product, qty: 1)
                    ticket.lines.append(line)
                }
            }
        }
    }

    func decrementLine(lineID: UUID) {
        mutateActiveTicket { ticket in
            if let idx = ticket.lines.firstIndex(where: { $0.id == lineID }) {
                var line = ticket.lines[idx]
                line.qty -= 1
                if line.qty <= 0 {
                    ticket.lines.remove(at: idx)
                } else {
                    ticket.lines[idx] = line
                }
            }
        }
    }

    func removeLine(lineID: UUID) {
        mutateActiveTicket { ticket in
            ticket.lines.removeAll { $0.id == lineID }
        }
    }
}

