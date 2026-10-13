import Foundation
import Combine
import ChatterboxCoreML

struct SavedVoice: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    let fileName: String
    // Optional for backward compatibility: earlier versions saved only the embedding.
    var sampleFileName: String?
    let createdAt: Date
}

@MainActor
final class VoiceLibrary: ObservableObject {
    @Published private(set) var voices: [SavedVoice] = []

    static let folder: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Voices", isDirectory: true)
    }()
    private var indexURL: URL { Self.folder.appendingPathComponent("index.json") }
    private static var samplesFolder: URL {
        folder.appendingPathComponent("Samples", isDirectory: true)
    }

    func sampleURL(for voice: SavedVoice) -> URL? {
        guard let fileName = voice.sampleFileName else { return nil }
        let url = Self.samplesFolder.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    init() { reload() }

    func url(for voice: SavedVoice) -> URL {
        Self.folder.appendingPathComponent(voice.fileName)
    }

    func reload() {
        // Never blank a live list when the sandbox index is briefly inaccessible.
        guard let data = try? Data(contentsOf: indexURL),
              let saved = try? JSONDecoder().decode([SavedVoice].self, from: data)
        else { return }
        let available = saved.filter {
            FileManager.default.fileExists(atPath: url(for: $0).path)
        }.sorted { $0.createdAt > $1.createdAt }
        if available != voices { voices = available }
    }

    func clone(name: String, from source: URL, modelDirectory: URL) async throws -> SavedVoice {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VoicegenError.message("Enter a voice name.") }
        let entry = SavedVoice(id: UUID(), name: trimmed,
                               fileName: "\(UUID().uuidString)-conds.safetensors",
                               sampleFileName: "\(UUID().uuidString).caf",
                               createdAt: Date())
        let destination = url(for: entry)
        let preview = Self.samplesFolder.appendingPathComponent(entry.sampleFileName!)
        try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        let output = try await Task.detached(priority: .userInitiated) {
            let prepared = try VoiceSamplePreprocessor.prepare(source)
            defer { prepared.cleanup() }
            do {
                // Retain the exact reference clip used for cloning.
                try VoiceSamplePreprocessor.savePreview(prepared.url, to: preview)
                let cloner = try await VoiceCloner(modelDirectory: modelDirectory)
                try cloner.cloneVoice(from: prepared.url, to: destination)
                return destination
            } catch {
                try? FileManager.default.removeItem(at: destination)
                try? FileManager.default.removeItem(at: preview)
                throw error
            }
        }.value
        guard FileManager.default.fileExists(atPath: output.path) else {
            throw VoicegenError.message("Voice was not saved.")
        }
        voices.insert(entry, at: 0)
        do { try save() } catch {
            voices.removeAll { $0.id == entry.id }
            try? FileManager.default.removeItem(at: output)
            try? FileManager.default.removeItem(at: preview)
            throw error
        }
        return entry
    }

    /// For existing clones made before source audio was retained, let users
    /// restore the original reference recording without changing the embedding.
    func attachSample(from source: URL, to voice: SavedVoice) async throws {
        guard let index = voices.firstIndex(where: { $0.id == voice.id }) else {
            throw VoicegenError.message("Voice no longer exists.")
        }
        let fileName = "\(UUID().uuidString).caf"
        let destination = Self.samplesFolder.appendingPathComponent(fileName)
        try await Task.detached(priority: .userInitiated) {
            let prepared = try VoiceSamplePreprocessor.prepare(source)
            defer { prepared.cleanup() }
            try VoiceSamplePreprocessor.savePreview(prepared.url, to: destination)
        }.value
        let previous = voices[index]
        voices[index].sampleFileName = fileName
        do {
            try save()
        } catch {
            voices[index] = previous
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        if let previousName = previous.sampleFileName {
            try? FileManager.default.removeItem(
                at: Self.samplesFolder.appendingPathComponent(previousName))
        }
    }

    func remove(_ voice: SavedVoice) {
        if UserDefaults.standard.string(forKey: "voicegen.selectedVoice") == voice.id.uuidString {
            UserDefaults.standard.set("default", forKey: "voicegen.selectedVoice")
        }
        voices.removeAll { $0.id == voice.id }
        try? FileManager.default.removeItem(at: url(for: voice))
        if let filename = voice.sampleFileName {
            try? FileManager.default.removeItem(
                at: Self.samplesFolder.appendingPathComponent(filename))
        }
        try? save()
    }

    private func save() throws {
        let data = try JSONEncoder().encode(voices)
        try data.write(to: indexURL, options: .atomic)
    }
}
