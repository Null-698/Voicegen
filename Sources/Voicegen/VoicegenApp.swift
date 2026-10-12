import SwiftUI

@main
struct VoicegenApp: App {
    @StateObject private var engine = VoiceEngine()
    @StateObject private var voices = VoiceLibrary()

    var body: some Scene {
        WindowGroup {
            StudioView()
                .environmentObject(engine)
                .environmentObject(voices)
                .preferredColorScheme(.dark)
        }
    }
}
