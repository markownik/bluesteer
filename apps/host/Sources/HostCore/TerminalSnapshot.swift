import Foundation
import SwiftTerm

/// Serialises a headless SwiftTerm screen as VT sequences a remote emulator
/// can replay to reproduce it (SPEC.md §4.1, `TermSnapshot.vt`).
enum TerminalSnapshot {
    static func render(_ t: Terminal) -> Data {
        var s = "\u{1b}[0m\u{1b}[H\u{1b}[2J"
        var lastAttr: Attribute? = nil
        for row in 0..<t.rows {
            s += "\u{1b}[\(row + 1);1H"
            // Trailing default-attribute blanks are not sent: they only cost
            // bytes and reflow into extra lines when the remote is narrower.
            var last = -1
            for col in 0..<t.cols {
                if let cd = t.getCharData(col: col, row: row), !(isBlank(cd.getCharacter()) && cd.attribute.bg == .defaultColor && !cd.attribute.style.contains(.inverse)) {
                    last = col
                }
            }
            for col in 0..<(last + 1) {
                guard let cd = t.getCharData(col: col, row: row) else { continue }
                if cd.attribute != lastAttr {
                    s += sgr(cd.attribute)
                    lastAttr = cd.attribute
                }
                let ch = cd.getCharacter()
                s.append(ch == "\0" ? " " : ch)
            }
            s += "\u{1b}[K"
        }
        let cursor = t.getCursorLocation()
        s += "\u{1b}[0m\u{1b}[\(cursor.y + 1);\(cursor.x + 1)H"
        if t.applicationCursor { s += "\u{1b}[?1h" }
        if t.bracketedPasteMode { s += "\u{1b}[?2004h" }
        return Data(s.utf8)
    }

    private static func isBlank(_ c: Character) -> Bool { c == " " || c == "\0" }

    private static func sgr(_ a: Attribute) -> String {
        var codes = ["0"]
        if a.style.contains(.bold) { codes.append("1") }
        if a.style.contains(.dim) { codes.append("2") }
        if a.style.contains(.italic) { codes.append("3") }
        if a.style.contains(.underline) { codes.append("4") }
        if a.style.contains(.inverse) { codes.append("7") }
        codes += colorCodes(a.fg, fg: true)
        codes += colorCodes(a.bg, fg: false)
        return "\u{1b}[" + codes.joined(separator: ";") + "m"
    }

    private static func colorCodes(_ c: Attribute.Color, fg: Bool) -> [String] {
        switch c {
        case .defaultColor, .defaultInvertedColor: return []
        case .ansi256(let code):
            if code < 8 { return [String((fg ? 30 : 40) + Int(code))] }
            if code < 16 { return [String((fg ? 90 : 100) + Int(code) - 8)] }
            return [fg ? "38" : "48", "5", String(code)]
        case .trueColor(let r, let g, let b):
            return [fg ? "38" : "48", "2", String(r), String(g), String(b)]
        }
    }
}
