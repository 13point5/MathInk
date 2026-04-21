# MathInk

`MathInk` is a native iPad sketching app starter aimed at note taking, math, and eventually graph-heavy deep learning workflows.

This first milestone gives you:

- a real native iPad app built with `SwiftUI`
- a `PencilKit` canvas with Apple's default tool picker
- local persistence with `SwiftData`
- voice-triggered tool switching using `Speech` and `AVFoundation`
- Apple Pencil gesture triggers for listening: `double tap` and `squeeze` on supported hardware

## Why This Stack

Apple's current native stack lines up well with your goal:

- `SwiftUI` is Apple's recommended app shell for modern iPad apps.
- `PencilKit` gives you the system drawing experience and tool picker immediately.
- `Speech` supports live microphone transcription for short commands.
- `SwiftData` handles local note persistence across launches without building a database layer yourself.
- `Swift Charts` is a strong next step for function plotting.
- `PaperKit` is promising for a later phase where you want structured shapes, math markup, and editable annotations on top of freehand ink.

Useful Apple references:

- [PencilKit](https://developer.apple.com/documentation/pencilkit)
- [Handling double taps from Apple Pencil](https://developer.apple.com/documentation/applepencil/handling-double-taps-from-apple-pencil)
- [Recognizing speech in live audio](https://developer.apple.com/documentation/speech/recognizing-speech-in-live-audio)
- [Preserving your app's model data across launches](https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches)
- [LinePlot in Swift Charts](https://developer.apple.com/documentation/charts/lineplot)
- [Integrating PaperKit into your app](https://developer.apple.com/documentation/paperkit/getting-started-with-paperkit)

## What You Need

You already have `Xcode 16.2` installed on this Mac, which is enough to build this app.

You *do* need to open Xcode for:

- running the app in Simulator
- choosing a signing team
- launching onto your real iPad
- granting microphone and speech permissions on-device

You do *not* need to hand-build project files from scratch. This folder already includes a generated Xcode project.

## How To Open And Run

1. Open `/Users/13point5/Documents/MathInk/MathInk.xcodeproj` in Xcode.
2. In Xcode, click the blue project icon, select the `MathInk` target, then go to `Signing & Capabilities`.
3. Choose your personal Apple ID team if Xcode asks for one.
4. Pick an iPad simulator, or connect your iPad and select it as the run destination.
5. Press the Run button.

If you want to run on your real iPad:

1. Connect the iPad by cable or pair it for wireless debugging in Xcode.
2. Trust the computer on the iPad if prompted.
3. Use a unique bundle identifier if `com.example.MathInk` conflicts.
4. On first launch, allow microphone and speech recognition access.

## How To Use The Starter App

- Tap `New Sketch` to create a new note.
- Draw with Apple Pencil or touch.
- Use the Apple tool picker for the default inking tools.
- Tap the mic button, or trigger Apple Pencil `double tap` or `squeeze`, then say:
  - `red pen`
  - `blue pencil`
  - `yellow marker`
  - `eraser`

Sketches are saved locally with `SwiftData`, so they persist across launches on the device.

## Current Scope

This is intentionally the smallest useful native foundation. It is not yet:

- a full document browser
- a math OCR app
- a graph editor
- a LaTeX renderer
- a structured geometry system

## Suggested Next Milestones

1. Add a graph layer for functions like `y = sin(x)` or circles.
2. Add a shape layer for segments, rays, arrows, and labeled points.
3. Add typed math blocks and deep-learning diagram blocks.
4. Add custom speech language models for math and ML vocabulary.
5. Add export to PDF and image formats.

