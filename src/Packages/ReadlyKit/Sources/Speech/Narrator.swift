import AVFoundation
import Observation

/// Reads long passages aloud, with pause, resume and skipping.
@MainActor
@Observable
public final class Narrator {
    public enum State: Sendable, Equatable {
        case idle
        case speaking
        case paused
    }

    public private(set) var state: State = .idle
    /// Called when a passage was read to its end (not when it was stopped).
    @ObservationIgnored public var onFinish: () -> Void = {}

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let delegate = Delegate()
    @ObservationIgnored private var currentUtterance: ObjectIdentifier?
    @ObservationIgnored private var text = ""
    @ObservationIgnored private var language: String?
    /// UTF-16 offset in `text` where the current utterance starts, and the last word spoken.
    @ObservationIgnored private var baseOffset = 0
    @ObservationIgnored private var spokenOffset = 0

    public init() {
        synthesizer.delegate = delegate
        delegate.onProgress = { [weak self] utterance, location in
            guard let self, utterance == currentUtterance else { return }
            spokenOffset = baseOffset + location
        }
        delegate.onFinish = { [weak self] utterance in
            guard let self, utterance == currentUtterance else { return }
            currentUtterance = nil
            state = .idle
            onFinish()
        }
    }

    public var isActive: Bool { state != .idle }

    /// Reads `text` from a UTF-16 `offset`, replacing whatever was being read.
    public func speak(_ text: String, from offset: Int = 0, language: String?) {
        halt()
        self.text = text
        self.language = language
        let units = text.utf16
        let start = min(max(0, offset), units.count)
        guard let index = units.index(units.startIndex, offsetBy: start, limitedBy: units.endIndex),
              let remainder = String(units[index...]),
              !remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            state = .idle
            onFinish()
            return
        }
        baseOffset = start
        spokenOffset = start
        let utterance = AVSpeechUtterance(string: remainder)
        utterance.voice = SystemVoices.voice(for: language)
        utterance.prefersAssistiveTechnologySettings = true
        SystemVoices.activateAudioSession()
        currentUtterance = ObjectIdentifier(utterance)
        state = .speaking
        synthesizer.speak(utterance)
    }

    public func pause() {
        guard state == .speaking else { return }
        synthesizer.pauseSpeaking(at: .word)
        state = .paused
    }

    public func resume() {
        guard state == .paused else { return }
        synthesizer.continueSpeaking()
        state = .speaking
    }

    public func stop() {
        halt()
        state = .idle
    }

    /// Jumps forward or back inside the passage. Returns where the jump lands;
    /// reading continues only for `.offset`.
    @discardableResult
    public func skip(seconds: Double) -> NarrationSkip {
        guard isActive else { return .offset(spokenOffset) }
        let target = NarrationSkip.target(in: text, from: spokenOffset, seconds: seconds)
        if case .offset(let offset) = target {
            speak(text, from: offset, language: language)
        }
        return target
    }

    private func halt() {
        currentUtterance = nil
        if synthesizer.isSpeaking || synthesizer.isPaused { synthesizer.stopSpeaking(at: .immediate) }
    }

    /// Receives synthesizer callbacks off the main actor and forwards them to it.
    private final class Delegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
        @MainActor var onFinish: (ObjectIdentifier) -> Void = { _ in }
        @MainActor var onProgress: (ObjectIdentifier, Int) -> Void = { _, _ in }

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            let id = ObjectIdentifier(utterance)
            Task { @MainActor in self.onFinish(id) }
        }

        nonisolated func speechSynthesizer(
            _ synthesizer: AVSpeechSynthesizer,
            willSpeakRangeOfSpeechString characterRange: NSRange,
            utterance: AVSpeechUtterance
        ) {
            let id = ObjectIdentifier(utterance)
            let location = characterRange.location
            Task { @MainActor in self.onProgress(id, location) }
        }
    }
}
