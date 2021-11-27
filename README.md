![CoreSwift Locks](Docs/coreswift-lockup-servicelocator.svg#gh-light-mode-only)
![CoreSwift Locks](Docs/coreswift-lockup-servicelocator-dark.svg#gh-dark-mode-only)

![badge-languages][] ![badge-platforms][] ![badge-license][]
![badge-ci][] [![badge-codecov]][codecov-url]

---

# ServiceLocator

Simple service locator infrastructure. Pass around protocols backed by these locators to your view
controllers and coordinators to simplify dependency injection.

## Basic Example

```swift
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

Compose service locators to provide isolation amongst domains.

![Scopes](Docs/Assets/Scopes.png)

### Broad Rules

* Parent scopes **must not** access services from child scopes
* Child scopes **can** access services from parent scopes
* Child scopes **must not** access services/data from sibling scopes

### Example

```swift
/// Services available in the user scope.
protocol UserServices {
  var myUserScopedService: MyUserScopedServiceProtocol { get }
}

/// Production implementation of `UserServices`.
class ProdUserServices: ChildServiceLocator<ProdAppServices>, UserServices {
  var myUserScopedService: MyUserScopedServiceProtocol {
    singleton {
      UserScopedServiceImplementation(parentService: parent.myAppScopedService)
    }
  }
}
```

[badge-languages]: https://img.shields.io/badge/languages-Swift-orange.svg
[badge-platforms]: https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20Linux-lightgrey.svg
[badge-license]: https://img.shields.io/github/license/CoreSwift/Locks
[badge-ci]: https://github.com/CoreSwift/ServiceLocator/actions/workflows/ci.yml/badge.svg
[badge-codecov]: https://codecov.io/gh/CoreSwift/ServiceLocator/branch/main/graph/badge.svg?token=V29B0Q2IS5
[codecov-url]: https://codecov.io/gh/CoreSwift/ServiceLocator
