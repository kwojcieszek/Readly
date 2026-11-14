import Foundation

/// Counts the pages of chapters by laying them out in a second, invisible web view
/// that has the same size and style as the visible one.
@MainActor
final class ChapterMeasurer {
    let engine = ReaderWebEngine()

    private var token = 0
    private var continuation: CheckedContinuation<Int?, Never>?

    init() {
        engine.onEvent = { [weak self] event in
            if case .layout(let layout) = event { self?.finish(token: layout.token, pageCount: layout.pageCount) }
        }
    }

    /// Returns `nil` when the chapter could not be laid out in time.
    func pageCount(of chapter: URL, root: URL, style: ReaderStyle) async -> Int? {
        finish(token: token, pageCount: nil)
        token += 1
        let current = token
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            engine.load(chapter: chapter, root: root, style: style, start: .fraction(0), token: current)
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                self?.finish(token: current, pageCount: nil)
            }
        }
    }

    private func finish(token finished: Int, pageCount: Int?) {
        guard finished == token, let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: pageCount)
    }
}
