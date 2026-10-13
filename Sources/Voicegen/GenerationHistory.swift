import Foundation
import Combine

struct GenerationEntry: Codable, Identifiable, Equatable {
    /// WAV filename is stable across launches.
    let id: String
    let text: String
    let language: String
    let voice: String
    let createdAt: Date
}

@MainActor
final class GenerationHistory: ObservableObject {
    @Published private(set) var entries: [GenerationEntry] = []

    static let directory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Generated", isDirectory: true)
    }()

    private var indexURL: URL { Self.directory.appendingPathComponent("history.json") }

    init() {
        try? FileManager.default.createDirectory(at: Self.directory,
                                                  withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL),
           let saved = try? JSONDecoder().decode([GenerationEntry].self, from: data) {
            entries = saved.filter { FileManager.default.fileExists(atPath: url(for: $0).path) }
        }
        recoverPreviousAudio()
    }

    func url(for entry: GenerationEntry) -> URL {
        Self.directory.appendingPathComponent(entry.id)
    }

    func add(audioURL: URL, text: String, language: String, voice: String) throws {
        let entry = GenerationEntry(
            id: audioURL.lastPathComponent,
            text: text,
            language: language,
            voice: voice,
            createdAt: Date())
        let previous = entries
        entries.removeAll { $0.id == entry.id }
        entries.insert(entry, at: 0)
        do { try persist() }
        catch {
            entries = previous
            throw error
        }
    }

    func delete(_ entry: GenerationEntry) throws {
        let file = url(for: entry)
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
        entries.removeAll { $0.id == entry.id }
        try persist()
    }

    /// Old Voicegen versions wrote WAV files without metadata. Keep them visible.
    private func recoverPreviousAudio() {
        let known = Set(entries.map(\.id))
        let files = (try? FileManager.default.contentsOfDirectory(
            at: Self.directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles])) ?? []
        let recovered: [GenerationEntry] = files.compactMap { file in
            guard file.pathExtension.lowercased() == "wav",
                  !known.contains(file.lastPathComponent) else { return nil }
            let created = (try? file.resourceValues(forKeys: [.creationDateKey]))?
                .creationDate ?? Date.distantPast
            return GenerationEntry(id: file.lastPathComponent, text: "",
                                   language: "", voice: "Previous generation",
                                   createdAt: created)
        }
        if !recovered.isEmpty {
            entries.append(contentsOf: recovered)
            entries.sort { $0.createdAt > $1.createdAt }
            try? persist()
        }
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(entries)
        try data.write(to: indexURL, options: .atomic)
    }
}
