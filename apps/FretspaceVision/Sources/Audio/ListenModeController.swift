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
    private var noteTracker = NoteHitTracker(holdFrames: 2)
    private var listenTask: Task<Void, Never>?

    /// Failures the user must act on are routed here (owned by AppModel).
    var onError: (@MainActor (UserFacingError) -> Void)?

    /// When set, frames are also matched against this single note; a stable
    /// hit fires `onNoteHit` once. Drives play-to-advance exercises.
    var noteTarget: PitchClass? {
        didSet { noteTracker.setTarget(noteTarget) }
    }
    var onNoteHit: (@MainActor () -> Void)?

    func start() async {
        guard !isListening else { return }
        guard await AVAudioApplication.requestRecordPermission() else {
            AppLog.audio.notice("Listen mode blocked: microphone permission denied")
            onError?(.microphonePermissionDenied)
            return
        }
        guard let extractor = ChromaExtractor() else {
            AppLog.audio.error("Listen mode failed: FFT setup returned nil")
            onError?(.audioEngineUnavailable)
            return
        }

        AppLog.audio.info("Listen mode started")
        smoother.reset()
        isListening = true
        listenTask = Task {
            for await chroma in extractor.chromagrams() {
                let match = ChordMatcher.match(chroma)
                confidence = match?.score ?? 0
                detectedChord = smoother.feed(match)
                if noteTracker.feed(chroma) {
                    onNoteHit?()
                }
            }
            // Stream ending on its own means the engine died mid-session.
            if isListening {
                AppLog.audio.error("Listen mode audio stream ended unexpectedly")
                onError?(.audioEngineUnavailable)
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
