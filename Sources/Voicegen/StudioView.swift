import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

private enum StudioStyle {
    static let accent = Color(red: 0.62, green: 0.73, blue: 1.0)
    static let subtle = Color.white.opacity(0.66)
}

struct StudioBackdrop: View {
    var body: some View {
        ZStack {
            Color(red: 0.045, green: 0.06, blue: 0.11)
            RadialGradient(
                colors: [Color(red: 0.24, green: 0.23, blue: 0.48).opacity(0.72), .clear],
                center: .topTrailing, startRadius: 20, endRadius: 490)
            RadialGradient(
                colors: [Color(red: 0.08, green: 0.32, blue: 0.37).opacity(0.38), .clear],
                center: .bottomLeading, startRadius: 0, endRadius: 350)
        }
        .ignoresSafeArea()
    }
}

struct GlassPanel<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
    }
}

struct StudioView: View {
    @State private var showModel = false

    var body: some View {
        TabView {
            GenerateView(showModel: $showModel)
                .tabItem { Label("Generate", systemImage: "waveform") }
            VoicesView(showModel: $showModel)
                .tabItem { Label("Voices", systemImage: "person.2.wave.2") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
        .tint(StudioStyle.accent)
        .sheet(isPresented: $showModel) { ModelSheet() }
        .modifier(EnginePresentation())
    }
}

/// Engine's timer updates must not invalidate the TabView parent every second.
private struct EnginePresentation: ViewModifier {
    @EnvironmentObject private var engine: VoiceEngine

    func body(content: Content) -> some View {
        content
            .alert("Voicegen", isPresented: Binding(
                get: { engine.alert != nil },
                set: { if !$0 { engine.alert = nil } }
            )) {
                Button("OK", role: .cancel) { engine.alert = nil }
            } message: {
                Text(engine.alert ?? "")
            }
            .task {
                if engine.modelDirectory != nil && !engine.isReady { engine.load() }
            }
    }
}

struct GenerateView: View {
    @EnvironmentObject private var engine: VoiceEngine
    @EnvironmentObject private var library: VoiceLibrary
    @EnvironmentObject private var history: GenerationHistory
    @EnvironmentObject private var playback: PlaybackController
    @Binding var showModel: Bool
    @AppStorage("voicegen.language") private var language = "ru"
    @AppStorage("voicegen.selectedVoice") private var selectedVoice = "default"
    @AppStorage("voicegen.sentencePause") private var sentencePause = 0.15
    @AppStorage("voicegen.commaPause") private var commaPause = 0.05
    @State private var text = ""

    private var chosenURL: URL? {
        guard let voice = library.voices.first(where: { $0.id.uuidString == selectedVoice }) else {
            return nil
        }
        return library.url(for: voice)
    }

    private var selectedVoiceName: String {
        library.voices.first(where: { $0.id.uuidString == selectedVoice })?.name
            ?? "Original"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Create speech")
                                .font(.system(size: 35, weight: .bold, design: .rounded))
                            Text("Your words. Any voice.")
                                .foregroundStyle(StudioStyle.subtle)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 12)

                    GlassPanel {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Label("Voice", systemImage: "waveform")
                                    .foregroundStyle(StudioStyle.subtle)
                                Spacer()
                                Picker("Voice", selection: $selectedVoice) {
                                    Text("Original").tag("default")
                                    ForEach(library.voices) { voice in
                                        Text(voice.name).tag(voice.id.uuidString)
                                    }
                                }
                                .tint(.white)
                                .labelsHidden()
                            }
                            Divider().overlay(.white.opacity(0.06))
                            HStack {
                                Label("Language", systemImage: "globe")
                                    .foregroundStyle(StudioStyle.subtle)
                                Spacer()
                                Picker("Language", selection: $language) {
                                    ForEach(SpeechLanguage.all) { lang in
                                        Text(lang.name).tag(lang.code)
                                    }
                                }
                                .tint(.white)
                                .labelsHidden()
                            }
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Script").font(.headline)
                                Spacer()
                                Text("\(text.count) characters")
                                    .font(.caption)
                                    .foregroundStyle(StudioStyle.subtle)
                            }
                            ZStack(alignment: .topLeading) {
                                if text.isEmpty {
                                    Text("Type or paste something to say…")
                                        .foregroundStyle(.white.opacity(0.36))
                                        .padding(.top, 9)
                                        .padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $text)
                                    .scrollContentBackground(.hidden)
                                    .font(.system(size: 17))
                                    .frame(minHeight: 202)
                                    .autocorrectionDisabled(false)
                            }
                        }
                    }

                    if !engine.isReady {
                        GlassPanel {
                            HStack(spacing: 12) {
                                Image(systemName: "square.stack.3d.up")
                                    .font(.title2)
                                    .foregroundStyle(StudioStyle.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Multilingual model").font(.headline)
                                    Text(engine.loading ? engine.loadingTimingText : engine.status)
                                        .font(.subheadline)
                                        .foregroundStyle(StudioStyle.subtle)
                                }
                                Spacer(minLength: 0)
                                Button(engine.modelDirectory == nil ? "Get" : "Manage") {
                                    showModel = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    GlassPanel {
                        DisclosureGroup {
                            VStack(spacing: 12) {
                                VStack(spacing: 4) {
                                    HStack {
                                        Text("Period").font(.subheadline)
                                        Spacer()
                                        Text("\(Int(sentencePause * 1_000)) ms")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(StudioStyle.subtle)
                                    }
                                    Slider(value: $sentencePause, in: 0...0.5, step: 0.05)
                                        .accessibilityLabel("Period pause")
                                }
                                VStack(spacing: 4) {
                                    HStack {
                                        Text("Comma").font(.subheadline)
                                        Spacer()
                                        Text("\(Int(commaPause * 1_000)) ms")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(StudioStyle.subtle)
                                    }
                                    Slider(value: $commaPause, in: 0...0.5, step: 0.05)
                                        .accessibilityLabel("Comma pause")
                                }
                            }
                            .padding(.top, 10)
                        } label: {
                            Label("Punctuation pauses", systemImage: "timer")
                                .font(.subheadline.weight(.medium))
                        }
                        .tint(StudioStyle.accent)
                    }

                    Button {
                        engine.generate(text: text, language: language, voiceURL: chosenURL,
                                        voiceName: selectedVoiceName, history: history,
                                        playback: playback, sentencePause: sentencePause,
                                        commaPause: commaPause)
                    } label: {
                        HStack(spacing: 10) {
                            if engine.generating { ProgressView().tint(.black) }
                            else { Image(systemName: "waveform.badge.mic") }
                            Text(engine.generating ? "Generating…" : "Generate audio")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StudioStyle.accent)
                    .foregroundStyle(.black)
                    .disabled(!engine.isReady || engine.generating ||
                              text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if engine.generating {
                        HStack(spacing: 9) {
                            ProgressView()
                                .tint(StudioStyle.accent)
                            Text(engine.generationTimingText)
                                .monospacedDigit()
                                .font(.subheadline)
                                .foregroundStyle(StudioStyle.subtle)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if let output = engine.lastOutput,
                       FileManager.default.fileExists(atPath: output.path) {
                        GlassPanel {
                            HStack(spacing: 14) {
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: 33))
                                    .foregroundStyle(StudioStyle.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Audio ready").font(.headline)
                                    Text("Saved on this iPhone")
                                        .font(.caption)
                                        .foregroundStyle(StudioStyle.subtle)
                                }
                                Spacer()
                                ShareLink(item: output) {
                                    Image(systemName: "square.and.arrow.up").font(.title3)
                                }
                                .accessibilityLabel("Share generated audio")
                            }
                            AudioTransport(url: output)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(StudioBackdrop())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showModel = true } label: {
                        Image(systemName: engine.isReady ? "checkmark.circle" : "arrow.down.circle")
                    }
                    .accessibilityLabel("Manage model")
                }
            }
        }
    }
}

struct VoicesView: View {
    @EnvironmentObject private var library: VoiceLibrary
    @Binding var showModel: Bool
    @State private var showingCreate = false
    @State private var attachingTo: SavedVoice?
    @State private var importingSample = false
    @State private var attachmentError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your voices")
                            .font(.system(size: 35, weight: .bold, design: .rounded))
                        Text("Private. On-device.")
                            .foregroundStyle(StudioStyle.subtle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)

                    AddVoiceButton(showModel: $showModel, showingCreate: $showingCreate)

                    if library.voices.isEmpty {
                        GlassPanel {
                            VStack(alignment: .center, spacing: 14) {
                                Image(systemName: "waveform.badge.plus")
                                    .font(.system(size: 45, weight: .ultraLight))
                                    .foregroundStyle(StudioStyle.accent)
                                Text("No cloned voices yet")
                                    .font(.headline)
                                Text("Record or import a sample to get started.")
                                    .font(.subheadline)
                                    .foregroundStyle(StudioStyle.subtle)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        }
                    } else {
                        ForEach(library.voices) { voice in
                            GlassPanel {
                                VStack(alignment: .leading, spacing: 11) {
                                    HStack(spacing: 15) {
                                    Image(systemName: "waveform")
                                        .font(.title2)
                                        .foregroundStyle(StudioStyle.accent)
                                        .frame(width: 46, height: 46)
                                        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(voice.name).font(.headline)
                                        Text(voice.createdAt, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(StudioStyle.subtle)
                                    }
                                    Spacer()
                                    VoiceMenu(voice: voice) {
                                        attachingTo = voice
                                        importingSample = true
                                    }
                                    }
                                    if let sample = library.sampleURL(for: voice) {
                                        AudioTransport(url: sample)
                                    } else {
                                        Text("Reference audio not stored · use ••• to attach it")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(StudioBackdrop())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showModel = true } label: { Image(systemName: "square.stack.3d.up") }
                        .accessibilityLabel("Manage model")
                }
            }
            .sheet(isPresented: $showingCreate) { NewVoiceSheet() }
            .fileImporter(isPresented: $importingSample, allowedContentTypes: [.audio],
                          allowsMultipleSelection: false) { result in
                guard let voice = attachingTo else { return }
                do {
                    let urls = try result.get()
                    guard let url = urls.first else { return }
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    let suffix = url.pathExtension.isEmpty ? "audio" : url.pathExtension
                    let temporary = FileManager.default.temporaryDirectory
                        .appendingPathComponent("voicegen-attach-\(UUID().uuidString).\(suffix)")
                    try FileManager.default.copyItem(at: url, to: temporary)
                    Task {
                        defer { try? FileManager.default.removeItem(at: temporary) }
                        do {
                            try await library.attachSample(from: temporary, to: voice)
                        } catch {
                            attachmentError = error.localizedDescription
                        }
                    }
                } catch {
                    attachmentError = error.localizedDescription
                }
            }
            .alert("Audio import", isPresented: Binding(
                get: { attachmentError != nil },
                set: { if !$0 { attachmentError = nil } }
            )) {
                Button("OK", role: .cancel) { attachmentError = nil }
            } message: {
                Text(attachmentError ?? "")
            }
        }
    }
}

/// Keeping transport/menu observations local prevents playback ticks rebuilding the list.
private struct VoiceMenu: View {
    @EnvironmentObject private var playback: PlaybackController
    @EnvironmentObject private var library: VoiceLibrary
    let voice: SavedVoice
    let onAttach: () -> Void

    var body: some View {
        Menu {
            Button("Attach reference audio", systemImage: "waveform.badge.plus") {
                onAttach()
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                if let sample = library.sampleURL(for: voice) {
                    playback.stopIfCurrent(sample)
                }
                library.remove(voice)
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(.white)
                .frame(width: 40, height: 44)
        }
    }
}

/// Only this button observes engine readiness; the voice rows remain stable.
private struct AddVoiceButton: View {
    @EnvironmentObject private var engine: VoiceEngine
    @Binding var showModel: Bool
    @Binding var showingCreate: Bool

    var body: some View {
        Button {
            if engine.isReady { showingCreate = true }
            else { showModel = true }
        } label: {
            Label("Add voice", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .tint(StudioStyle.accent)
        .foregroundStyle(.black)
    }
}

struct ModelSheet: View {
    @EnvironmentObject private var engine: VoiceEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                StudioBackdrop()
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 18) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 35))
                            .foregroundStyle(StudioStyle.accent)
                            .frame(width: 68, height: 68)
                            .glassEffect()
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Chatterbox Multilingual").font(.headline)
                            Text(engine.status)
                                .font(.subheadline)
                                .foregroundStyle(StudioStyle.subtle)
                        }
                    }
                    if engine.loading {
                        GlassPanel {
                            HStack(spacing: 12) {
                                ProgressView().tint(StudioStyle.accent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(engine.loadingPhase)
                                        .font(.subheadline.weight(.medium))
                                    Text(engine.loadingTimingText)
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(StudioStyle.subtle)
                                }
                            }
                        }
                    }

                    if engine.isReady || engine.loading {
                        GlassPanel {
                            HStack(spacing: 12) {
                                Text("Russian stress")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                switch engine.ruAccentAvailability {
                                case .active:
                                    Label("Active", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                case .unavailable:
                                    Text("Fallback")
                                        .foregroundStyle(.orange)
                                    Button("Retry") { engine.retryRUAccent() }
                                        .buttonStyle(.bordered)
                                case .checking:
                                    ProgressView()
                                    Text("Checking")
                                        .foregroundStyle(StudioStyle.subtle)
                                case .unknown:
                                    Text("Not checked")
                                        .foregroundStyle(StudioStyle.subtle)
                                }
                            }
                            .font(.subheadline)
                        }
                    }

                    if engine.downloading || engine.paused {
                        ProgressView(value: engine.progress)
                            .tint(StudioStyle.accent)
                        HStack {
                            Text("\(Int(engine.progress * 100))%")
                                .monospacedDigit()
                            Spacer()
                            Text(engine.paused ? "Paused" : "Downloading")
                        }
                        .font(.caption)
                        .foregroundStyle(StudioStyle.subtle)
                    }

                    if engine.isReady {
                        Label("Available offline", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else if engine.downloading {
                        Button("Pause download", systemImage: "pause.fill") { engine.pauseDownload() }
                            .buttonStyle(.borderedProminent)
                    } else if engine.paused {
                        Button("Resume download", systemImage: "play.fill") { engine.resumeDownload() }
                            .buttonStyle(.borderedProminent)
                    } else if engine.modelDirectory != nil {
                        if !engine.loading {
                            Button("Load model", systemImage: "bolt.fill") {
                                engine.load()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        if !engine.loading {
                            Button("Repair / resume download") { engine.resumeDownload() }
                                .font(.subheadline)
                        }
                    } else {
                        Button("Download model", systemImage: "arrow.down") { engine.startDownload() }
                            .buttonStyle(.borderedProminent)
                    }
                    Text("One-time download · generation runs locally.")
                        .font(.footnote)
                        .foregroundStyle(StudioStyle.subtle)
                    Spacer(minLength: 0)
                }
                .padding(25)
                .padding(.top, 22)
            }
            .navigationTitle("Offline model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }}
        }
        .presentationDetents([.medium, .large])
    }
}
