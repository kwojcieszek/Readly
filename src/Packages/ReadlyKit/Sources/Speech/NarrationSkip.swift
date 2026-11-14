import Foundation

/// Works out where a "skip 15 seconds" lands in a text that is being read aloud.
public enum NarrationSkip: Equatable, Sendable {
    /// Continue from this UTF-16 offset.
    case offset(Int)
    /// The skip runs back past the start of the text.
    case beforeStart
    /// The skip runs past the end of the text.
    case pastEnd

    /// Roughly how many characters the synthesizer speaks per second.
    public static let charactersPerSecond = 14.0

    public static func target(in text: String, from offset: Int, seconds: Double) -> NarrationSkip {
        let units = Array(text.utf16)
        let distance = Int((seconds * charactersPerSecond).rounded())
        var target = offset + distance
        if target >= units.count { return .pastEnd }
        if target <= 0 {
            // Near the top of the text a skip back means "the text before this one".
            return offset <= Int(charactersPerSecond * 2) ? .beforeStart : .offset(0)
        }
        // Land on the start of a word.
        let space = UInt16(32), newline = UInt16(10)
        let isAtWordStart = units[target - 1] == space || units[target - 1] == newline
        while !isAtWordStart, target < units.count, units[target] != space, units[target] != newline { target += 1 }
        while target < units.count, units[target] == space || units[target] == newline { target += 1 }
        return target >= units.count ? .pastEnd : .offset(target)
    }
}
