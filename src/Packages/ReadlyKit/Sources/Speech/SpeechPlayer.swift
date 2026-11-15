import AVFoundation
import Observation

/// Reads text aloud with the system speech synthesizer.
@MainActor
@Observable
public final class SpeechPlayer {
    /// The text being spoken, if any.
    public private(set) var speakingText: String?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let delegate = Delegate()
    @ObservationIgnored private var currentUtterance: ObjectIdentifier?

    @ObservationIgnored private let voiceQuality: @MainActor () -> VoiceQuality

    public init(voiceQuality: @escaping @MainActor () -> VoiceQuality = { .enhanced }) {
        self.voiceQuality = voiceQuality
        synthesizer.delegate = delegate
        delegate.onFinish = { [weak self] utterance in
            guard let self, utterance == currentUtterance else { return }
            currentUtterance = nil
            speakingText = nil
        }
    }

    public func isSpeaking(_ text: String) -> Bool { speakingText == text }

    /// Speaks `text`, or stops if that text is already being spoken.
    public func toggle(_ text: String, language: String?) {
        if isSpeaking(text) {
            stop()
        } else {
            speak(text, language: language)
        }
    }

    public func speak(_ text: String, language: String?) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = SystemVoices.voice(for: language, quality: voiceQuality())
        // A little slower than normal speech, which helps when learning a language.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        SystemVoices.activateAudioSession()
        currentUtterance = ObjectIdentifier(utterance)
        speakingText = text
        synthesizer.speak(utterance)
    }

    public func stop() {
        currentUtterance = nil
        speakingText = nil
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    }

    /// Receives synthesizer callbacks off the main actor and forwards them to it.
    private final class Delegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
        @MainActor var onFinish: (ObjectIdentifier) -> Void = { _ in }

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            finish(utterance)
        }

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            finish(utterance)
        }

        private nonisolated func finish(_ utterance: AVSpeechUtterance) {
            let id = ObjectIdentifier(utterance)
            Task { @MainActor in self.onFinish(id) }
        }
    }
}
