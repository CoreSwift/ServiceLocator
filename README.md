![CoreSwift Locks](Docs/coreswift-lockup-servicelocator.png#gh-light-mode-only)
![CoreSwift Locks](Docs/coreswift-lockup-servicelocator-dark.png#gh-dark-mode-only)

# ServiceLocator

Simple service locator infrastructure.

## Basic Example

```
/// Services available in the app scope.
protocol AppServices {
  var myAppScopedService: MyAppScopedServiceProtocol { get }
  var otherAppScopedService: OtherAppScopedServiceProtocol { get }
}

/// Production implementation of `AppServices`.
class ProdAppServices: ServiceLocator, AppServices {
  var myAppScopedService: MyAppScopedServiceProtocol {
    singleton { MyAppScopedServiceImpl(other: otherAppScopedService) }
  }
  …
  var otherAppScopedService: OtherAppScopedServiceProtocol {
    singleton { OtherAppScopedServiceImpl() }
  }
}
```

## Scopes

```
/// Services available in the user scope.
protocol UserServices {
}

/// Production implementation of `UserServices`.
class ProdUserServices<ProdUserServices>: ServiceLocator, UserServices {
  var myUserScopedService: MyUserScopedServiceProtocol {
    singleton {
      UserScopedServiceImplementation(parentService: parent.myAppScopedService)
    }
  }
}
```
