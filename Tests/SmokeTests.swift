import XCTest
@testable import Orcamento

/// Formatação monetária e de datas em pt-PT.
final class SmokeTests: XCTestCase {
    func testPlainStringUsesCommaAndTwoDecimals() {
        XCTAssertEqual(MoneyFormat.plainString(1250), "12,50")
        XCTAssertEqual(MoneyFormat.plainString(5), "0,05")
        XCTAssertEqual(MoneyFormat.plainString(-123456), "-1234,56")
    }

    func testCurrencyStringIsEuroPortuguese() {
        let s = MoneyFormat.string(123450)
        XCTAssertTrue(s.contains("€"), s)
        XCTAssertTrue(s.contains("1234,50") || s.contains("1 234,50") || s.contains("1\u{00A0}234,50") || s.contains("1\u{202F}234,50") || s.contains("1.234,50"), s)
    }

    func testTextNormalizerFoldsAccents() {
        XCTAssertEqual(TextNormalizer.key("  Café  São-João "), "cafe sao joao")
        XCTAssertEqual(TextNormalizer.key("Pingo Doce"), "pingo doce")
    }
}
