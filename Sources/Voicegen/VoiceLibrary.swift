import Foundation
import Combine
import ChatterboxCoreML

struct SavedVoice: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    let fileName: String
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

    init() { reload() }

    func url(for voice: SavedVoice) -> URL {
        Self.folder.appendingPathComponent(voice.fileName)
    }

    func reload() {
        guard let data = try? Data(contentsOf: indexURL),
              let saved = try? JSONDecoder().decode([SavedVoice].self, from: data)
        else { voices = []; return }
        voices = saved.filter { FileManager.default.fileExists(atPath: url(for: $0).path) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func clone(name: String, from source: URL, modelDirectory: URL) async throws -> SavedVoice {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VoicegenError.message("Enter a voice name.") }
        let entry = SavedVoice(id: UUID(), name: trimmed,
                               fileName: "\(UUID().uuidString)-conds.safetensors",
                               createdAt: Date())
        let destination = url(for: entry)
        try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        // Creating the embedding can be computationally expensive. Do not block SwiftUI.
        let output = try await Task.detached(priority: .userInitiated) {
            let cloner = try await VoiceCloner(modelDirectory: modelDirectory)
            try cloner.cloneVoice(from: source, to: destination)
            return destination
        }.value
        guard FileManager.default.fileExists(atPath: output.path) else {
            throw VoicegenError.message("Voice was not saved.")
        }
        voices.insert(entry, at: 0)
        do { try save() } catch {
            voices.removeAll { $0.id == entry.id }
            try? FileManager.default.removeItem(at: output)
            throw error
        }
        return entry
    }

    func remove(_ voice: SavedVoice) {
        voices.removeAll { $0.id == voice.id }
        try? FileManager.default.removeItem(at: url(for: voice))
        try? save()
    }

    private func save() throws {
        let data = try JSONEncoder().encode(voices)
        try data.write(to: indexURL, options: .atomic)
    }
}
