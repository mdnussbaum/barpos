import Foundation

extension InventoryVM {

    // ✅ NEW: addLine with optional variant
    func addLine(product: Product, variant: SizeVariant? = nil) {
        mutateActiveTicket { ticket in
            // For products with variants, we need to match both product AND variant
            if let variant = variant {
                // Check if this exact product+variant combo exists
                if let idx = ticket.lines.firstIndex(where: { 
                    $0.product.id == product.id && $0.selectedVariant?.id == variant.id 
                }) {
                    // Increment qty for this specific variant
                    var line = ticket.lines[idx]
                    line.qty += 1
                    ticket.lines[idx] = line
                } else {
                    // Create new line with variant
                    let line = OrderLine(id: UUID(), product: product, qty: 1, selectedVariant: variant)
                    ticket.lines.append(line)
                }
            } else {
                // Original behavior for non-variant products
                if let idx = ticket.lines.firstIndex(where: { 
                    $0.product.id == product.id && $0.selectedVariant == nil 
                }) {
                    // Increment qty if this product already exists on the ticket
                    var line = ticket.lines[idx]
                    line.qty += 1
                    ticket.lines[idx] = line
                } else {
                    // Otherwise create a new line
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

