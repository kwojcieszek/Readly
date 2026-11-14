import Foundation
import TranslationCore

/// Messages sent by the in-page reader script.
enum ReaderEvent: Equatable {
    case translate(kind: TranslationRequest.Kind, text: String, context: String?, selection: SelectionRect? = nil)
    /// The chapter was laid out or the visible page changed.
    case layout(PageLayout)
    /// A page turn ran past the first or last page of the chapter.
    case boundary(forward: Bool)
    case dismiss

    struct PageLayout: Equatable {
        var page: Int
        var pageCount: Int
        var width: Int
        var height: Int
        /// Echo of the token passed when the chapter was loaded.
        var token: Int
        /// Where the highlighted text is on the visible page, if it is there.
        var selection: SelectionRect?
    }

    /// A rectangle in the page's CSS pixels.
    struct SelectionRect: Equatable {
        var x: Double
        var y: Double
        var width: Double
        var height: Double

        init?(_ value: Any?) {
            guard let body = value as? [String: Any] else { return nil }
            func number(_ key: String) -> Double? { (body[key] as? NSNumber)?.doubleValue }
            guard let x = number("x"), let y = number("y"), let width = number("width"), let height = number("height")
            else { return nil }
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
    }

    init?(messageBody: Any) {
        guard let body = messageBody as? [String: Any], let type = body["type"] as? String else {
            return nil
        }
        func int(_ key: String) -> Int? { (body[key] as? NSNumber)?.intValue }

        switch type {
        case "translate":
            guard let rawKind = body["kind"] as? String,
                  let kind = TranslationRequest.Kind(rawValue: rawKind),
                  let text = body["text"] as? String, !text.isEmpty
            else { return nil }
            self = .translate(
                kind: kind,
                text: text,
                context: body["context"] as? String,
                selection: SelectionRect(body["selection"])
            )
        case "layout":
            guard let page = int("page"), let pageCount = int("pageCount"), pageCount > 0 else { return nil }
            self = .layout(PageLayout(
                page: min(max(0, page), pageCount - 1),
                pageCount: pageCount,
                width: int("width") ?? 0,
                height: int("height") ?? 0,
                token: int("token") ?? 0,
                selection: SelectionRect(body["selection"])
            ))
        case "boundary":
            guard let forward = body["forward"] as? Bool else { return nil }
            self = .boundary(forward: forward)
        case "dismiss":
            self = .dismiss
        default:
            return nil
        }
    }
}
