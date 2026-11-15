import AVFoundation

public enum VoiceQuality: String, CaseIterable, Sendable {
    case `default`
    case enhanced
    case premium

    var systemQuality: AVSpeechSynthesisVoiceQuality {
        switch self {
        case .default: .default
        case .enhanced: .enhanced
        case .premium: .premium
        }
    }
}
