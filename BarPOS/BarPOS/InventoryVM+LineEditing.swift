import Foundation

extension InventoryVM {

    // ✅ NEW: addLine
    func addLine(product: Product) {
        mutateActiveTicket { ticket in
            if let idx = ticket.lines.firstIndex(where: { $0.product.id == product.id }) {
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
