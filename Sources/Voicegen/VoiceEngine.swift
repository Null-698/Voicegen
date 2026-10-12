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

enum RUAccentAvailability: Equatable {
    case unknown
    case checking
    case active
    case unavailable
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
    @Published private(set) var ruAccentAvailability: RUAccentAvailability = .unknown
    @Published private(set) var loadingPhase = ""
    @Published private(set) var loadingElapsed = 0
    @Published private(set) var generationElapsed = 0
    @Published private(set) var lastOutput: URL?
    @Published var alert: String?

    private var model: ChatterboxCoreMLModel?
    private var downloadTask: Task<Void, Never>?
    private var player: AVAudioPlayer?
    private var loadingTimer: Timer?
    private var generationTimer: Timer?
    private var loadStartedAt: Date?
    private var generationStartedAt: Date?
    private var predictedLoadDuration: TimeInterval?
    private var predictedGenerationDuration: TimeInterval?

    private static let loadHistoryKey = "voicegen.timing.modelLoad"
    private static let generateHistoryPrefix = "voicegen.timing.generate."

    var loadingTimingText: String {
        Self.timingText(elapsed: loadingElapsed, estimate: predictedLoadDuration)
    }

    var generationTimingText: String {
        Self.timingText(elapsed: generationElapsed, estimate: predictedGenerationDuration)
    }

    private static func timingText(elapsed: Int, estimate: TimeInterval?) -> String {
        if let estimate, estimate.isFinite, estimate > 0 {
            let remaining = Int(ceil(estimate - Double(elapsed)))
            if remaining > 0 {
                return "~\(clock(remaining)) left · \(clock(elapsed)) elapsed"
            }
            return "Longer than expected · \(clock(elapsed)) elapsed"
        }
        return "Estimating… · \(clock(elapsed)) elapsed"
    }

    private static func clock(_ seconds: Int) -> String {
        let seconds = max(seconds, 0)
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600,
                          (seconds % 3600) / 60, seconds % 60)
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func beginLoadClock() {
        loadingTimer?.invalidate()
        loadingElapsed = 0
        loadStartedAt = Date()
        let baseline = UserDefaults.standard.double(forKey: Self.loadHistoryKey)
        predictedLoadDuration = baseline > 0 ? baseline : nil
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.loadStartedAt else { return }
                self.loadingElapsed = Int(Date().timeIntervalSince(start))
            }
        }
    }

    private func endLoadClock(success: Bool) {
        loadingTimer?.invalidate()
        loadingTimer = nil
        if success, let start = loadStartedAt {
            let duration = Date().timeIntervalSince(start)
            if duration > 0 {
                let old = UserDefaults.standard.double(forKey: Self.loadHistoryKey)
                let average = old > 0 ? (old * 0.6 + duration * 0.4) : duration
                UserDefaults.standard.set(average, forKey: Self.loadHistoryKey)
            }
        }
        loadStartedAt = nil
    }

    private func beginGenerationClock(characters: Int, language: String) {
        generationTimer?.invalidate()
        generationElapsed = 0
        generationStartedAt = Date()
        let rate = UserDefaults.standard.double(forKey: Self.generateHistoryPrefix + language)
        predictedGenerationDuration = rate > 0 ? rate * Double(characters) : nil
        generationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.generationStartedAt else { return }
                self.generationElapsed = Int(Date().timeIntervalSince(start))
            }
        }
    }

    private func endGenerationClock(success: Bool, characters: Int, language: String) {
        generationTimer?.invalidate()
        generationTimer = nil
        if success, let start = generationStartedAt, characters > 0 {
            let duration = Date().timeIntervalSince(start)
            if duration > 0 {
                let key = Self.generateHistoryPrefix + language
                let rate = duration / Double(characters)
                let old = UserDefaults.standard.double(forKey: key)
                let average = old > 0 ? (old * 0.6 + rate * 0.4) : rate
                UserDefaults.standard.set(average, forKey: key)
            }
        }
        generationStartedAt = nil
    }

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
        guard !loading, !downloading, !generating, !isReady,
              let dir = modelDirectory else { return }
        loading = true
        loadingPhase = "Checking Russian stress"
        ruAccentAvailability = .checking
        status = "Preparing model"
        beginLoadClock()
        Task {
            var succeeded = false
            do {
                guard ModelRepository.isMultilingualModelDirectory(dir) else {
                    throw VoicegenError.message("Model is incomplete. Resume downloading.")
                }
                // The factory silently falls back when RUAccent fails. Inspect the
                // concrete result rather than treating a folder as proof of success.
                let stress = await RuAccentStress.makeOrFallback(
                    downloadHFHome: home, hfToken: nil)
                let hasRUAccent = stress is RuAccentStress
                loadingPhase = "Loading speech model"
                let loaded = try await ChatterboxCoreMLModel.load(
                    from: dir, russianStress: stress)
                self.model = loaded
                ruAccentAvailability = hasRUAccent ? .active : .unavailable
                isReady = true
                status = "Ready · Offline"
                succeeded = true
            } catch {
                ruAccentAvailability = .unknown
                status = "Model not ready"
                alert = error.localizedDescription
            }
            endLoadClock(success: succeeded)
            loading = false
        }
    }

    func retryRUAccent() {
        guard isReady, ruAccentAvailability == .unavailable,
              !loading, !downloading, !generating else { return }
        model = nil
        isReady = false
        load()
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
        beginGenerationClock(characters: content.count, language: language)
        Task {
            var succeeded = false
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
                succeeded = true
                play()
            } catch {
                status = "Generation failed"
                alert = error.localizedDescription
            }
            endGenerationClock(success: succeeded, characters: content.count, language: language)
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
