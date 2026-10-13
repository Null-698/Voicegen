import SwiftUI
import AVFoundation

struct HistoryView: View {
    @EnvironmentObject private var history: GenerationHistory
    @State private var selected: GenerationEntry?
    @State private var player: AVAudioPlayer?
    @State private var playbackError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("History")
                            .font(.system(size: 35, weight: .bold, design: .rounded))
                        Text("Your generated audio, saved on this iPhone.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)

                    if history.entries.isEmpty {
                        GlassPanel {
                            VStack(spacing: 12) {
                                Image(systemName: "waveform.path")
                                    .font(.system(size: 44, weight: .ultraLight))
                                    .foregroundStyle(.tint)
                                Text("Nothing here yet").font(.headline)
                                Text("Generated audio will appear here.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 25)
                        }
                    }

                    ForEach(history.entries) { entry in
                        GlassPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                Button { selected = entry } label: {
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(entry.text.isEmpty ? "Previous generation" : entry.text)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(summary(for: entry))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)

                                HStack(spacing: 20) {
                                    Button {
                                        play(entry)
                                    } label: {
                                        Label("Play", systemImage: "play.fill")
                                    }
                                    ShareLink(item: history.url(for: entry)) {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                    Spacer()
                                    Menu {
                                        Button("Delete audio", systemImage: "trash",
                                               role: .destructive) {
                                            do { try history.delete(entry) }
                                            catch { playbackError = error.localizedDescription }
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .frame(width: 32, height: 36)
                                    }
                                    .accessibilityLabel("More options")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.tint)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(StudioBackdrop())
            .sheet(item: $selected) { entry in
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(entry.text.isEmpty ? "Previous generation" : entry.text)
                                .font(.title3)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(summary(for: entry))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 18) {
                                Button("Play", systemImage: "play.fill") { play(entry) }
                                ShareLink(item: history.url(for: entry)) {
                                    Label("Share WAV", systemImage: "square.and.arrow.up")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(24)
                    }
                    .background(StudioBackdrop())
                    .navigationTitle("Generation")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { selected = nil }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Audio error", isPresented: Binding(
                get: { playbackError != nil },
                set: { if !$0 { playbackError = nil } }
            )) {
                Button("OK", role: .cancel) { playbackError = nil }
            } message: {
                Text(playbackError ?? "")
            }
        }
    }

    private func summary(for entry: GenerationEntry) -> String {
        let language = SpeechLanguage.all.first { $0.code == entry.language }?.name
            ?? entry.language
        return [entry.voice, language, entry.createdAt.formatted(date: .abbreviated, time: .shortened)]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func play(_ entry: GenerationEntry) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            player?.stop()
            player = try AVAudioPlayer(contentsOf: history.url(for: entry))
            player?.prepareToPlay()
            player?.play()
        } catch {
            playbackError = error.localizedDescription
        }
    }
}
