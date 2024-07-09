import AppKit
import Foundation
import NodeAPI
import ScreenCaptureKit

class AppSession<T>: NSObject, NSApplicationDelegate {
  typealias Func = () async throws -> T
  
  let app = NSApplication.shared
  let initialActivationPolicy = NSApplication.shared.activationPolicy()
  let initialDelegate = NSApplication.shared.delegate
  var exitStatus: Int32? = nil
  var produce: Func
  var task: Task<T, Error>? = nil
  var result: Result<T, Error>? = nil
  var started = false
  
  init(_ produce: @escaping Func) {
    self.produce = produce
  }
  
  @discardableResult
  func start() -> Bool {
    if app.isRunning {
      print("app already running")
      runFunc()
      return false
    }
    
    if initialActivationPolicy == .prohibited {
      app.setActivationPolicy(.accessory)
    }
    
    app.delegate = self
    started = true
    app.run()
    print("after app.run \(threadInfo())")
    return true
  }
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    print("applicationDidFinishLaunching")
    runFunc()
  }
  
  private func runFunc() {
    print("runFunc")
    defer { print("end runFunc") }
    task = Task { @MainActor in
      print("runFunc task started \(started)")
      defer { print("runFunc task stopped: \(String(describing: result))")}
      do {
        let success = try await produce()
        result = .success(success)
        done()
        return success
      } catch {
        result = .failure(error)
        done()
        throw error
      }
    }
  }
  
  func done() {
    app.setActivationPolicy(initialActivationPolicy)
    app.delegate = initialDelegate
    if started {
      threadInfo()
      let stopEvent = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: .deviceIndependentFlagsMask, timestamp: TimeInterval(), windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0)!
      app.postEvent(stopEvent, atStart: true)
      app.stop(self)
      print("app.stop(self) \(threadInfo())")
    }
  }
}

// No MainActor here.
@NodeActor
@available(macOS 14.0, *)
func withUI<I>(block: @escaping () async throws -> I) throws -> I {
  print("withUI begin")
  let delegate = AppSession(block)
  defer { delegate.done() }
  delegate.start()
  return try delegate.result!.get()
}

func threadInfo() -> String {
  "isMainThread: \(Thread.current.isMainThread), \(Thread.current), task priority \(Task.currentPriority), isCancelled: \(Task.isCancelled)"
}

@available(macOS 14.0, *)
class MainThreadHelper<T>: NSObject, NSApplicationDelegate {
  var filter: SCContentFilter? = nil
  var window: NSWindow? = nil
  var task: Task<T, Error>? = nil
  var whenDidFinishLaunching: () async throws -> T

  init(whenDidFinishLaunching block: @escaping () async throws -> T) {
    whenDidFinishLaunching = block
  }

  func applicationDidFinishLaunching(_: Notification) {
    print("didFinishLaunching")
    task = Task { @MainActor in
      let result = try await whenDidFinishLaunching()
      NSApp.stop(self)
      print("NSApp.stop")
      return result
    }
  }
}

@available(macOS 14.0, *)
@NodeActor
struct NodeModule {
  static func getSharableContent(args: NodeArguments) async throws -> NodeValueConvertible {
    return try await SCShareableContent.getNodeSharableContent(
      nodeArgs: args.first?.as(NodeObject.self))
  }

  static func createStreamConfiguration() -> StreamConfiguration {
    let base = SCStreamConfiguration()
    return StreamConfiguration(base)
  }

  static func createContentFilter(args: ContentFilterArgs) throws -> ContentFilter {
    return try args.contentFilter()
  }

  static func captureImage(filter: ContentFilter, config: StreamConfiguration? = nil) async throws -> NodeImage {
    let finalConfig = config ?? filter.createStreamConfiguration()
    let image = try await SCScreenshotManager.captureImage(
      contentFilter: filter.inner,
      configuration: finalConfig.inner
    )
    return NodeImage(image)
  }

  static func pickContentFilter(args: SCContentSharingPickerConfiguration) async throws -> ContentFilter {
    let filter = try await args.preset()
    // TODO: support window shadows :|
    return ContentFilter(filter)
  }

  static func testMainActor() async throws -> ContentFilter? {
    threadInfo()
    let result = try withUI(block: { @MainActor in
      print("started producing")
//      let config = SCContentSharingPickerConfiguration()
      print("starting presenter")
//      return try await config.preset()
//      return SCContentF
      return nil as SCContentFilter?
    })
    print("result: \(result)")
    if let result = result {
      return ContentFilter(result)
    }
    return nil
  }
}

@available(macOS 14.0, *)
#NodeModule(exports: try [
  "SCContentSharingPickerMode": SCContentSharingPickerMode.nodeByName(),
  "getSharableContent": NodeFunction { try await NodeModule.getSharableContent(args: $0) },
  "createStreamConfiguration": NodeFunction { NodeModule.createStreamConfiguration() },
  "createContentFilter": NodeFunction { try NodeModule.createContentFilter(args: $0) },
  "captureImage": NodeFunction { (filter: ContentFilter, config: StreamConfiguration?) async throws in
    try await NodeModule.captureImage(filter: filter, config: config)
  },
  "pickContentFilter": NodeFunction { try await NodeModule.pickContentFilter(args: $0) },
  "testMainActor": NodeFunction { return try await NodeModule.testMainActor() },
])
