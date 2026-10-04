import AVFoundation
import MusicTheory

/// Procedural chord pads for backing playback — no audio assets, just
/// softly-enveloped sine stacks per chord, so a progression is audible
/// the moment it's loaded. Real stems can replace this later; the
/// scheduling surface stays the same.
@MainActor
final class ChordPadEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private let format: AVAudioFormat
    private var started = false

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.8
    }

    /// Sound one chord for (up to) the given duration, immediately.
    func play(_ chord: Chord, durationMs: Int) {
        guard ensureRunning() else { return }
        let seconds = min(Double(durationMs) / 1000.0, 6.0)
        guard let buffer = Self.padBuffer(for: chord, seconds: seconds,
                                          sampleRate: sampleRate, format: format) else { return }
        player.scheduleBuffer(buffer, at: nil)
        if !player.isPlaying { player.play() }
    }

    func stop() {
        player.stop()
        engine.stop()
        started = false
    }

    private func ensureRunning() -> Bool {
        guard !started else { return true }
        do {
            try engine.start()
            started = true
            return true
        } catch {
            AppLog.audio.error("Chord pad engine failed to start: \(error)")
            return false
        }
    }

    /// A soft pad: root (oct 3) + chord tones (oct 4), gentle attack, long
    /// release, slight detune shimmer so it doesn't sound like a test tone.
    private static func padBuffer(
        for chord: Chord, seconds: Double, sampleRate: Double, format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(sampleRate * seconds)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames

        var midiNotes = [Note(chord.root, octave: 3).midi]
        midiNotes += chord.pitchClasses.map { Note($0, octave: 4).midi }

        let frequencies = midiNotes.map { 440.0 * pow(2.0, (Double($0) - 69.0) / 12.0) }
        let gain = 0.22 / Double(frequencies.count)
        let attack = 0.06, release = min(0.8, seconds * 0.35)

        for frame in 0..<Int(frames) {
            let t = Double(frame) / sampleRate
            var envelope = 1.0
            if t < attack { envelope = t / attack }
            let tail = seconds - t
            if tail < release { envelope = max(0, tail / release) }

            var value = 0.0
            for f in frequencies {
                value += sin(2 * .pi * f * t)
                value += 0.35 * sin(2 * .pi * (f * 1.003) * t) // detune shimmer
            }
            samples[frame] = Float(value * gain * envelope)
        }
        return buffer
    }
}
