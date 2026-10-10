import Foundation

/// Decides whether copied text is a link, code or plain text.
enum Classifier {
    static func classify(_ text: String) -> ClipKind {
        if isURL(text) { return .url }
        if looksLikeCode(text) { return .code }
        return .text
    }

    static func isURL(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t.count < 2048, t.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return false }
        if let url = URL(string: t), let scheme = url.scheme?.lowercased(),
           ["http", "https", "ftp"].contains(scheme), url.host != nil {
            return true
        }
        return t.range(of: #"^www\.[^\s/]+\.[A-Za-z]{2,}(/\S*)?$"#, options: .regularExpression) != nil
    }

    private static let keywordStart = try! NSRegularExpression(
        pattern: #"^(func|def|class|struct|enum|protocol|extension|import|from|return|const|let|var|function|public|private|protected|static|final|async|await|package|using|namespace|interface|type|SELECT|INSERT|UPDATE|DELETE|CREATE|WITH|if|else|elif|for|while|switch|case|try|catch|guard)\b.*(\(|\{|:|=|;|$)"#
    )
    private static let commandStart = try! NSRegularExpression(
        pattern: #"^(\$ )?(git|npm|npx|yarn|pnpm|brew|docker|kubectl|sudo|cd|ls|curl|wget|pip3?|python3?|swift|swiftc|cargo|go|make|ssh|scp|chmod|chown|grep|sed|awk|cat|echo|export|xcodebuild)\s"#
    )

    static func looksLikeCode(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return false }

        func matches(_ re: NSRegularExpression, _ s: String) -> Bool {
            re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
        }
        let operators = ["=>", "->", "==", "!=", "&&", "||", ":=", "::", "();", "</", "/>", "+=", "-="]

        func codey(_ line: String) -> Bool {
            if line.hasSuffix(";") || line.hasSuffix("{") || line.hasSuffix("}") { return true }
            if line.hasPrefix("//") || line.hasPrefix("/*") || line.hasPrefix("#include") || line.hasPrefix("#!") { return true }
            if matches(keywordStart, line) || matches(commandStart, line) { return true }
            return operators.contains { line.contains($0) }
        }

        let codeLines = lines.filter(codey).count
        if lines.count == 1 {
            let line = lines[0]
            return matches(commandStart, line) || (codeLines == 1 && line.count < 400 && line.contains(where: { "{}();=<>".contains($0) }))
        }
        return Double(codeLines) / Double(lines.count) >= 0.45
    }
}
