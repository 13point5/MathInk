# MathInk

MathInk is a native iPad sketching app for fast handwritten math notes. It pairs a full-bleed `PencilKit` canvas with a native SwiftUI sidebar, local sketch persistence, and quick tool switching from a bottom style panel, voice commands, or Apple Pencil gestures.

## Features

- Native iPad app built with `SwiftUI`.
- Edge-to-edge `PencilKit` drawing canvas for Apple Pencil or touch input.
- Native `NavigationSplitView` sidebar for creating, selecting, and deleting sketches.
- Local sketch storage with `SwiftData`.
- Floating style panel with pen, pencil, marker, eraser, color, and microphone controls.
- Voice tool commands such as `red pen`, `blue pencil`, `yellow marker`, and `eraser`.
- Apple Pencil double-tap and squeeze triggers for voice command capture on supported hardware.
- Simulator text fallback for testing voice commands without microphone input.

## Requirements

- Xcode with iOS 17.5 or newer SDK support.
- iPadOS 17.5 or newer for device builds.
- A signing team in Xcode for running on a physical iPad.
- Microphone and speech recognition permissions for voice commands.

## Run The App

1. Open `MathInk.xcodeproj` in Xcode.
2. Select the `MathInk` scheme.
3. Choose an iPad simulator or a connected iPad.
4. If running on device, choose a signing team under `Signing & Capabilities`.
5. Press Run.

On first launch, allow microphone and speech recognition access if you want voice tool switching.

## Use The App

- Tap `New Sketch` in the sidebar to create another board.
- Draw directly on the canvas with Apple Pencil or touch.
- Use the bottom style panel to change tools and colors.
- Tap the mic button, or use Apple Pencil double tap/squeeze, then say a command like `blue pencil`.
- In Simulator, type a command into the fallback field and press Apply.

Sketches save locally and reappear across launches.

## Development

Run the test suite from the command line:

```sh
xcodebuild -project MathInk.xcodeproj -scheme MathInk -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=26.4.1' test
```

The project also includes `project.yml` so the Xcode project settings can be regenerated if you use XcodeGen.

## Current Scope

MathInk is currently a focused sketching foundation. Planned next steps include graphing, structured shape layers, typed math blocks, richer math vocabulary for voice commands, and export to PDF or image formats.
