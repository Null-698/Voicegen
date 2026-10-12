import Foundation
import Combine
import AVFoundation
import ChatterboxCoreML

enum VoicegenError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case .message(let value) = self { return value }
        return nil
    }
}

@MainActor
final class VoiceEngine: ObservableObject {
    @Published private(set) var status = "Model required"
    @Published private(set) var progress: Double = 0
    @Published private(set) var downloading = false
    @Published private(set) var paused = false
    @Published private(set) var loading = false
    @Published private(set) var generating = false
    @Published private(set) var isReady = false
    @Published private(set) var lastOutput: URL?
    @Published var alert: String?

    private var model: ChatterboxCoreMLModel?
    private var downloadTask: Task<Void, Never>?
    private var player: AVAudioPlayer?

    private let repo = ModelRepository.Variant.multilingual
    private var home: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var modelDirectory: URL? {
        ModelRepository.existingModelDirectory(hfHome: home, repoId: repo.repoId)
    }

    init() {
        status = "Checking model"
        if modelDirectory != nil { status = "Tap to load model" }
        else { status = "Download model to begin" }
    }

    func load() {
        guard !loading, !downloading, !isReady, let dir = modelDirectory else { return }
        loading = true
        status = "Preparing model"
        Task {
            do {
                guard ModelRepository.isMultilingualModelDirectory(dir) else {
                    throw VoicegenError.message("Model is incomplete. Resume downloading.")
                }
                // Russian accents are resolved locally once the optional stress model is cached.
                let stress = await RuAccentStress.makeOrFallback(downloadHFHome: home, hfToken: nil)
                let loaded = try await ChatterboxCoreMLModel.load(from: dir, russianStress: stress)
                self.model = loaded
                isReady = true
                status = "Ready · Offline"
            } catch {
                status = "Model not ready"
                alert = error.localizedDescription
            }
            loading = false
        }
    }

    func startDownload() {
        guard !downloading else { return }
        downloading = true
        paused = false
        progress = 0
        status = "Downloading model"
        downloadTask = Task {
            do {
                let result = try await ModelRepository.download(
                    repoId: repo.repoId,
                    hfHome: home,
                    matching: repo.runtimeGlobs
                ) { [weak self] fraction in
                    Task { @MainActor [weak self] in
                        guard let self, self.downloading, !self.paused else { return }
                        self.progress = fraction
                    }
                }
                guard !Task.isCancelled else { return }
                if result.isPartiallyApplied || !result.stillStale.isEmpty ||
                    !ModelRepository.isMultilingualModelDirectory(result.directory) {
                    throw VoicegenError.message("Some files are missing. Tap Resume to retry.")
                }
                downloading = false
                progress = 1
                status = "Downloaded"
                load()
            } catch {
                guard !Task.isCancelled else { return }
                downloading = false
                paused = true
                status = "Download incomplete"
                alert = error.localizedDescription
            }
        }
    }

    func pauseDownload() {
        guard downloading else { return }
        downloading = false
        paused = true
        status = "Paused"
        downloadTask?.cancel()
    }

    func resumeDownload() {
        guard !downloading else { return }
        // Wait for the cancelled snapshot task to stop writing before retrying.
        let previous = downloadTask
        downloadTask = nil
        Task {
            await previous?.value
            guard !self.downloading else { return }
            self.startDownload()
        }
    }

    func generate(text: String, language: String, voiceURL: URL?) {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { alert = "Enter text to speak."; return }
        guard let model else { alert = "Download and load the model first."; return }
        guard !generating else { return }
        generating = true
        status = "Generating"
        lastOutput = nil
        Task {
            do {
                let options = GenerationOptions.multilingual(
                    language: language, exaggeration: 0.6, cfgWeight: 0.5)
                let audio = try await model.generate(content, voice: voiceURL, options: options)
                let outputDir = home.appendingPathComponent("Generated", isDirectory: true)
                try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
                let target = outputDir.appendingPathComponent("voicegen-\(UUID().uuidString).wav")
                do {
                    let writer = try AVAudioFile(forWriting: target, settings: audio.format.settings)
                    try writer.write(from: audio)
                } // Close the file before opening it for playback.
                lastOutput = target
                status = "Ready · Offline"
                play()
            } catch {
                status = "Generation failed"
                alert = error.localizedDescription
            }
            generating = false
        }
    }

    func play() {
        guard let lastOutput else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: lastOutput)
            player?.prepareToPlay()
            player?.play()
        } catch { alert = error.localizedDescription }
    }
}
