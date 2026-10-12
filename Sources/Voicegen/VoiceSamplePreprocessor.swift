import AVFoundation
import Foundation

/// Keeps reference audio inside VEMel's 16 kHz, 640,000-sample Core ML input limit.
/// Use 30 seconds (480,000 samples at 16 kHz) for margin in resampling.
enum VoiceSamplePreprocessor {
    static let maxDuration: TimeInterval = 30

    struct PreparedSample: Sendable {
        let url: URL
        let isTemporary: Bool

        func cleanup() {
            if isTemporary { try? FileManager.default.removeItem(at: url) }
        }
    }

    static func prepare(_ source: URL) throws -> PreparedSample {
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let maxFrames = AVAudioFramePosition(maxDuration * format.sampleRate)

        // Short recordings pass through unchanged; both imported and recorded
        // samples take the same path through the cloner.
        guard input.length > maxFrames else {
            return PreparedSample(url: source, isTemporary: false)
        }

        let requestedFrames = AVAudioFrameCount(maxFrames)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: requestedFrames) else {
            throw VoicegenError.message("Could not prepare this voice sample.")
        }
        try input.read(into: buffer, frameCount: requestedFrames)
        guard buffer.frameLength > 0 else {
            throw VoicegenError.message("Audio file is empty or unsupported.")
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("voicegen-reference-\(UUID().uuidString).caf")
        do {
            let output = try AVAudioFile(forWriting: destination, settings: format.settings)
            try output.write(from: buffer)
            return PreparedSample(url: destination, isTemporary: true)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
}
