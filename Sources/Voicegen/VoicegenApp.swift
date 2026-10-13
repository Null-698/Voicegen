import SwiftUI

@main
struct VoicegenApp: App {
    @StateObject private var engine = VoiceEngine()
    @StateObject private var voices = VoiceLibrary()
    @StateObject private var history = GenerationHistory()
    @StateObject private var playback = PlaybackController()

    var body: some Scene {
        WindowGroup {
            StudioView()
                .environmentObject(engine)
                .environmentObject(voices)
                .environmentObject(history)
                .environmentObject(playback)
                .preferredColorScheme(.dark)
        }
    }
}
