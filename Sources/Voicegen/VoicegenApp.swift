import SwiftUI

@main
struct VoicegenApp: App {
    @StateObject private var engine = VoiceEngine()
    @StateObject private var voices = VoiceLibrary()
    @StateObject private var history = GenerationHistory()

    var body: some Scene {
        WindowGroup {
            StudioView()
                .environmentObject(engine)
                .environmentObject(voices)
                .environmentObject(history)
                .preferredColorScheme(.dark)
        }
    }
}
