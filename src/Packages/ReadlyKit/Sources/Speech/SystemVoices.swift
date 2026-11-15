import AVFoundation

/// Access to the installed system voices and the audio session they play through.
@MainActor
enum SystemVoices {
    static func voice(for language: String?, quality: VoiceQuality) -> AVSpeechSynthesisVoice? {
        guard let language = language ?? AVSpeechSynthesisVoice(language: nil)?.language else { return nil }
        let candidates = AVSpeechSynthesisVoice.speechVoices().map {
            VoiceSelector.Candidate(identifier: $0.identifier, language: $0.language, quality: $0.quality.rawValue)
        }
        if let identifier = VoiceSelector(candidates: candidates).voice(for: language, preferredQuality: quality.systemQuality.rawValue) {
            return AVSpeechSynthesisVoice(identifier: identifier)
        }
        return AVSpeechSynthesisVoice(language: language)
    }

    static func activateAudioSession() {
        #if os(iOS)
        // Speak even with the ringer switched off, and duck any music playing.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        #endif
    }
}
