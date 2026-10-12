import Foundation

struct SpeechLanguage: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }

    static let all: [SpeechLanguage] = [
        .init(code: "ru", name: "Russian"),
        .init(code: "en", name: "English"),
        .init(code: "ar", name: "Arabic"),
        .init(code: "da", name: "Danish"),
        .init(code: "de", name: "German"),
        .init(code: "el", name: "Greek"),
        .init(code: "es", name: "Spanish"),
        .init(code: "fi", name: "Finnish"),
        .init(code: "fr", name: "French"),
        .init(code: "he", name: "Hebrew"),
        .init(code: "hi", name: "Hindi"),
        .init(code: "it", name: "Italian"),
        .init(code: "ja", name: "Japanese"),
        .init(code: "ko", name: "Korean"),
        .init(code: "ms", name: "Malay"),
        .init(code: "nl", name: "Dutch"),
        .init(code: "no", name: "Norwegian"),
        .init(code: "pl", name: "Polish"),
        .init(code: "pt", name: "Portuguese"),
        .init(code: "sv", name: "Swedish"),
        .init(code: "sw", name: "Swahili"),
        .init(code: "tr", name: "Turkish"),
        .init(code: "zh", name: "Chinese"),
    ]
}
