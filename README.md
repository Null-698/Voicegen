# Voicegen

Offline voice cloning and multilingual TTS for iOS 26+ (including iOS 27). SwiftUI Liquid Glass, Chatterbox Multilingual Core ML. Intended for iPhone 16 Pro Max.

## Features

- Record/import samples; clone voices locally and store multiple voices.
- Choose cloned voice and language (23 options, including Russian).
- Generate, play and share WAV speech.
- Pause and resume model downloads (finished files are reused; interrupted files may restart).
- After the initial downloads, cloning and generation are on-device.

## Build unsigned IPA with Xcode

**One push to `main` triggers one build.** Concurrent builds cancel older builds. CI uses **Xcode 27**, `xcodebuild`, and [XcodeGen](https://github.com/yonaskolb/XcodeGen), which generates the native `Voicegen.xcodeproj` from `project.yml`.

Open [GitHub Actions](https://github.com/Null-698/Voicegen/actions/workflows/unsigned-ipa.yml), select the latest successful run, and download the `Voicegen-unsigned-ipa` artifact.

To build locally on a Mac:

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Voicegen.xcodeproj -scheme Voicegen \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

The workflow packages `Voicegen.app` into an unsigned IPA. **A stock iPhone normally requires signing before installation.** No certificate or Apple account is needed to produce the build.

If the build fails, download `Voicegen-xcode-build-log` from its workflow artifacts.

## First launch

1. Download Chatterbox Multilingual in the model manager.
2. Record/import a clean 20–30 s reference clip in Voices, name it, confirm permission.
3. Choose voice and language in Generate, enter text, and generate speech.
4. Play/export the WAV.

Model weights are downloaded in-app and are not in the IPA. Russian stress correction may need its own initial download. Once installed, synthesis and cloning work offline. Pause/resume preserves completed cached model files; it does not guarantee byte-level resume of partial files. Keep the app foregrounded during download.

Chatterbox's speech watermarking remains enabled. This project has not yet been validated on-device or by a successful CI build. The Core ML package tracks upstream `main`; pin an audited revision before shipping.

## Attribution

Chatterbox by Resemble AI; Core ML port by Ilia Sazonov; RUAccent by Denis Petrov; Perth watermarking by Resemble AI. See upstream for licenses.
