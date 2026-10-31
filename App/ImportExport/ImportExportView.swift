import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ShareFile: Identifiable {
    let url: URL
    var id: URL { url }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct ImportExportView: View {
    private enum ImportKind { case csv, backup }

    @Environment(\.modelContext) private var context
    @Query(sort: \FinTransaction.date) private var transactions: [FinTransaction]
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]
    @AppStorage(SettingsKeys.openingBalance) private var openingBalance: Int = 0

    @State private var share: ShareFile?
    @State private var importing: ImportKind?
    @State private var csvPreview: CSVImportResult?
    @State private var pendingBackup: BackupDocument?
    @State private var message: String?
    @State private var reportMonth = Date.now

    var body: some View {
        Form {
            Section {
                Button { exportCSV() } label: { Label("Exportar transações (CSV)", systemImage: "tablecells") }
                Button { importing = .csv } label: { Label("Importar transações (CSV)", systemImage: "square.and.arrow.down") }
            } header: {
                Text("CSV")
            } footer: {
                Text("Separador “;”, valores como 12,50 e datas AAAA-MM-DD. Colunas: \(CSVCodec.header.joined(separator: ", ")).")
            }

            Section("Relatório mensal (PDF)") {
                DatePicker("Mês", selection: $reportMonth, displayedComponents: .date)
                Text(DateFormat.month(reportMonth)).foregroundStyle(.secondary)
                Button { exportPDF() } label: { Label("Gerar PDF", systemImage: "doc.richtext") }
            }

            Section {
                Button { exportBackup() } label: { Label("Exportar cópia de segurança (JSON)", systemImage: "externaldrive") }
                Button { importing = .backup } label: { Label("Restaurar cópia de segurança", systemImage: "arrow.counterclockwise") }
            } header: {
                Text("Cópia de segurança completa")
            } footer: {
                Text("Inclui categorias, transações, objetivos, recorrentes, grupos, regras de comerciantes e definições. Restaurar substitui todos os dados atuais.")
            }
        }
        .navigationTitle("Importar e exportar")
        .sheet(item: $share) { ActivityView(items: [$0.url]) }
        .fileImporter(isPresented: Binding(get: { importing != nil }, set: { if !$0 { importing = nil } }),
                      allowedContentTypes: importing == .backup ? [.json] : [.commaSeparatedText, .plainText, .text]) { result in
            let kind = importing
            importing = nil
            handleImport(result, kind: kind)
        }
        .sheet(isPresented: Binding(get: { csvPreview != nil }, set: { if !$0 { csvPreview = nil } })) {
            if let preview = csvPreview {
                CSVImportReportView(result: preview) { importRows(preview.rows) }
            }
        }
        .confirmationDialog("Substituir todos os dados pela cópia de segurança?", isPresented: Binding(get: { pendingBackup != nil }, set: { if !$0 { pendingBackup = nil } }),
                            titleVisibility: .visible, presenting: pendingBackup) { doc in
            Button("Restaurar (\(doc.transactions.count) transações)", role: .destructive) {
                do {
                    try BackupService.restore(doc, into: context)
                    message = "Cópia de segurança restaurada."
                } catch {
                    message = "Erro ao restaurar: \(error.localizedDescription)"
                }
            }
        } message: { doc in
            Text("Criada em \(DateFormat.short(doc.exportedAt)). Esta ação não pode ser desfeita.")
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: Exportar

    private func writeTemp(_ data: Data, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            message = "Não foi possível criar o ficheiro: \(error.localizedDescription)"
            return nil
        }
    }

    private func stamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }

    private func exportCSV() {
        let rows = transactions.map {
            CSVRow(date: $0.date, kind: $0.kind, amountCents: $0.amountCents, category: $0.category?.name ?? "", method: $0.method,
                   note: $0.note, merchant: $0.merchant, needsReview: $0.needsReview)
        }
        // BOM UTF-8 para o Excel reconhecer acentos.
        let data = Data("\u{FEFF}".utf8) + Data(CSVCodec.encode(rows).utf8)
        if let url = writeTemp(data, name: "transacoes-\(stamp()).csv") { share = ShareFile(url: url) }
    }

    private func exportPDF() {
        let snaps = transactions.map(\.snapshot)
        let interval = BalanceCalculator.monthInterval(containing: reportMonth)
        let monthTx = transactions.filter { $0.date >= interval.start && $0.date < interval.end }
        let balances = BalanceCalculator.balances(snaps, opening: openingBalance, upTo: interval.end.addingTimeInterval(-1))
        let byCat = BalanceCalculator.expensesByCategory(snaps, from: interval.start, to: interval.end).map { item in
            (name: categories.first { $0.id == item.categoryID }?.name ?? "Sem categoria", total: item.total)
        }
        let data = MonthlyReportData(
            month: interval.start,
            flow: BalanceCalculator.cashFlow(snaps, from: interval.start, to: interval.end),
            checking: balances.checking,
            vault: balances.vault,
            byCategory: byCat,
            lines: monthTx.map { MonthlyReportData.Line(date: $0.date, title: $0.title, category: $0.category?.name ?? $0.kind.label, amountCents: $0.amountCents, kind: $0.kind) }
        )
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        if let url = writeTemp(PDFReport.render(data), name: "relatorio-\(f.string(from: interval.start)).pdf") { share = ShareFile(url: url) }
    }

    private func exportBackup() {
        do {
            let data = try BackupService.makeDocument(context).encoded()
            if let url = writeTemp(data, name: "orcamento-backup-\(stamp()).json") { share = ShareFile(url: url) }
        } catch {
            message = "Erro ao criar a cópia de segurança: \(error.localizedDescription)"
        }
    }

    // MARK: Importar

    private func handleImport(_ result: Result<URL, Error>, kind: ImportKind?) {
        switch result {
        case .failure(let error):
            message = "Não foi possível abrir o ficheiro: \(error.localizedDescription)"
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                message = "Não foi possível ler o ficheiro."
                return
            }
            if kind == .backup {
                do { pendingBackup = try BackupDocument.decode(data) } catch {
                    message = (error as? LocalizedError)?.errorDescription ?? "Ficheiro JSON inválido."
                }
            } else {
                let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
                csvPreview = CSVCodec.decode(text)
            }
        }
    }

    private func importRows(_ rows: [CSVRow]) {
        var byName: [String: FinCategory] = [:]
        for c in categories { byName[TextNormalizer.key(c.name) + "|" + c.kindRaw] = c }
        var nextOrder = (categories.map(\.sortOrder).max() ?? 0) + 1
        for r in rows {
            var category: FinCategory? = nil
            if !r.category.isEmpty, !r.kind.isTransfer {
                let kind: CategoryKind = r.kind == .income ? .income : .expense
                let key = TextNormalizer.key(r.category) + "|" + kind.rawValue
                if let existing = byName[key] {
                    category = existing
                } else {
                    let c = FinCategory(name: r.category, kind: kind, colorHex: "#8E8E93", iconName: "tag.fill", sortOrder: nextOrder)
                    nextOrder += 1
                    context.insert(c)
                    byName[key] = c
                    category = c
                }
            }
            context.insert(FinTransaction(amountCents: r.amountCents, kind: r.kind, date: r.date, category: category, method: r.method,
                                          note: r.note, merchant: r.merchant, needsReview: r.needsReview))
        }
        try? context.save()
        VaultIntegrity.enforce(context)
        csvPreview = nil
        message = "\(rows.count) transações importadas."
    }
}

private struct CSVImportReportView: View {
    @Environment(\.dismiss) private var dismiss
    let result: CSVImportResult
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("\(result.rows.count) linhas válidas", systemImage: "checkmark.circle").foregroundStyle(.green)
                    Label("\(result.errors.count) linhas com erros", systemImage: "xmark.circle")
                        .foregroundStyle(result.errors.isEmpty ? Color.secondary : Color.red)
                }
                if !result.errors.isEmpty {
                    Section("Erros (estas linhas não são importadas)") {
                        ForEach(result.errors) { e in
                            VStack(alignment: .leading) {
                                Text("Linha \(e.line)").font(.caption.bold())
                                Text(e.message).font(.callout)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Relatório de importação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importar \(result.rows.count)") { onImport() }.disabled(result.rows.isEmpty)
                }
            }
        }
    }
}
