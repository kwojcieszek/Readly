import Testing
@testable import Speech

@Suite struct VoiceSelectorTests {
    private let voices = [
        VoiceSelector.Candidate(identifier: "us", language: "en-US", quality: 1),
        VoiceSelector.Candidate(identifier: "gb", language: "en-GB", quality: 1),
        VoiceSelector.Candidate(identifier: "gb-premium", language: "en-GB", quality: 3),
        VoiceSelector.Candidate(identifier: "de", language: "de-DE", quality: 1),
    ]

    @Test func prefersExactRegionThenQuality() {
        let selector = VoiceSelector(candidates: voices, preferredRegion: "US")
        #expect(selector.voice(for: "en-GB") == "gb-premium")
        #expect(selector.voice(for: "en_US") == "us")
    }

    @Test func languageWithoutRegionUsesTheUsersRegion() {
        #expect(VoiceSelector(candidates: voices, preferredRegion: "US").voice(for: "en") == "us")
        #expect(VoiceSelector(candidates: voices, preferredRegion: "PL").voice(for: "EN") == "gb-premium")
    }

    @Test func unknownLanguageHasNoVoice() {
        #expect(VoiceSelector(candidates: voices).voice(for: "fr") == nil)
        #expect(VoiceSelector(candidates: voices).voice(for: "de-AT") == "de")
    }

    @Test func detectsLanguageOnlyWhenTheBookDeclaresNone() {
        #expect(LanguageGuesser.language(of: "anything", declared: "pl") == "pl")
        let detected = LanguageGuesser.language(
            of: "Der schnelle braune Fuchs springt über den faulen Hund.", declared: " "
        )
        #expect(detected == "de")
    }
}

@Suite struct NarrationSkipTests {
    private let text = String(repeating: "word ", count: 100) // 500 characters

    @Test func skipsForwardToTheStartOfAWord() {
        // 15 s at 14 characters per second is 210 characters, which is the start of a word.
        #expect(NarrationSkip.target(in: text, from: 0, seconds: 15) == .offset(210))
        #expect(NarrationSkip.target(in: text, from: 2, seconds: 15) == .offset(215))
    }

    @Test func skipsBackWithinTheText() {
        #expect(NarrationSkip.target(in: text, from: 400, seconds: -15) == .offset(190))
        #expect(NarrationSkip.target(in: text, from: 100, seconds: -15) == .offset(0))
    }

    @Test func reportsRunningOffEitherEnd() {
        #expect(NarrationSkip.target(in: text, from: 400, seconds: 15) == .pastEnd)
        #expect(NarrationSkip.target(in: text, from: 10, seconds: -15) == .beforeStart)
    }
}
