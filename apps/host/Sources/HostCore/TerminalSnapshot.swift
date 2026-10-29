import Foundation
import SwiftTerm

/// Serialises a headless SwiftTerm screen as VT sequences a remote emulator
/// can replay to reproduce it (SPEC.md §4.1, `TermSnapshot.vt`).
enum TerminalSnapshot {
    /// The screen, preceded by up to `scrollbackLines` lines of history (SPEC.md §4.4).
    static func render(_ t: Terminal, scrollbackLines: Int = 0) -> Data {
        var s = ""
        var lastAttr: Attribute? = nil
        let history = min(max(scrollbackLines, 0), t.buffer.yDisp)
        if history > 0 {
            // Erase the remote's history too, park the cursor on the last row so
            // every CR LF scrolls exactly one line into the remote's history.
            s += "\u{1b}[0m\u{1b}[2J\u{1b}[3J\u{1b}[\(t.rows);1H"
            let first = t.buffer.totalLinesTrimmed + t.buffer.yDisp - history
            for i in 0..<history {
                if let line = t.getScrollInvariantLine(row: first + i) {
                    s += renderLine(line, cols: t.cols, lastAttr: &lastAttr)
                }
                s += "\u{1b}[0m\r\n"
                lastAttr = nil
            }
            s += String(repeating: "\n", count: max(t.rows - 1, 0))
        }
        s += "\u{1b}[0m\u{1b}[H\u{1b}[2J"
        lastAttr = nil
        for row in 0..<t.rows {
            s += "\u{1b}[\(row + 1);1H"
            if let line = t.getLine(row: row) {
                s += renderLine(line, cols: t.cols, lastAttr: &lastAttr)
            }
            s += "\u{1b}[K"
        }
        let cursor = t.getCursorLocation()
        s += "\u{1b}[0m\u{1b}[\(cursor.y + 1);\(cursor.x + 1)H"
        if t.applicationCursor { s += "\u{1b}[?1h" }
        if t.bracketedPasteMode { s += "\u{1b}[?2004h" }
        return Data(s.utf8)
    }

    /// One buffer line as SGR runs and text. Trailing default-attribute blanks
    /// are not sent: they only cost bytes and reflow into extra lines when the
    /// remote is narrower.
    private static func renderLine(_ line: BufferLine, cols: Int, lastAttr: inout Attribute?) -> String {
        var s = ""
        var last = -1
        for col in 0..<cols {
            let cd = line[col]
            if !(isBlank(cd.getCharacter()) && cd.attribute.bg == .defaultColor && !cd.attribute.style.contains(.inverse)) {
                last = col
            }
        }
        for col in 0..<(last + 1) {
            let cd = line[col]
            // The cell after a wide character is a placeholder the wide glyph already covers.
            if col > 0, cd.getCharacter() == "\0", line[col - 1].width == 2 { continue }
            if cd.attribute != lastAttr {
                s += sgr(cd.attribute)
                lastAttr = cd.attribute
            }
            let ch = cd.getCharacter()
            s.append(ch == "\0" ? " " : ch)
        }
        return s
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
