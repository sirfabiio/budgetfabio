import XCTest
@testable import Orcamento

final class CSVCodecTests: XCTestCase {
    func testRoundTrip() {
        let rows = [
            CSVRow(date: dayStart(2026, 3, 1), kind: .income, amountCents: 150000, category: "Salário", method: .bankTransfer,
                   note: "Ordenado março", merchant: "", needsReview: false),
            CSVRow(date: dayStart(2026, 3, 2), kind: .expense, amountCents: 1250, category: "Restaurantes", method: .applePay,
                   note: "Jantar; com \"amigos\"\nsegunda linha", merchant: "Tasca do Zé", needsReview: true),
            CSVRow(date: dayStart(2026, 3, 3), kind: .vaultDeposit, amountCents: 20000, category: "", method: .other,
                   note: "", merchant: "", needsReview: false),
            CSVRow(date: dayStart(2026, 3, 4), kind: .vaultWithdrawal, amountCents: 5, category: "", method: .cash,
                   note: "Ação — café", merchant: "Pastelaria São João", needsReview: false),
        ]
        let text = CSVCodec.encode(rows)
        let result = CSVCodec.decode(text)
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(result.rows, rows)
    }

    func testHeaderAndEscaping() {
        let text = CSVCodec.encode([])
        XCTAssertTrue(text.hasPrefix("data;tipo;valor;categoria;metodo;descricao;comerciante;por_rever"))
        XCTAssertEqual(CSVCodec.escape("a;b"), "\"a;b\"")
        XCTAssertEqual(CSVCodec.escape("diz \"olá\""), "\"diz \"\"olá\"\"\"")
        XCTAssertEqual(CSVCodec.escape("simples"), "simples")
    }

    func testValidationReportsLineNumbers() {
        let text = """
        data;tipo;valor;categoria;metodo;descricao
        2026-03-01;despesa;12,50 €;Supermercado;Apple Pay;Compras
        2026-13-01;despesa;10;;;
        2026-03-02;transferência;10;;;
        2026-03-03;despesa;abc;;;
        2026-03-04;receita;-5;;;
        01/03/2026;receita;100;;Dinheiro;
        2026-03-05;despesa;3;;Bitcoin;
        """
        let r = CSVCodec.decode(text)
        XCTAssertEqual(r.rows.count, 2)
        XCTAssertEqual(r.rows[0].amountCents, 1250)
        XCTAssertEqual(r.rows[0].method, .applePay)
        XCTAssertEqual(r.rows[1].method, .cash)
        XCTAssertEqual(r.errors.map(\.line), [3, 4, 5, 6, 8])
    }

    func testMissingHeaderColumns() {
        let r = CSVCodec.decode("foo;bar\n1;2\n")
        XCTAssertTrue(r.rows.isEmpty)
        XCTAssertEqual(r.errors.count, 1)
        XCTAssertEqual(r.errors.first?.line, 1)
    }

    func testEmptyFile() {
        XCTAssertEqual(CSVCodec.decode("").errors.count, 1)
    }
}
