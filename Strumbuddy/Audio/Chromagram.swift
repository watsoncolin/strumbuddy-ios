import Foundation
import Accelerate

/// Polyphonic analysis (design-doc §4 polyphonic path). Computes a chromagram:
/// energy in each of the 12 pitch classes, folded across octaves. This is the
/// backbone of BOTH chord identity and cleanliness grading — built on Accelerate's
/// vDSP FFT (first-party, no copyleft), per the §4 licensing note.
///
/// Pure (no AVFoundation): operates on raw `[Float]` samples so it's unit-testable
/// off-device. Reference type because it owns an FFT setup reused across buffers.
final class Chromagram {
    private let fftSize: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private var window: [Float]

    init(fftSize: Int = 4096) {
        self.fftSize = fftSize
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    deinit { vDSP_destroy_fftsetup(fftSetup) }

    /// 12 normalized pitch-class energies (index 0 = C … 11 = B) for the first
    /// `fftSize` samples. Returns all-zero if there aren't enough samples.
    func compute(_ samples: [Float], sampleRate: Float) -> [Float] {
        guard samples.count >= fftSize else { return zero }

        // Window the first fftSize samples.
        var windowed = [Float](repeating: 0, count: fftSize)
        samples.withUnsafeBufferPointer { src in
            vDSP_vmul(src.baseAddress!, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))
        }

        // Real FFT via split-complex packing.
        let half = fftSize / 2
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer { wptr in
                    wptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) { cptr in
                        vDSP_ctoz(cptr, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(half))
            }
        }

        // Fold each bin into its pitch class (12-TET, A4 = 440).
        var chroma = [Float](repeating: 0, count: 12)
        let binWidth = sampleRate / Float(fftSize)
        for bin in 1..<half {
            let freq = Float(bin) * binWidth
            guard freq >= 70, freq <= 2000 else { continue }   // guitar-ish range
            let midi = 69 + 12 * log2(freq / 440)
            let pitchClass = ((Int(midi.rounded()) % 12) + 12) % 12
            chroma[pitchClass] += magnitudes[bin]
        }

        // Normalize so detection is amplitude-independent.
        var maxVal: Float = 0
        vDSP_maxv(chroma, 1, &maxVal, 12)
        if maxVal > 0 { vDSP_vsdiv(chroma, 1, &maxVal, &chroma, 1, 12) }
        return chroma
    }

    private var zero: [Float] { Array(repeating: 0, count: 12) }
}
