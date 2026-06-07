import Foundation
import AVFoundation

/// Decodes a user-supplied audio file to mono float samples for offline analysis
/// (BYO-song). Capped length keeps the debug harness snappy and memory-light.
enum AudioFileLoader {
    static func loadMono(url: URL, maxSeconds: Double = 90) throws -> (samples: [Float], sampleRate: Double) {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let sampleRate = format.sampleRate

        let cap = AVAudioFrameCount(min(Double(file.length), maxSeconds * sampleRate))
        guard cap > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: cap) else {
            throw NSError(domain: "AudioFileLoader", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Couldn't read that audio file."])
        }
        try file.read(into: buffer, frameCount: cap)

        let frames = Int(buffer.frameLength)
        guard frames > 0, let channels = buffer.floatChannelData else {
            throw NSError(domain: "AudioFileLoader", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No audio in that file."])
        }

        // Sum channels to mono.
        let channelCount = Int(format.channelCount)
        var mono = [Float](repeating: 0, count: frames)
        for c in 0..<channelCount {
            let p = channels[c]
            for i in 0..<frames { mono[i] += p[i] }
        }
        if channelCount > 1 {
            let inv = 1 / Float(channelCount)
            for i in 0..<frames { mono[i] *= inv }
        }
        return (mono, sampleRate)
    }
}
