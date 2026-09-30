import AVFoundation
import Observation
import AudioAnalysis
import MusicTheory

/// Orchestrates listen mode: mic chroma → matcher → smoother → published
/// stable chord. The immersive view observes `detectedChord` to drive the
/// overlay and the chord aura.
@MainActor
@Observable
final class ListenModeController {
    private(set) var isListening = false
    private(set) var detectedChord: Chord?
    /// Raw per-frame confidence, for a subtle UI meter.
    private(set) var confidence: Double = 0

    private var smoother = ChordDecisionSmoother(holdFrames: 3)
    private var listenTask: Task<Void, Never>?

    func start() async {
        guard !isListening else { return }
        guard await AVAudioApplication.requestRecordPermission() else { return }
        guard let extractor = ChromaExtractor() else { return }

        smoother.reset()
        isListening = true
        listenTask = Task {
            for await chroma in extractor.chromagrams() {
                let match = ChordMatcher.match(chroma)
                confidence = match?.score ?? 0
                detectedChord = smoother.feed(match)
            }
            isListening = false
        }
    }

    func stop() {
        listenTask?.cancel()
        listenTask = nil
        isListening = false
        detectedChord = nil
        confidence = 0
    }
}
