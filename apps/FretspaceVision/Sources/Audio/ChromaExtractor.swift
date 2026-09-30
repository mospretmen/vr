import AVFoundation
import Accelerate
import AudioAnalysis
import MusicTheory

/// Mic → chromagram pipeline for "listen" mode (Phase 3).
///
/// Taps the input node, windows + FFTs each buffer, folds spectral energy
/// into 12 pitch-class bins over the guitar's range, and yields a
/// `Chromagram` per hop. All recognition logic lives in the testable
/// `AudioAnalysis` package; this class is only the signal front-end.
@MainActor
final class ChromaExtractor {
    static let sampleRate: Double = 44_100
    static let fftSize = 4096                    // ~93 ms window, ~10.8 Hz bins
    /// Guitar fundamentals: E2 (82 Hz) up to ~E6 (1319 Hz) covers fret 24.
    static let minFrequency = 75.0
    static let maxFrequency = 1350.0

    private let engine = AVAudioEngine()
    private let fft: vDSP.FFT<DSPSplitComplex>
    private var window: [Float]

    init?() {
        let log2n = vDSP_Length(log2(Double(Self.fftSize)))
        guard let fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self) else {
            return nil
        }
        self.fft = fft
        self.window = vDSP.window(ofType: Float.self,
                                  usingSequence: .hanningDenormalized,
                                  count: Self.fftSize,
                                  isHalfWindow: false)
    }

    /// Streams one chromagram per audio buffer until the task is cancelled.
    /// Caller must have obtained mic permission first.
    func chromagrams() -> AsyncStream<Chromagram> {
        AsyncStream { continuation in
            // Measurement mode disables system voice processing (AGC, echo
            // cancellation) that would smear the guitar's spectrum.
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .measurement,
                                             options: [.mixWithOthers])
                try audioSession.setActive(true)
            } catch {
                AppLog.audio.error("Audio session activation failed: \(error)")
                continuation.finish()
                return
            }

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)

            input.installTap(onBus: 0,
                             bufferSize: AVAudioFrameCount(Self.fftSize),
                             format: format) { [weak self] buffer, _ in
                guard let self,
                      let chroma = self.extract(from: buffer, sampleRate: format.sampleRate) else { return }
                continuation.yield(chroma)
            }

            do {
                try engine.start()
            } catch {
                continuation.finish()
                return
            }

            continuation.onTermination = { [engine] _ in
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
            }
        }
    }

    /// Window → FFT → magnitude → fold bins into pitch classes.
    nonisolated private func extract(from buffer: AVAudioPCMBuffer, sampleRate: Double) -> Chromagram? {
        guard let channel = buffer.floatChannelData?[0],
              buffer.frameLength >= AVAudioFrameCount(Self.fftSize) else { return nil }

        var samples = [Float](UnsafeBufferPointer(start: channel, count: Self.fftSize))
        vDSP.multiply(samples, window, result: &samples)

        var real = [Float](repeating: 0, count: Self.fftSize / 2)
        var imaginary = [Float](repeating: 0, count: Self.fftSize / 2)
        var magnitudes = [Float](repeating: 0, count: Self.fftSize / 2)

        real.withUnsafeMutableBufferPointer { realPtr in
            imaginary.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!,
                                            imagp: imagPtr.baseAddress!)
                samples.withUnsafeBytes {
                    $0.baseAddress!.withMemoryRebound(to: DSPComplex.self,
                                                      capacity: Self.fftSize / 2) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(Self.fftSize / 2))
                    }
                }
                fft.forward(input: split, output: &split)
                vDSP.squareMagnitudes(split, result: &magnitudes)
            }
        }

        // Fold spectral bins into pitch classes across the guitar's range.
        var energies = [Double](repeating: 0, count: 12)
        let binHz = sampleRate / Double(Self.fftSize)
        let firstBin = max(1, Int(Self.minFrequency / binHz))
        let lastBin = min(magnitudes.count - 1, Int(Self.maxFrequency / binHz))
        guard firstBin < lastBin else { return nil }

        for bin in firstBin...lastBin {
            let frequency = Double(bin) * binHz
            let midi = 69.0 + 12.0 * log2(frequency / 440.0)
            let pitchClass = ((Int(midi.rounded()) % 12) + 12) % 12
            energies[pitchClass] += Double(magnitudes[bin])
        }
        return Chromagram(energies: energies)
    }
}
