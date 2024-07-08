// https://gist.github.com/jegnux/4a9871220ef93016d92194ecf7ae8919
@propertyWrapper
public struct AnyProxy<EnclosingSelf, Value> {
    private let keyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>

    public init(_ keyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>) {
        self.keyPath = keyPath
    }

    @available(*, unavailable, message: "The wrapped value must be accessed from the enclosing instance property.")
    public var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    public static subscript(
        _enclosingInstance observed: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
    ) -> Value {
        get {
            let storageValue = observed[keyPath: storageKeyPath]
            let value = observed[keyPath: storageValue.keyPath]
            return value
        }
        set {
            let storageValue = observed[keyPath: storageKeyPath]
            observed[keyPath: storageValue.keyPath] = newValue
        }
    }
}

// Kudos @johnsundell for this trick
// https://swiftbysundell.com/articles/accessing-a-swift-property-wrappers-enclosing-instance/
// extension NSObject: ProxyContainer {}
// public protocol ProxyContainer {
//   typealias Proxy<T> = AnyProxy<Self, T>
// }

@propertyWrapper
struct SpecificProxy<EnclosingSelf: SpecificProxyContainer, Value> {
  typealias InnerProxy = AnyProxy<EnclosingSelf, Value>
  private var inner: InnerProxy
  
  @available(
    *, unavailable,
    message: "The wrapped value must be accessed from the enclosing instance property."
  )
  public var wrappedValue: Value {
    get { fatalError() }
    set { fatalError() }
  }
  
  public init(_ keyPath: ReferenceWritableKeyPath<EnclosingSelf.Wrapped, Value>) {
    let outerKeyPath = (\EnclosingSelf.inner).appending(path: keyPath)
    inner = AnyProxy(outerKeyPath)
  }
  
  public static subscript(
    _enclosingInstance observed: EnclosingSelf,
    wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
    storage outerStorageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
  ) -> Value {
    get {
      AnyProxy[_enclosingInstance: observed, wrapped: wrappedKeyPath, storage: outerStorageKeyPath.appending(path: \.inner)
               ]
    }
    set {
      AnyProxy[_enclosingInstance: observed, wrapped: wrappedKeyPath, storage: outerStorageKeyPath.appending(path: \.inner)
               ] = newValue

    }
  }
}


protocol SpecificProxyContainer {
  associatedtype Wrapped
  var inner: Wrapped { get }
  
  typealias Proxy<Value> = SpecificProxy<Self, Value>
}


