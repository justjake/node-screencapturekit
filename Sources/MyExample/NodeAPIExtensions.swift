import NodeAPI

@NodeActor public func obj(_ properties: NodeObjectPropertyList = [:]) throws -> NodeObject {
  try NodeObject(properties)
}

enum MyError: Error {
  case missingProperty(String)
  case unsupported(String)
}

extension NodeObject {
  @NodeActor public func propertyAs<T: AnyNodeValueCreatable>(_ property: String, _ type: T.Type) throws -> T {
    guard let value = try self.property(forKey: property).as(type) else {
      throw MyError.missingProperty("Cannot convert property .\(property) to type '\(type)': missing or undefined")
    }
    return value
  }

  @NodeActor func clone() throws -> NodeObject {
    guard let dictionary = try self.as([String: NodeValue].self) else {
      throw try NodeError(code: nil, message: "Cannot convert options to dictionary")
    }

    return try NodeObject(.init(Array(dictionary)))
  }
}

extension NodeSymbol {
  static func nodeInspectCustom() throws -> NodeSymbol {
    try NodeSymbol.global(for: "nodejs.util.inspect.custom")
  }
}

protocol NodeInspect {
  @NodeActor func nodeInspect(_ inspector: Inspector) throws -> String
}

/// Helper for formatting output of `util.inspect.custom` method
@NodeActor public struct Inspector {
  let depth: Int
  let options: NodeObject
  let nodeInspect: NodeFunction

  static func from(args: NodeArguments) throws -> Inspector {
    guard let depth = try args[0].as(NodeNumber.self) else {
      throw try NodeError(code: nil, message: "Depth is required")
    }
    guard let options = try args[1].as(NodeObject.self) else {
      throw try NodeError(code: nil, message: "Options is required")
    }
    guard let inspect = try args[2].as(NodeFunction.self) else {
      throw try NodeError(code: nil, message: "Inspect is required")
    }
    return try Inspector(depth: depth, options: options, inspect: inspect)
  }

  init(depth: NodeNumber, options: NodeObject, inspect: NodeFunction) throws {
    self.depth = Int(try depth.double())
    self.nodeInspect = inspect
    self.options = options
  } 

  func stylize(_ value: NodeValueConvertible, _ type: String) throws -> any NodeValue {
    try options.stylize(value, type)
  }

  func stylize(inferType value: Int) throws -> any NodeValue {
    try stylize(number: value)
  }

  func stylize(inferType value: Double) throws -> any NodeValue {
    try stylize(number: value)
  }

  func stylize(inferType value: String) throws -> any NodeValue {
    try stylize(string: value)
  }

  func stylize(inferType value: NodeValue) throws -> any NodeValue {
    try stylize(value, "\(try value.nodeType())")
  }

  func stylize(number value: NodeValueConvertible) throws -> any NodeValue {
    try options.stylize(value, "number")
  }

  func stylize(special value: NodeValueConvertible) throws -> any NodeValue {
    try options.stylize(value, "special")
  }

  func stylize(string value: NodeValueConvertible) throws -> any NodeValue {
    try options.stylize(value, "string")
  }

  func nextDepth() throws -> Int {
    let currentDepth = try options["depth"].as(Int.self) ?? depth
    return currentDepth - 1
  }

  func nextOptions() throws -> NodeObject {
    let nextOptions = try options.clone()
    try nextOptions["depth"].set(to: try nextDepth())
    return nextOptions
  }

  func nextInspector() throws -> Inspector {
    try Inspector(depth: try NodeNumber(coercing: nextDepth()), options: try nextOptions(), inspect: nodeInspect)
  }

  func inspect(_ child: NodeValueConvertible) throws -> NodeValueConvertible {
    if depth < 0 {
      switch try child.nodeType() {
      case .object:
        return "\(try child.nodeValue())"
      default:
        break
      }
    }

    return try nodeInspect.call([try child.nodeValue(), try nextOptions()])
  }

  func inspect(_ inspectable: NodeInspect) throws -> InspectResult {
    let string = try inspectable.nodeInspect(try nextInspector())
    return InspectResult(string)
  }

  func keyPaths<T, each A: NodeValueConvertible>(value: T, paths: repeat (String, (T) throws -> each A)) throws -> String {
    var strings: [String] = []

    func item<V: NodeValueConvertible>(_ namePath: (String, (T) throws -> V)) throws {
      let name = namePath.0
      let path = namePath.1
      let convertible = try path(value)
      print("convertible type: \(type(of: convertible))")
      if let inspectResult = convertible as? InspectResult {
        strings.append("\(name): \(inspectResult.value)")
        return
      }
      let subvalue = try convertible.nodeValue()
      let inspected = try inspect(subvalue)
      strings.append("\(name): \(inspected)")
    }

    repeat try item(each paths)
    return strings.joined(separator: ", ")
  }

  func nodeClass<T: NodeClass, each A: NodeValueConvertible>(value: T, paths: repeat (String, (T) throws -> each A)) throws -> String {
    let name = try stylize(special: T.name)
    
    // NOTE: calling keyPaths here crashes the Swift 5.9 compiler
    // So, we copy-paste the implementation here.
    var strings: [String] = []

    func item<V: NodeValueConvertible>(_ namePath: (String, (T) throws -> V)) throws {
      let name = namePath.0
      let path = namePath.1
      let convertible = try path(value)
      if let inspectResult = convertible as? InspectResult {
        strings.append("\(name): \(inspectResult.value)")
        return
      }
      if let inspectable = convertible as? NodeInspect {
        let inspectResult = try inspect(inspectable)
        strings.append("\(name): \(inspectResult.value)")
        return
      }
      let subvalue = try convertible.nodeValue()
      let inspected = try inspect(subvalue)
      strings.append("\(name): \(inspected)")
    }

    repeat try item(each paths)

    let parts = strings.joined(separator: ", ")
    return "\(name) { \(parts) }"
  }
}

struct InspectResult: NodeValueConvertible, CustomDebugStringConvertible {
  let value: String
  let debugDescription: String

  init(_ value: String) {
    self.value = value
    self.debugDescription = value
  }

  func nodeValue() throws -> NodeValue {
    try NodeString(value)
  }
}

extension NodeMethod {
    /// Support for `@NodeMethod` on a func(Inspector)
    public init<T: NodeClass>(
        attributes: NodePropertyAttributes = .defaultMethod,
        _ callback: @escaping (T) -> @NodeActor (_: Inspector) throws -> NodeValueConvertible
    ) {
        self.init(attributes: attributes) { (target: T) in
            { (args: NodeArguments) in
                let inspector = try Inspector.from(args: args)
                return try callback(target)(inspector)
            }
        }
    }
}

