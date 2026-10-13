import AVFoundation
import Combine
import Foundation
import SwiftUI

/// One playback session shared by generated audio and saved reference samples.
@MainActor
final class PlaybackController: ObservableObject {
    @Published private(set) var currentURL: URL?
    @Published private(set) var isPlaying = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var error: String?

    private var audio: AVAudioPlayer?
    private var timer: Timer?

    func toggle(_ url: URL) {
        do {
            try prepare(url)
            guard let audio else { return }
            if audio.isPlaying {
                audio.pause()
                isPlaying = false
                stopTimer()
            } else {
                if duration > 0 && audio.currentTime >= duration - 0.05 {
                    audio.currentTime = 0
                    elapsed = 0
                }
                guard audio.play() else {
                    throw VoicegenError.message("Audio could not be played.")
                }
                isPlaying = true
                startTimer()
            }
        } catch { self.error = error.localizedDescription }
    }

    func seek(_ time: TimeInterval, in url: URL) {
        do {
            try prepare(url)
            let position = min(max(time, 0), duration)
            audio?.currentTime = position
            elapsed = position
            if audio?.isPlaying == true && position >= duration {
                audio?.pause()
                isPlaying = false
                stopTimer()
            }
        } catch { self.error = error.localizedDescription }
    }

    func stopIfCurrent(_ url: URL) {
        guard currentURL == url else { return }
        stop()
    }

    func stop() {
        audio?.stop()
        audio = nil
        currentURL = nil
        isPlaying = false
        elapsed = 0
        duration = 0
        stopTimer()
    }

    private func prepare(_ url: URL) throws {
        if currentURL == url, audio != nil { return }
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        let player = try AVAudioPlayer(contentsOf: url)
        guard player.duration.isFinite, player.duration > 0 else {
            throw VoicegenError.message("This audio file is empty.")
        }
        player.prepareToPlay()
        audio = player
        currentURL = url
        duration = player.duration
        elapsed = 0
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let audio = self.audio else { return }
                self.elapsed = audio.currentTime
                if !audio.isPlaying {
                    self.elapsed = min(audio.duration, self.elapsed)
                    self.isPlaying = false
                    self.stopTimer()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

/// A small native playback bar. A slider changes the actual audio position,
/// including when paused and before the first play.
struct AudioTransport: View {
    @EnvironmentObject private var playback: PlaybackController
    let url: URL
    @State private var scrubbing: TimeInterval?
    @State private var fileDuration: TimeInterval = 0

    private var selected: Bool { playback.currentURL == url }
    private var total: TimeInterval {
        selected ? playback.duration : fileDuration
    }
    private var current: TimeInterval {
        scrubbing ?? (selected ? playback.elapsed : 0)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                Button {
                    playback.toggle(url)
                } label: {
                    Image(systemName: selected && playback.isPlaying
                          ? "pause.fill" : "play.fill")
                        .font(.headline)
                        .frame(width: 34, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(selected && playback.isPlaying ? "Pause" : "Play")
                Slider(value: Binding(
                    get: { min(current, max(total, 1)) },
                    set: { scrubbing = $0 }),
                    in: 0...max(total, 1),
                    onEditingChanged: { editing in
                        if !editing, let position = scrubbing {
                            playback.seek(position, in: url)
                            scrubbing = nil
                        }
                    }
                )
                .tint(Color(red: 0.62, green: 0.73, blue: 1))
                .accessibilityLabel("Playback position")
            }
            HStack {
                Text(clock(current))
                Spacer()
                Text(clock(total))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .task(id: url) {
            if let file = try? AVAudioFile(forReading: url), file.processingFormat.sampleRate > 0 {
                fileDuration = Double(file.length) / file.processingFormat.sampleRate
            } else {
                fileDuration = 0
            }
        }
    }

    private func clock(_ value: TimeInterval) -> String {
        let seconds = max(0, Int(value.isFinite ? value : 0))
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600,
                          (seconds % 3600) / 60, seconds % 60)
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
