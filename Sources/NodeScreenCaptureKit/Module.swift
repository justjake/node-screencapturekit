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

  func shouldCallDone() -> Bool {
    if app.isRunning {
      print("app already running")
      runFunc()
      return true
    }

    if initialActivationPolicy == .prohibited {
      app.setActivationPolicy(.accessory)
    }

    app.delegate = self
    started = true
    app.run()
    print("after app.run \(threadInfo())")
    return false
  }

  func applicationDidFinishLaunching(_: Notification) {
    print("applicationDidFinishLaunching")
    runFunc()
  }

  private func runFunc() {
    print("runFunc")
    defer { print("end runFunc") }
    Task {
      print("runFunc task started \(started)")
      defer { print("runFunc task stopped: \(String(describing: result))") }
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
      let stopEvent = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: .deviceIndependentFlagsMask, timestamp: TimeInterval(), windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0)!
      app.postEvent(stopEvent, atStart: true)
      app.stop(self)
      print("app.stop(self) \(threadInfo())")
      started = false
    }
  }
}

// No MainActor here.
@NodeActor
@available(macOS 14.0, *)
func withUI<I>(block _: @escaping () async throws -> I) throws -> I? {
  print("withUI begin")
  let delegate = AppSession { @MainActor in nil as I? }
  if delegate.shouldCallDone() {
    MainActor.assumeIsolated { delegate.done() }
  }
//  return try delegate.result!.get()
  return nil
}

func threadInfo() -> String {
  "isMainThread: \(Thread.current.isMainThread), \(Thread.current), task priority \(Task.currentPriority), isCancelled: \(Task.isCancelled)"
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
    let maybeResult = try withUI(block: { @MainActor in
      print("started producing")
//      let config = SCContentSharingPickerConfiguration()
      print("starting presenter")
//      return try await config.preset()
//      return SCContentF
      return nil as SCContentFilter?
    })
    print("\(#file):\(#line) result: \(maybeResult)")
//    if let result = maybeResult {
//      let actual = ContentFilter(result)
//      print("made actual")
//      return actual
//    }
    return nil
  }
}

@available(macOS 14.0, *)
@NodeActor
func makeTestMainActor() throws -> NodeFunction {
  return try NodeFunction { (args: NodeArguments) in
    return try NodePromise {
      print("\(#file):\(#line) start")
      
      let result = try await NodeModule.testMainActor()
      
      print("\(#file):\(#line) end")
      return result
    }
  }
}

class MyAppDelegate<T>: NSObject, NSApplicationDelegate {
  var result: Result<T, Error>? = nil
  var perform: () async throws -> T
  
  init(_ perform: @escaping () async throws -> T) {
    self.perform = perform
  }
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    print("applicationDidFinishLaunching")
    // Is this enough to trigger the bug?
    Task { 
      print("task start")
      defer {
        print("task end \(result)")
      }
      do {
        result = .success(try await perform())
        let stopEvent = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: .deviceIndependentFlagsMask, timestamp: TimeInterval(), windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0)!
        NSApp.postEvent(stopEvent, atStart: true)
        NSApp.stop(self)
      } catch {
        result = .failure(error)
      }
    }
  }
  
  func runAppSync() throws -> T {
    let app = NSApplication.shared
    app.delegate = self
    app.run()
    return try self.result!.get()
  }
}


func isAppRunning() -> Bool {
  return NSApplication.shared.isRunning
}

@NodeActor @available(macOS 14.0, *)
func maybeBlockMainThreadWithAppUntilTaskComplete(perform fn: @escaping () async throws -> ()) throws -> () {
  if (isAppRunning()) {
    Task { try await fn() }
  }
  
  let delegate = MyAppDelegate(fn)
  return try delegate.runAppSync()
}

@NodeActor @available(macOS 14.0, *)
func testMainActor2() throws -> NodePromise {
  return try NodePromise { resolve in
      do {
        try maybeBlockMainThreadWithAppUntilTaskComplete { @MainActor in
          let config = SCContentSharingPickerConfiguration()
          let thingy = try await config.preset()
          try NodeActor.unsafeAssumeIsolated {
            try resolve(.success(ContentFilter(thingy)))
          }
        }
      } catch {
        try! resolve(.failure(error))
      }
  }
//  class MyAppDelegate: NSObject, NSApplicationDelegate {
//    var result: Result<SCContentFilter, Error>? = nil
//    func applicationDidFinishLaunching(_ notification: Notification) {
//      print("applicationDidFinishLaunching")
//      // Is this enough to trigger the bug?
//      Task {
//        let config = SCContentSharingPickerConfiguration()
//        do {
//          result = .success(try await config.preset())
//          let stopEvent = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: .deviceIndependentFlagsMask, timestamp: TimeInterval(), windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0)!
//          NSApp.postEvent(stopEvent, atStart: true)
//          NSApp.stop(self)
//        } catch {
//          result = .failure(error)
//        }
//      }
//    }
//  }
//  
//  let delegate = MyAppDelegate()
//  let app = NSApplication.shared
//  app.delegate = delegate
//  app.run()
//  print("app.run done")
//  let result = try delegate.result!.get()
//  return ContentFilter(result)
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
//  "testMainActor": makeTestMainActor(),
  "testMainActor": NodeFunction { return try testMainActor2() }
])
