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
    @EnvironmentObject private var engine: VoiceEngine
    @EnvironmentObject private var library: VoiceLibrary
    @State private var showModel = false

    var body: some View {
        TabView {
            GenerateView(showModel: $showModel)
                .tabItem { Label("Generate", systemImage: "waveform") }
            VoicesView(showModel: $showModel)
                .tabItem { Label("Voices", systemImage: "person.2.wave.2") }
        }
        .tint(StudioStyle.accent)
        .sheet(isPresented: $showModel) { ModelSheet() }
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
    @Binding var showModel: Bool
    @AppStorage("voicegen.language") private var language = "ru"
    @AppStorage("voicegen.selectedVoice") private var selectedVoice = "default"
    @State private var text = ""

    private var chosenURL: URL? {
        guard let voice = library.voices.first(where: { $0.id.uuidString == selectedVoice }) else {
            return nil
        }
        return library.url(for: voice)
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

                    Button {
                        engine.generate(text: text, language: language, voiceURL: chosenURL)
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

                    if let output = engine.lastOutput {
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
                                Button { engine.play() } label: {
                                    Image(systemName: "play.fill").font(.title3)
                                }
                                .accessibilityLabel("Play generated audio")
                                ShareLink(item: output) {
                                    Image(systemName: "square.and.arrow.up").font(.title3)
                                }
                                .accessibilityLabel("Share generated audio")
                            }
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
    @EnvironmentObject private var engine: VoiceEngine
    @EnvironmentObject private var library: VoiceLibrary
    @Binding var showModel: Bool
    @State private var showingCreate = false

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
                                    Menu {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            library.remove(voice)
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .foregroundStyle(.white)
                                            .frame(width: 40, height: 44)
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
        }
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
                        .buttonStyle(.borderedProminent)
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
