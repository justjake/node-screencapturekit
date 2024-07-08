import AppKit
import CoreImage
import Foundation
import NodeAPI

extension CGFloat: NodeValueConvertible, NodeValueCreatable {
  public typealias ValueType = NodeNumber

  public func nodeValue() throws -> any NodeAPI.NodeValue {
    try NodeNumber(Double(self))
  }

  public static func from(_ value: NodeAPI.NodeNumber) throws -> CGFloat {
    CGFloat(try value.double())
  }
}

extension CGPoint: NodeValueConvertible, NodeValueCreatable, NodeInspect {
  public typealias ValueType = NodeObject

  public func nodeValue() throws -> any NodeValue {
    try NodeObject([
      "x": x,
      "y": y,
    ])
  }

  public static func from(_ value: ValueType) throws -> Self {
    let x = try value.propertyAs("x", Double.self)
    let y = try value.propertyAs("y", Double.self)
    return Self(x: x, y: y)
  }

  func nodeInspect(_ inspector: Inspector) throws -> String {
    "x: \(try inspector.stylize(inferType: x)) y: \(try inspector.stylize(inferType: y))"
  }
}

extension CGSize: NodeValueConvertible, NodeValueCreatable, NodeInspect {
  func nodeInspect(_ inspector: Inspector) throws -> String {
    "\(try inspector.stylize(inferType: width))x\(try inspector.stylize(inferType: height))"
  }

  public typealias ValueType = NodeObject

  public func nodeValue() throws -> any NodeValue {
    try NodeObject([
      "width": width,
      "height": height,
    ])
  }

  public static func from(_ value: ValueType) throws -> Self {
    let width = try value.propertyAs("width", Double.self)
    let height = try value.propertyAs("height", Double.self)
    return Self(width: width, height: height)
  }
  
  public func scaled(by scale: CGFloat) -> CGSize {
    Self(width: width * scale, height: height * scale)
  }
}

extension CGRect: NodeValueConvertible, NodeValueCreatable, NodeInspect {
  public typealias ValueType = NodeObject

  public func nodeValue() throws -> any NodeValue {
    try NodeObject([
      "origin": origin,
      "size": size,
    ])
  }

  public static func from(_ value: ValueType) throws -> Self {
    let origin = try value.propertyAs("origin", CGPoint.self)
    let size = try value.propertyAs("size", CGSize.self)
    return Self(origin: origin, size: size)
  }

  func nodeInspect(_ inspector: Inspector) throws -> String {
    "[\(try inspector.inspect(origin as NodeInspect)) \(try inspector.inspect(size as NodeInspect))]"
  }
}

extension CGImage {
  func pngImageData() throws -> NSMutableData {
    let bitmap = NSBitmapImageRep(cgImage: self)
    // TODO: it's probably worth compressing to reduce bytes copied?
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
      throw MyError.unsupported("Cannot decode image png representation")
    }
    // TODO: no copy
    return NSMutableData(data: data)
  }

  var size: CGSize {
    CGSize(width: width, height: height)
  }
}

@NodeClass final class NodeImage {
  let image: CGImage
  let task: Task<NSMutableData, Error>
  @NodeProperty let size: CGSize

  init(_ image: CGImage) {
    self.image = image
    self.size = image.size
    self.task = Task(priority: .userInitiated) { try image.pngImageData() }
  }

  @NodeActor
  @NodeMethod func getImageData() async throws -> NodeUInt8ClampedArray {
    let data = try await task.value
    let buffer = try NodeArrayBuffer(data: data)
    return try NodeUInt8ClampedArray(for: buffer, count: data.count)
  }

  @NodeActor
  @NodeName(NodeSymbol.utilInspectCustom)
  @NodeMethod
  func nodeInspect(_ inspector: Inspector) throws -> String {
    return try inspector.nodeClass(
      value: self, paths: ("size", \.size)
    )
  }
}
