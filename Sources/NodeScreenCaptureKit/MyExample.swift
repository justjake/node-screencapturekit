import Foundation
import NodeAPI
import ScreenCaptureKit

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
}

@available(macOS 14.0, *)
#NodeModule(exports: [
  "SCContentSharingPickerMode": try SCContentSharingPickerMode.nodeByName(),
  "getSharableContent": try NodeFunction { try await NodeModule.getSharableContent(args: $0) },
  "createStreamConfiguration": try NodeFunction { NodeModule.createStreamConfiguration() },
  "createContentFilter": try NodeFunction { try NodeModule.createContentFilter(args: $0) },
  "captureImage": try NodeFunction { (filter: ContentFilter, config: StreamConfiguration?) async throws in
    try await NodeModule.captureImage(filter: filter, config: config)
  },
  "pickContentFilter": try NodeFunction { try await NodeModule.pickContentFilter(args: $0) },
])
