# node-screencapturekit

Filter and select Mac screen content and stream it to NodeJS using [Apple's ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit/).

> Use the ScreenCaptureKit framework to add support for high-performance frame capture of screen ~and audio content~ to your Mac **NodeJS** app. The framework gives you fine-grained control to select and stream only the content that you want to capture. As a stream captures ~new video frames and audio samples, it passes them to your app as CMSampleBuffer objects that contain the media data and its related metadata. ScreenCaptureKit also provides a macOS-integrated picker for streaming selection and management, SCContentSharingPicker~.

## Using

This is early days for the project. Install via Git:

```bash
npm add git://github.com/justjake/node-screencapturekit
```

There may be a version available in NPM but it probably is out of date and/or not code signed correctly.

For a demo of the available features, see [the demo](https://github.com/justjake/node-screencapturekit/blob/main/scripts/demo.ts) or read the source code.

See also the [API documentation for Apple's ScreenCaptureKit]()

## Roadmap

- [x] Sharable content enumeration & filtering
- [x] Screenshot capture
- [ ] Picker UI (if possible)
  - [ ] Built-in picker UI (SCContentSharingPicker)
  - [ ] Custom screen grab UI via SwiftUI
- [ ] Tests
- [ ] Binary distribution
- [ ] Video streaming
- [ ] Audio streaming

## Development

Built with [node-swift](https://github.com/kabiroberai/node-swift).

Get started:

```bash
npm install
npm start
```

Swift goes in `./Sources`.

Typescript goes in `./src` and builds into `./lib`.
