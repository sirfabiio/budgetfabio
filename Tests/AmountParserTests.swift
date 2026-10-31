import XCTest
@testable import Orcamento

final class AmountParserTests: XCTestCase {
    func testEuropeanFormatWithSymbolAfter() {
        XCTAssertEqual(AmountParser.parseCents("12,50 €"), 1250)
        XCTAssertEqual(AmountParser.parseCents("12,50\u{00A0}€"), 1250)
        XCTAssertEqual(AmountParser.parseCents("12,5€"), 1250)
    }

    func testSymbolBeforeWithDot() {
        XCTAssertEqual(AmountParser.parseCents("€12.50"), 1250)
        XCTAssertEqual(AmountParser.parseCents("€ 12.50"), 1250)
        XCTAssertEqual(AmountParser.parseCents("EUR 12,50"), 1250)
    }

    func testThousandsSeparators() {
        XCTAssertEqual(AmountParser.parseCents("1.234,56 €"), 123456)
        XCTAssertEqual(AmountParser.parseCents("€1,234.56"), 123456)
        XCTAssertEqual(AmountParser.parseCents("1 234,56 €"), 123456)
        XCTAssertEqual(AmountParser.parseCents("1.234"), 123400)
        XCTAssertEqual(AmountParser.parseCents("1.234.567"), 123456700)
    }

    func testIntegersAndEdgeCases() {
        XCTAssertEqual(AmountParser.parseCents("12"), 1200)
        XCTAssertEqual(AmountParser.parseCents("12 €"), 1200)
        XCTAssertEqual(AmountParser.parseCents("0,99"), 99)
        XCTAssertEqual(AmountParser.parseCents(",50"), 50)
        XCTAssertEqual(AmountParser.parseCents("-3,20 €"), -320)
        XCTAssertEqual(AmountParser.parseCents("12,505"), 1250500)
        XCTAssertEqual(AmountParser.parseCents("1,5"), 150)
        XCTAssertEqual(AmountParser.parseCents("2.999,995"), 300000)
    }

    func testInvalidInput() {
        XCTAssertNil(AmountParser.parseCents(""))
        XCTAssertNil(AmountParser.parseCents("€"))
        XCTAssertNil(AmountParser.parseCents("abc"))
    }
}
