import Foundation

enum MerchantMatcher {
    /// Chave estável para um comerciante: minúsculas, sem acentos, sem números de loja finais.
    static func key(_ merchant: String) -> String {
        var words = TextNormalizer.key(merchant).split(separator: " ").map(String.init)
        while let last = words.last, words.count > 1, last.allSatisfy(\.isNumber) { words.removeLast() }
        return words.joined(separator: " ")
    }

    /// Procura a regra cuja chave coincide, ou uma cuja chave é prefixo do comerciante
    /// ("continente" apanha "continente modelo lisboa").
    static func bestMatch(for merchant: String, keys: [String]) -> String? {
        let k = key(merchant)
        guard !k.isEmpty else { return nil }
        if keys.contains(k) { return k }
        return keys.filter { !$0.isEmpty && (k.hasPrefix($0 + " ") || $0.hasPrefix(k + " ")) }
            .max { $0.count < $1.count }
    }
}
