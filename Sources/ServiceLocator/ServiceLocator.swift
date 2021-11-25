import Foundation

/// Base class for a service locator.
///
/// Example:
///
///     /// Services available in the app scope.
///     protocol AppServices {
///       var myAppScopedService: MyAppScopedServiceProtocol { get }
///       var otherAppScopedService: OtherAppScopedServiceProtocol { get }
///     }
///
///     /// Production implementation of `AppServices`.
///     class ProdAppServices: ServiceLocator, AppServices {
///       var myAppScopedService: MyAppScopedServiceProtocol {
///         singleton { MyAppScopedServiceImpl(other: otherAppScopedService) }
///       }
///       …
///       var otherAppScopedService: OtherAppScopedServiceProtocol {
///         singleton { OtherAppScopedServiceImpl() }
///       }
///     }
open class ServiceLocator {
  /// Backing storage for any singletons stored in this locator.
  private let singletons = SingletonMap<String>()

  // MARK: Subclass Hooks

  /// Subclass hook for starting any actions (such as long-running "background" services) upon
  /// creation/startup of the locator.
  public func activate() {
  }

  /// Subclass hook for stopping any actions (such as long-running "background" services) upon
  /// teardown of the locator (as in the case of a scope ending - e.g. a user logging out).
  public func deactivate() {
  }

  // MARK: Singletons

  /// Returns a single instance of the given object `T`, constructing it if necessary using the
  /// given `factory`.
  ///
  /// Example:
  ///
  ///     class ProdAppServices: ServiceLocator {
  ///      …
  ///      var myService: MyServiceProtocol {
  ///        singleton { MyServiceImpl(other: otherService) }
  ///      }
  ///      …
  ///      var otherService: OtherServiceProtocol {
  ///        singleton { OtherServiceImpl() }
  ///      }
  ///      …
  ///     }
  public func singleton<T>(key: String = #function, factory: () -> T) -> T {
    singletons.getValue(for: key, factory: factory)
  }
}

// MARK: - Locator Hierarchies

/// Base class for a service locator that is scoped within another service locator.
///
/// Example:
///
///     protocol AppServices {}
///     protocol UserServices {}
///     
///     class ProdAppServices: ServiceLocator, AppServices {
///       var myAppScopedService: MyAppScopedServiceProtocol { … }
///     }
///
///     class ProdUserServices: ChildServiceLocator<ProdAppServices>, UserServices {
///       var myUserScopedService: MyUserScopedServiceProtocol {
///         singleton {
///           UserScopedServiceImplementation(parentService: parent.myAppScopedService)
///         }
///       }
///     }
open class ChildServiceLocator<Parent: ServiceLocator>: ServiceLocator {
  /// The parent service locator.
  public let parent: Parent

  /// Creates a new `ChildServiceLocator` with the given parent locator.
  init(parent: Parent) {
    self.parent = parent
  }
}
