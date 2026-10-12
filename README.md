# Voicegen

Offline voice-cloning and multilingual TTS for iOS 26+ (including iOS 27), targeting iPhone 16 Pro Max. SwiftUI, Liquid Glass, Chatterbox Multilingual Core ML.

## Features

- Record or import a voice sample; clone locally into reusable conditioning files.
- Switch among saved voices (or the included default) when generating speech.
- Generate speech in 23 languages, including Russian.
- Play, export and share generated WAV audio.
- Download the model within the app; **Pause / Resume** retain finished cached files.
- Once the model and Russian stress assets are installed, generation and cloning run on the iPhone, without server calls.
- No account or voice uploads. Voice references and generated clips are kept in the app sandbox.

## Build without owning a Mac

GitHub **Actions → Unsigned iOS IPA → Run workflow** (or push to main).
The workflow runs on a GitHub-hosted macOS runner, installs [xtool](https://xtool.sh/) and runs:

```sh
xtool dev build --configuration release --ipa
```

Download `Voicegen-unsigned-ipa` from the workflow's artifacts. No signing credentials are required **for building**. An unsigned IPA generally **cannot be installed on a stock iPhone** until it is signed (e.g. by your preferred sideload tool or deployment method).

To build yourself using xtool:

```sh
brew install xtool-org/tap/xtool
xtool dev build --configuration release --ipa
```

The build uses a **Swift package**, not an Xcode project. The package fetches the open-source [Chatterbox Core ML](https://github.com/iliasaz/chatterbox-coreml) runtime at build time, but **does not embed model weights**.

## First launch

1. Open the model manager and download Chatterbox Multilingual. The first load compiles Core ML assets on device.
2. In **Voices**, record or import an audio reference, name it, and confirm consent.
3. In **Generate**, select voice and language, enter text, then generate speech.
4. Use play / share for generated audio. Generated WAV files remain in Documents/Generated.

### Pause / resume behavior

Uses the runtime's incremental Hugging Face model snapshot cache. Pausing cancels the in-flight download; resuming rechecks and reuses completed cached files. **It does not guarantee byte-for-byte continuation of a partially transferred individual file**. Keep the app foregrounded during download; iOS may suspend it in the background.

### Notes

- The model requires a large initial download and sufficient free disk space for compiled model caches.
- Russian stress correction may require a separate initial RUAccent download; if unavailable, the runtime falls back to explicit stress marks.
- Voice conditioning should use a clean, preferably 20–30 second sample.
- Chatterbox's default speech watermarking is retained.
- Dependencies are on upstream main branches, because the Core ML runtime is new. Pin audited commits before shipping.
- This project has not been validated on a physical device or a successful CI build yet.

## Attribution

Chatterbox by Resemble AI; Core ML implementation by Ilia Sazonov; RUAccent by Denis Petrov; Perth watermarking by Resemble AI. Refer to upstream repositories for their MIT licenses.
