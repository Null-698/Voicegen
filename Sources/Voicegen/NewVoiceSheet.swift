import SwiftUI
import UniformTypeIdentifiers

struct NewVoiceSheet: View {
    @EnvironmentObject private var engine: VoiceEngine
    @EnvironmentObject private var library: VoiceLibrary
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = VoiceRecorder()

    @State private var name = ""
    @State private var importedURL: URL?
    @State private var importing = false
    @State private var consent = false
    @State private var isCloning = false
    @State private var error: String?

    private var source: URL? { recorder.recordedURL ?? importedURL }

    private var canSave: Bool {
        source != nil && consent && engine.isReady && !isCloning &&
        !recorder.isRecording && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            TextField("Voice name", text: $name)
                                .font(.title3)
                                .textInputAutocapitalization(.words)
                            Divider()
                            Text("VOICE SAMPLE")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.55))
                            HStack(spacing: 12) {
                                Button {
                                    if recorder.isRecording { recorder.stop() }
                                    else {
                                        importedURL = nil
                                        recorder.start()
                                    }
                                } label: {
                                    Label(recorder.isRecording ? "Stop" : "Record",
                                          systemImage: recorder.isRecording ? "stop.fill" : "mic.fill")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(recorder.isRecording ? .red : Color(red: 0.62, green: 0.73, blue: 1))
                                Button { importing = true } label: {
                                    Label("Import", systemImage: "square.and.arrow.down")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.bordered)
                                .disabled(recorder.isRecording || isCloning)
                            }
                            if recorder.isRecording {
                                HStack(spacing: 8) {
                                    Circle().fill(.red).frame(width: 8, height: 8)
                                    Text(recorder.duration, format: .number.precision(.fractionLength(1)))
                                        .monospacedDigit()
                                    Text("seconds")
                                }
                                .font(.caption)
                            }
                            if let source {
                                Label(source.lastPathComponent, systemImage: "checkmark.circle.fill")
                                    .lineLimit(1)
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    Text("Use 20–30 seconds of clear speech. Longer clips are trimmed.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 4)

                    Toggle("I have permission to use this voice", isOn: $consent)
                        .tint(Color(red: 0.62, green: 0.73, blue: 1))
                        .padding(.horizontal, 5)

                    Button {
                        clone()
                    } label: {
                        HStack(spacing: 10) {
                            if isCloning { ProgressView().tint(.black) }
                            else { Image(systemName: "sparkles") }
                            Text(isCloning ? "Cloning voice…" : "Create voice")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.62, green: 0.73, blue: 1))
                    .foregroundStyle(.black)
                    .disabled(!canSave)

                    if let error {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                    if let micError = recorder.error {
                        Text(micError).foregroundStyle(.red).font(.footnote)
                    }
                }
                .padding(20)
            }
            .background(StudioBackdrop())
            .navigationTitle("New voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.disabled(isCloning)
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio],
                          allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let destination = FileManager.default.temporaryDirectory
                            .appendingPathComponent("\(UUID().uuidString).\(url.pathExtension)")
                        try FileManager.default.copyItem(at: url, to: destination)
                        recorder.discard()
                        importedURL = destination
                    } catch {
                        self.error = error.localizedDescription
                    }
                case .failure(let failure):
                    error = failure.localizedDescription
                }
            }
            .onDisappear {
                recorder.discard()
                if let importedURL { try? FileManager.default.removeItem(at: importedURL) }
            }
        }
    }

    private func clone() {
        guard let source, let modelDirectory = engine.modelDirectory, canSave else { return }
        isCloning = true
        error = nil
        Task {
            do {
                let voice = try await library.clone(name: name, from: source, modelDirectory: modelDirectory)
                UserDefaults.standard.set(voice.id.uuidString, forKey: "voicegen.selectedVoice")
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isCloning = false
        }
    }
}
