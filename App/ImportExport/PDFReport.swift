import UIKit

/// Dados de um relatório mensal, já calculados (sem SwiftData).
struct MonthlyReportData {
    struct Line {
        var date: Date
        var title: String
        var category: String
        var amountCents: Cents
        var kind: TransactionKind
    }
    var month: Date
    var flow: CashFlow
    var checking: Cents
    var vault: Cents
    var byCategory: [(name: String, total: Cents)]
    var lines: [Line]
}

enum PDFReport {
    static func render(_ data: MonthlyReportData) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let headFont = UIFont.boldSystemFont(ofSize: 13)
        let bodyFont = UIFont.systemFont(ofSize: 10)
        let monoFont = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)

        return renderer.pdfData { ctx in
            var y: CGFloat = 0
            func newPage() {
                ctx.beginPage()
                y = margin
            }
            func ensure(_ h: CGFloat) {
                if y + h > page.height - margin { newPage() }
            }
            func draw(_ text: String, font: UIFont, x: CGFloat, width: CGFloat, align: NSTextAlignment = .left, color: UIColor = .black) {
                let style = NSMutableParagraphStyle()
                style.alignment = align
                style.lineBreakMode = .byTruncatingTail
                (text as NSString).draw(in: CGRect(x: x, y: y, width: width, height: font.lineHeight + 2),
                                        withAttributes: [.font: font, .paragraphStyle: style, .foregroundColor: color])
            }
            let contentWidth = page.width - 2 * margin

            newPage()
            draw("Relatório mensal — \(DateFormat.month(data.month))", font: titleFont, x: margin, width: contentWidth)
            y += 30
            draw("Gerado em \(DateFormat.short(.now)) · Orçamento (dados locais)", font: bodyFont, x: margin, width: contentWidth, color: .darkGray)
            y += 24

            draw("Resumo", font: headFont, x: margin, width: contentWidth)
            y += 20
            let summary: [(String, Cents)] = [
                ("Receitas", data.flow.income), ("Despesas", data.flow.expense), ("Saldo do mês", data.flow.net),
                ("Saldo à ordem no fim do mês", data.checking), ("Cofre no fim do mês", data.vault),
            ]
            for (label, v) in summary {
                draw(label, font: bodyFont, x: margin, width: 300)
                draw(MoneyFormat.string(v), font: monoFont, x: margin + 300, width: contentWidth - 300, align: .right)
                y += 15
            }
            if data.flow.income > 0 {
                let bp = data.flow.net * 10_000 / data.flow.income
                draw("Taxa de poupança", font: bodyFont, x: margin, width: 300)
                draw("\(bp / 100),\(String(format: "%02d", abs(bp % 100))) %", font: monoFont, x: margin + 300, width: contentWidth - 300, align: .right)
                y += 15
            }
            y += 14

            draw("Despesas por categoria", font: headFont, x: margin, width: contentWidth)
            y += 20
            if data.byCategory.isEmpty {
                draw("Sem despesas.", font: bodyFont, x: margin, width: contentWidth, color: .darkGray)
                y += 15
            }
            for item in data.byCategory {
                ensure(15)
                draw(item.name, font: bodyFont, x: margin, width: 300)
                draw(MoneyFormat.string(item.total), font: monoFont, x: margin + 300, width: contentWidth - 300, align: .right)
                y += 15
            }
            y += 14

            ensure(40)
            draw("Transações (\(data.lines.count))", font: headFont, x: margin, width: contentWidth)
            y += 20
            for line in data.lines {
                ensure(14)
                draw(DateFormat.short(line.date), font: bodyFont, x: margin, width: 80)
                draw(line.title, font: bodyFont, x: margin + 82, width: 210)
                draw(line.category, font: bodyFont, x: margin + 296, width: 120, color: .darkGray)
                let sign: String
                switch line.kind {
                case .income, .vaultWithdrawal: sign = "+"
                case .expense, .vaultDeposit: sign = "−"
                }
                draw(sign + MoneyFormat.string(line.amountCents), font: monoFont, x: margin + 420, width: contentWidth - 420, align: .right,
                     color: line.kind == .income ? UIColor.systemGreen : .black)
                y += 14
            }
        }
    }
}
