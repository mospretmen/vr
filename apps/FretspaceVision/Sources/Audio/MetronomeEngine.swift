import AVFoundation
import MusicTheory

/// Sample-accurate click track for backing playback. Generates its click
/// sounds procedurally (no bundled assets): a bright tick on beat 1, a soft
/// tick on beats 2–4. Runs alongside the timeline clock; drift is bounded by
/// scheduling ahead in whole bars from the audio render clock.
@MainActor
final class MetronomeEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var strongClick: AVAudioPCMBuffer?
    private var softClick: AVAudioPCMBuffer?
    private var scheduling = false

    // Beat state lives on the actor (not closure captures) so the rolling
    // schedule stays data-race free under strict concurrency.
    private var framesPerBeat: AVAudioFramePosition = 0
    private var nextBeatFrame: AVAudioFramePosition = 0
    private var beatInBar = 0

    var isRunning: Bool { scheduling }

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        strongClick = Self.makeClick(frequency: 1567.98, sampleRate: sampleRate, format: format) // G6
        softClick = Self.makeClick(frequency: 1046.50, sampleRate: sampleRate, format: format)   // C6
    }

    /// Starts clicking at `bpm` (4/4), phase-aligned to "now" = the current
    /// bar position of the timeline clock.
    func start(bpm: Double) {
        guard !scheduling, bpm > 0, strongClick != nil, softClick != nil else { return }
        do {
            try engine.start()
        } catch {
            AppLog.audio.error("Metronome engine failed to start: \(error)")
            return
        }
        scheduling = true
        player.play()

        framesPerBeat = AVAudioFramePosition(sampleRate * 60.0 / bpm)
        nextBeatFrame = 0
        beatInBar = 0

        // Prime one bar of lookahead; each completion tops up one beat.
        for _ in 0..<4 { scheduleNextBeat() }
    }

    /// Rolling schedule: one beat per call, re-armed from each buffer's
    /// completion. (MetronomeEngine is @MainActor and therefore Sendable,
    /// so the hop back from the audio completion thread is clean.)
    private func scheduleNextBeat() {
        guard scheduling, let strong = strongClick, let soft = softClick else { return }
        let buffer = beatInBar == 0 ? strong : soft
        let when = AVAudioTime(sampleTime: nextBeatFrame, atRate: sampleRate)
        player.scheduleBuffer(buffer, at: when) { [weak self] in
            Task { @MainActor [weak self] in self?.scheduleNextBeat() }
        }
        nextBeatFrame += framesPerBeat
        beatInBar = (beatInBar + 1) % 4
    }

    func stop() {
        scheduling = false
        player.stop()
        engine.stop()
    }

    /// 40ms decaying sine tick with a 2ms attack — click without the clack.
    private static func makeClick(
        frequency: Double, sampleRate: Double, format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let length = AVAudioFrameCount(sampleRate * 0.04)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: length),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = length
        for frame in 0..<Int(length) {
            let t = Double(frame) / sampleRate
            let attack = min(t / 0.002, 1.0)
            let decay = exp(-t * 90)
            samples[frame] = Float(sin(2 * .pi * frequency * t) * attack * decay * 0.5)
        }
        return buffer
    }
}
