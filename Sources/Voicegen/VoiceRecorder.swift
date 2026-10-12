import Foundation
import AVFoundation
import Combine

@MainActor
final class VoiceRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var recordedURL: URL?
    @Published private(set) var duration: TimeInterval = 0
    @Published var error: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func start() {
        Task {
            let permitted = await AVAudioApplication.requestRecordPermission()
            guard permitted else { error = "Microphone permission denied."; return }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try session.setActive(true)
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("voice-\(UUID().uuidString).m4a")
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 24000,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                let audio = try AVAudioRecorder(url: url, settings: settings)
                guard audio.record() else { throw VoicegenError.message("Could not start recording.") }
                recorder = audio
                recordedURL = nil
                duration = 0
                isRecording = true
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        guard let self else { return }
                        self.duration = self.recorder?.currentTime ?? self.duration
                    }
                }
            } catch { self.error = error.localizedDescription }
        }
    }

    func stop() {
        recorder?.stop()
        recordedURL = recorder?.url
        recorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func discard() {
        if isRecording { stop() }
        if let recordedURL { try? FileManager.default.removeItem(at: recordedURL) }
        recordedURL = nil
        duration = 0
    }
}
