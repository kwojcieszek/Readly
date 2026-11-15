import Foundation
import Observation
@preconcurrency import Translation
import TranslationCore

/// Hands translations to Apple's on-device translator.
///
/// This bridge uses SwiftUI's `translationTask` so the system can ask to
/// download missing languages. So requests wait in
/// a queue here, the bridge asks the hosting view for a session for their language
/// pair, and the view hands the session back to `run(_:)` to work through the queue.
@MainActor
@Observable
public final class SystemTranslationBridge {
    struct LanguagePair: Equatable, Sendable {
        var source: Locale.Language?
        var target: Locale.Language
    }

    /// Watched by the hosting view; a new value (or an invalidated one) starts a session.
    private(set) var configuration: TranslationSession.Configuration?

    /// Requests not handed to a session yet.
    @ObservationIgnored private var queue: [Job] = []
    /// Everyone still waiting for an answer, queued or being translated. Each
    /// continuation is removed before it is resumed, so it is resumed exactly once.
    @ObservationIgnored private var waiting: [Int: CheckedContinuation<String, any Error>] = [:]
    @ObservationIgnored private var activePair: LanguagePair?
    @ObservationIgnored private var runID: UUID?
    @ObservationIgnored private var hostCount = 0
    @ObservationIgnored private var nextJobID = 0

    struct Job: Sendable {
        let id: Int
        let text: String
        let pair: LanguagePair
    }

    public init() {}

    func translate(_ text: String, pair: LanguagePair) async throws -> String {
        guard hostCount > 0 else { throw TranslationError.systemTranslationUnavailable }
        nextJobID += 1
        let id = nextJobID
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiting[id] = continuation
                queue.append(Job(id: id, text: text, pair: pair))
                requestSession()
            }
        } onCancel: {
            Task { @MainActor in self.finish(id, with: .failure(CancellationError())) }
        }
    }

    /// Called by the hosting view with the session it was given. Runs off the main actor,
    /// where the session lives; only the queue bookkeeping hops to it.
    nonisolated func run(_ session: TranslationSession) async {
        guard let (pair, id) = await beginRun() else { return }
        while let job = await nextJob(for: pair, runID: id) {
            let result: Result<String, any Error>
            do {
                result = .success(try await session.translate(job.text).targetText)
            } catch is CancellationError {
                result = .failure(CancellationError())
            } catch {
                result = .failure(TranslationError.system(error.localizedDescription))
            }
            await finish(job.id, with: result)
        }
        await endRun(id)
    }

    func hostAppeared() {
        hostCount += 1
        requestSession()
    }

    func hostDisappeared() {
        hostCount = max(0, hostCount - 1)
        guard hostCount == 0 else { return }
        // Nothing can serve the queue any more.
        queue.removeAll()
        runID = nil
        activePair = nil
        configuration = nil
        for id in Array(waiting.keys) {
            finish(id, with: .failure(TranslationError.systemTranslationUnavailable))
        }
    }

    // MARK: Queue

    private func beginRun() -> (LanguagePair, UUID)? {
        guard hostCount > 0, runID == nil, let pair = activePair else { return nil }
        let id = UUID()
        runID = id
        return (pair, id)
    }

    private func nextJob(for pair: LanguagePair, runID: UUID) -> Job? {
        guard self.runID == runID, let index = queue.firstIndex(where: { $0.pair == pair }) else { return nil }
        return queue.remove(at: index)
    }

    private func endRun(_ id: UUID) {
        guard runID == id else { return }
        runID = nil
        requestSession()
    }

    private func finish(_ id: Int, with result: Result<String, any Error>) {
        queue.removeAll { $0.id == id }
        waiting.removeValue(forKey: id)?.resume(with: result)
    }

    /// Asks the hosting view for a session for the oldest waiting request.
    private func requestSession() {
        guard runID == nil, hostCount > 0, let pair = queue.first?.pair else { return }
        if pair == activePair, configuration != nil {
            configuration?.invalidate()
        } else {
            activePair = pair
            configuration = TranslationSession.Configuration(source: pair.source, target: pair.target)
        }
    }
}
