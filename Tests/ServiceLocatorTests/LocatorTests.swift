import XCTest
@testable import ServiceLocator

private class RootLocator: ServiceLocator {
  var itemOne: TestItem {
    singleton { TestItem() }
  }

  var itemTwo: TestItem {
    singleton { TestItem() }
  }

  var compositeItem: TestItem {
    singleton { TestItem(parent: itemOne) }
  }
}

private class ChildLocator: ChildServiceLocator<RootLocator> {
  var childCompositeItem: TestItem {
    singleton {
      TestItem(parents: [
        parent.compositeItem
      ])
    }
  }
}

final class ServiceLocatorTests: XCTestCase {
  func testSingletonReturnsSameValue() async throws {
    let locator = RootLocator()

    let itemOne = locator.itemOne
    let itemTwo = locator.itemOne

    XCTAssertIdentical(itemOne, itemTwo)
  }

  func testSingletonCompositeItem() async throws {
    let locator = RootLocator()

    let singletonItem = locator.itemOne
    let compositeItem = locator.compositeItem

    XCTAssertIdentical(compositeItem.parentItems[0], singletonItem)
  }

  func testChildAccessesParent() async throws {
    let root = RootLocator()
    let child = ChildLocator(parent: root)

    let childComposite = child.childCompositeItem

    XCTAssertIdentical(childComposite.parentItems[0], root.compositeItem)
  }
}
