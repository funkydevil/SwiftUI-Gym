# SwiftUI Gym

A native macOS live-coding trainer for practicing SwiftUI interview tasks.

## Included in the MVP

- Eight exercises covering layout, state, lists, forms, concurrency, navigation,
  animation, and accessibility.
- Native code editor with line numbers, undo, find, and four-space tabs.
- Learning, live-coding, and interview modes with a session timer.
- Progressive hints with a score penalty and reference solutions.
- Local source checks and Swift compiler diagnostics without executing submitted code.
- iOS Simulator preview rendered from the current `View`.
- Keyboard shortcuts: `⌘R` runs checks, `⌘P` runs iOS preview, and `⇧⌘R`
  resets the solution.

## Run

Requirements: macOS 14 or newer and Xcode. Preview owns a private CoreSimulator
device set in Application Support. On first use it creates `SwiftUI Gym Preview`,
boots it headlessly without opening Simulator.app, and reuses that device for
later previews. The device shuts down when the trainer quits or its last window
closes, so it never touches simulators used by other development sessions.

```sh
swift run LiveCodeTrainer
```

To work in Xcode, open `LiveCodeTrainer.xcodeproj` and select the shared
`LiveCodeTrainer` scheme. The Swift Package remains available as an alternative.
Run package tests with:

```sh
swift test
```

Build a standalone application bundle with:

```sh
./scripts/build-app.sh
open "dist/SwiftUI Gym.app"
```

## Current safety model

The evaluator never executes the submitted program. Snippets are passed directly
to `xcrun swiftc -typecheck`, with a timeout and diagnostic-size limit. The
preview runner app is compiled for `arm64-apple-ios17.0-simulator`, installed under the
stable `dev.livecodetrainer.preview` bundle identifier, and displayed as a
screenshot. Simulator preview does execute the submitted code inside the iOS app
sandbox; only run code you trust.
