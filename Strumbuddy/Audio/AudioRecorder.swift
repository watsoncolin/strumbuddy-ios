import Foundation
import AVFoundation
import Accelerate

/// Captures mic audio into a contiguous mono buffer for offline analysis (BYO-song
/// "listen" path — play a song near the phone). Separate from the live `AudioEngine`;
/// they're never used at once. Capped length bounds memory and keeps analysis quick.
@MainActor
final class AudioRecorder: ObservableObject {
    enum Status: Equatable { case idle, recording, denied, failed(String) }

    @Published private(set) var status: Status = .idle
    @Published private(set) var seconds: Double = 0
    @Published private(set) var level: Float = 0

    let maxSeconds: Double = 40

    private let engine = AVAudioEngine()
    private var buffer: [Float] = []
    private var sampleRate: Double = 44_100
    private var frameCount = 0
    private var capFrames = 0

    func start() async {
        guard await Self.requestMic() else { status = .denied; return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            sampleRate = format.sampleRate
            capFrames = Int(maxSeconds * sampleRate)
            frameCount = 0
            buffer = []
            buffer.reserveCapacity(capFrames)

            input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buf, _ in
                guard let self, let channel = buf.floatChannelData?[0] else { return }
                let n = Int(buf.frameLength)
                if self.frameCount < self.capFrames {
                    self.buffer.append(contentsOf: UnsafeBufferPointer(start: channel, count: n))
                    self.frameCount += n
                }
                var rms: Float = 0
                vDSP_rmsqv(channel, 1, &rms, vDSP_Length(n))
                let secs = Double(self.frameCount) / self.sampleRate
                Task { @MainActor in
                    self.level = rms
                    self.seconds = secs
                }
            }
            engine.prepare()
            try engine.start()
            status = .recording
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Stop and return the captured mono samples.
    @discardableResult
    func stop() -> (samples: [Float], sampleRate: Double) {
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        status = .idle
        return (buffer, sampleRate)
    }

    private static func requestMic() async -> Bool {
        await withCheckedContinuation { cont in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in cont.resume(returning: granted) }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in cont.resume(returning: granted) }
            }
        }
    }
}
