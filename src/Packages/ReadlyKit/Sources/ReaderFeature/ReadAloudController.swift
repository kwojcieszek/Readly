import Foundation
import Observation
import Speech

/// Reads the book aloud page by page, turning pages as it goes.
@MainActor
@Observable
final class ReadAloudController {
    /// What the reader has to provide for narration.
    struct Source {
        var pageText: () async -> String
        var language: (String) -> String?
        var canTurnForward: () -> Bool
        var canTurnBack: () -> Bool
        var turnPage: (_ forward: Bool) -> Void
    }

    enum Mode: Equatable {
        case idle
        case playing
        case paused
    }

    private(set) var mode: Mode = .idle
    @ObservationIgnored var source: Source?
    @ObservationIgnored private let narrator: Narrator
    @ObservationIgnored private var startTask: Task<Void, Never>?

    init(voiceQuality: @escaping @MainActor () -> VoiceQuality) {
        narrator = Narrator(voiceQuality: voiceQuality)
        narrator.onFinish = { [weak self] in self?.advance() }
    }

    var isPlaying: Bool { mode == .playing }
    var isActive: Bool { mode != .idle }

    func toggle() {
        switch mode {
        case .idle:
            mode = .playing
            readCurrentPage(delayed: false)
        case .playing:
            pause()
        case .paused:
            mode = .playing
            if narrator.state == .paused { narrator.resume() } else { readCurrentPage(delayed: false) }
        }
    }

    func pause() {
        guard mode == .playing else { return }
        mode = .paused
        startTask?.cancel()
        narrator.pause()
    }

    func stop() {
        mode = .idle
        startTask?.cancel()
        narrator.stop()
    }

    /// Jumps about `seconds` forward or back, crossing to the neighbouring page when needed.
    func skip(seconds: Double) {
        guard let source, isActive else { return }
        mode = .playing
        switch narrator.skip(seconds: seconds) {
        case .offset:
            break
        case .pastEnd:
            advance()
        case .beforeStart:
            if source.canTurnBack() { source.turnPage(false) } else { readCurrentPage(delayed: false) }
        }
    }

    /// The visible page changed: keep reading from the new one.
    func pageDidChange() {
        switch mode {
        case .idle: break
        case .playing: readCurrentPage(delayed: true)
        case .paused: stop()
        }
    }

    private func advance() {
        guard mode == .playing else { return }
        guard let source, source.canTurnForward() else {
            stop()
            return
        }
        // The turn reports back through `pageDidChange`, which reads the new page.
        source.turnPage(true)
    }

    private func readCurrentPage(delayed: Bool) {
        guard let source else { return }
        startTask?.cancel()
        narrator.stop()
        startTask = Task { [narrator] in
            // Give a page turn or a new chapter time to settle before reading it.
            if delayed { try? await Task.sleep(for: .milliseconds(600)) }
            guard !Task.isCancelled else { return }
            let text = await source.pageText()
            guard !Task.isCancelled else { return }
            narrator.speak(text, language: source.language(text))
        }
    }
}
