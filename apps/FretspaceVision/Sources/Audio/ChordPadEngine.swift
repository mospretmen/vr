import AVFoundation
import MusicTheory

/// The app's guitar: bundled nylon-string samples (FluidR3, MIT; one mp3
/// per midi 40–84 under GuitarSamples/) decoded once and mixed into the
/// same sequentially-queued buffers as before. The Karplus–Strong pluck
/// remains the fallback for anything not yet decoded or out of range.
@MainActor
final class ChordPadEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private let format: AVAudioFormat
    private var started = false

    /// Decoded mono 44.1k sample per midi note. Filled lazily + by the
    /// background preload; main-actor confined.
    private static var bank: [Int: [Float]] = [:]
    private static let sampleRange = 40...84

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.8
        Self.preload()
    }

    /// Decode the whole range shortly after launch so taps hit samples.
    private static var preloaded = false
    private static func preload() {
        guard !preloaded else { return }
        preloaded = true
        Task { @MainActor in
            for midi in sampleRange where bank[midi] == nil {
                _ = loadSample(midi)
                await Task.yield()
            }
            AppLog.audio.info("Guitar sample bank ready: \(bank.count) notes")
        }
    }

    /// Synchronous decode of one bundled note into mono 44.1k floats.
    @discardableResult
    private static func loadSample(_ midi: Int) -> [Float]? {
        if let cached = bank[midi] { return cached }
        guard sampleRange.contains(midi),
              let url = Bundle.main.url(forResource: String(midi),
                                        withExtension: "mp3",
                                        subdirectory: "GuitarSamples") else { return nil }
        do {
            let file = try AVAudioFile(forReading: url)
            guard let raw = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                             frameCapacity: AVAudioFrameCount(file.length))
            else { return nil }
            try file.read(into: raw)
            guard let target = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
                  let converter = AVAudioConverter(from: file.processingFormat, to: target),
                  let out = AVAudioPCMBuffer(pcmFormat: target,
                                             frameCapacity: AVAudioFrameCount(
                                                Double(file.length) * 44_100 / file.processingFormat.sampleRate + 1024))
            else { return nil }
            var fed = false
            var convError: NSError?
            converter.convert(to: out, error: &convError) { _, status in
                if fed { status.pointee = .endOfStream; return nil }
                fed = true
                status.pointee = .haveData
                return raw
            }
            if let convError {
                AppLog.audio.error("Sample convert failed for midi \(midi): \(convError)")
                return nil
            }
            guard let channel = out.floatChannelData?[0] else { return nil }
            let samples = Array(UnsafeBufferPointer(start: channel, count: Int(out.frameLength)))
            bank[midi] = samples
            return samples
        } catch {
            AppLog.audio.error("Sample load failed for midi \(midi): \(error)")
            return nil
        }
    }

    /// One note as floats: the real string when decoded, the pluck model
    /// otherwise. `seconds` caps length; a fade keeps the cut inaudible.
    private static func noteSamples(
        midi: Int, seconds: Double, sampleRate: Double, amplitude: Double
    ) -> [Float] {
        let clamped = min(max(midi, sampleRange.lowerBound), sampleRange.upperBound)
        guard midi == clamped, let pcm = loadSample(clamped) else {
            return pluckSamples(midi: midi, seconds: seconds,
                                sampleRate: sampleRate, amplitude: amplitude)
        }
        let count = min(pcm.count, Int(sampleRate * seconds))
        let fade = min(Int(sampleRate * 0.08), count)
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            var v = pcm[i] * Float(amplitude)
            if i >= count - fade {
                v *= Float(count - i) / Float(fade)
            }
            out[i] = v
        }
        return out
    }

    /// Sound one chord for (up to) the given duration, immediately.
    func play(_ chord: Chord, durationMs: Int) {
        guard ensureRunning() else { return }
        let seconds = min(Double(durationMs) / 1000.0, 6.0)
        var midis = [Note(chord.root, octave: 3).midi]
        midis += chord.pitchClasses.map { Note($0, octave: 4).midi }
        guard let buffer = Self.strumBuffer(midis: midis, seconds: seconds,
                                            stagger: 0.016,
                                            sampleRate: sampleRate,
                                            format: format) else { return }
        player.scheduleBuffer(buffer, at: nil)
        if !player.isPlaying { player.play() }
    }

    /// Play a scale as an ascending run (one octave plus the top root),
    /// one gentle tone per step. Buffers queue sequentially on the player.
    func playScale(_ scale: Scale, noteMs: Int = 280) {
        guard ensureRunning() else { return }
        player.stop()
        player.play()
        var midiNotes = scale.pitchClasses.map { Note($0, octave: 4).midi }
        // Keep the run ascending even when pitch classes wrap past B.
        for i in 1..<midiNotes.count where midiNotes[i] <= midiNotes[i - 1] {
            midiNotes[i] += 12
        }
        midiNotes.append(midiNotes[0] + 12)
        for midi in midiNotes {
            if let buffer = Self.toneBuffer(midi: midi,
                                            seconds: Double(noteMs) / 1000.0,
                                            sampleRate: sampleRate, format: format) {
                player.scheduleBuffer(buffer, at: nil)
            }
        }
    }

    /// Play chords back to back — a progression or a single resolution.
    func playProgression(_ chords: [Chord], eachMs: Int = 950) {
        guard ensureRunning() else { return }
        player.stop()
        player.play()
        let seconds = Double(eachMs) / 1000.0
        for chord in chords {
            var midis = [Note(chord.root, octave: 3).midi]
            midis += chord.pitchClasses.map { Note($0, octave: 4).midi }
            if let buffer = Self.strumBuffer(midis: midis, seconds: seconds,
                                             stagger: 0.014,
                                             sampleRate: sampleRate,
                                             format: format) {
                player.scheduleBuffer(buffer, at: nil)
            }
        }
    }

    /// Sound EXACT notes together (a voiced shape, not a generic pad).
    /// Queues after whatever is playing, so a ladder climbs voicing by
    /// voicing when called per rung.
    func playVoicing(_ notes: [Note], durationMs: Int = 560, restart: Bool = false) {
        guard ensureRunning() else { return }
        if restart { player.stop() }
        if !player.isPlaying { player.play() }
        let seconds = Double(durationMs) / 1000.0
        let frames = AVAudioFrameCount(sampleRate * seconds)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames
        _ = samples // silenced: the strum buffer below carries the audio
        guard let strummed = Self.strumBuffer(midis: notes.map(\.midi),
                                              seconds: seconds, stagger: 0.012,
                                              sampleRate: sampleRate,
                                              format: format) else { return }
        player.scheduleBuffer(strummed, at: nil)
    }

    /// Arpeggiate exact sounding notes — swung like a player (long-short
    /// eighth pairs), each note ringing into the next, the last held.
    func playRun(_ notes: [Note], noteMs: Int = 240) {
        guard ensureRunning() else { return }
        player.stop()
        player.play()
        let base = Double(noteMs) / 1000.0
        var onsets: [Double] = []
        var t = 0.0
        for i in notes.indices {
            onsets.append(t)
            t += base * (i % 2 == 0 ? 1.18 : 0.82)
        }
        let ring = base * 5
        let total = t + ring
        let frames = AVAudioFrameCount(sampleRate * total)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames
        for (i, note) in notes.enumerated() {
            let last = i == notes.count - 1
            let seconds = last ? ring : base * 2.2
            let offset = Int(sampleRate * onsets[i])
            let voice = Self.noteSamples(midi: note.midi, seconds: seconds,
                                         sampleRate: sampleRate,
                                         amplitude: last ? 0.62 : 0.5)
            for (j, v) in voice.enumerated() where offset + j < Int(frames) {
                samples[offset + j] += v
            }
        }
        player.scheduleBuffer(buffer, at: nil)
    }

    private static func toneBuffer(
        midi: Int, seconds: Double, sampleRate: Double, format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(sampleRate * seconds)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        let pluck = noteSamples(midi: midi, seconds: seconds,
                                sampleRate: sampleRate, amplitude: 0.8)
        for (i, v) in pluck.enumerated() where i < Int(frames) {
            samples[i] = v
        }
        return buffer
    }

    /// Karplus–Strong plucked string: a noise burst through an averaging
    /// delay line — the closest thing to a guitar with zero samples.
    private static func pluckSamples(
        midi: Int, seconds: Double, sampleRate: Double, amplitude: Double
    ) -> [Float] {
        let frequency = 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
        let period = max(2, Int(sampleRate / frequency))
        // Low-passed excitation (three smoothing passes): a felt-pick attack
        // instead of a white-noise snap. Mirrors web/src/audio.ts.
        var delayLine = (0..<period).map { _ in Double.random(in: -1...1) }
        for _ in 0..<3 {
            var previous = delayLine[period - 1]
            for i in 0..<period {
                let current = delayLine[i]
                delayLine[i] = 0.5 * (current + previous)
                previous = current
            }
        }
        let count = Int(sampleRate * seconds)
        var out = [Float](repeating: 0, count: count)
        var index = 0
        // High strings decay faster than wound bass strings.
        let damping = min(0.9985, max(0.988, 0.9995 - Double(midi - 40) * 0.00022))
        let attackFrames = sampleRate * 0.004
        for frame in 0..<count {
            let next = (index + 1) % period
            let sample = delayLine[index]
            delayLine[index] = damping * 0.5 * (delayLine[index] + delayLine[next])
            index = next
            // Soft attack in, gentle fade tail out, so nothing ever clicks.
            let tail = seconds - Double(frame) / sampleRate
            var env = tail < 0.08 ? tail / 0.08 : 1.0
            if Double(frame) < attackFrames { env *= Double(frame) / attackFrames }
            out[frame] = Float(sample * amplitude * env)
        }
        return out
    }

    /// Mix plucks into one buffer, each voice offset like a strum.
    private static func strumBuffer(
        midis: [Int], seconds: Double, stagger: Double,
        sampleRate: Double, format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(sampleRate * seconds)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        let amplitude = 0.75 / Double(max(midis.count, 1)).squareRoot()
        for (voice, midi) in midis.enumerated() {
            let offset = Int(sampleRate * stagger * Double(voice))
            let remaining = Double(Int(frames) - offset) / sampleRate
            guard remaining > 0.05 else { continue }
            let pluck = noteSamples(midi: midi, seconds: remaining,
                                     sampleRate: sampleRate, amplitude: amplitude)
            for (i, v) in pluck.enumerated() {
                samples[offset + i] += v
            }
        }
        return buffer
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
