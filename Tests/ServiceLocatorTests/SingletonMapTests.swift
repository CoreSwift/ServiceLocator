import XCTest
import Dispatch
@testable import ServiceLocator

private actor TestState {
  var isReady: Bool
  var taskOneValue: TestItem?
  var taskTwoValue: TestItem?

  init() {
    self.isReady = false
    self.taskOneValue = nil
    self.taskTwoValue = nil
  }

  func markReady() {
    self.isReady = true
  }

  func setTaskOneValue(_ item: TestItem) {
    XCTAssertTrue(isReady, "Attempting to set task one value while not ready")
    taskOneValue = item
  }

  func setTaskTwoValue(_ item: TestItem) {
    XCTAssertTrue(isReady, "Attempting to set task two value while not ready")
    taskTwoValue = item
  }
}

final class SingletonMapTests: XCTestCase {
  func testItExecutesFactory() async throws {
    let map = SingletonMap<String>()

    let factoryExpectation = expectation(description: "Factory fulfilled")
    let factory: () -> TestItem = {
      factoryExpectation.fulfill()
      return TestItem()
    }

    let _ = map.getValue(for: "test", factory: factory)
    wait(for: [factoryExpectation], timeout: 5.0)
  }

  func testItBlocksOtherThreads() async throws {
    let map = SingletonMap<String>()

    let factoryWaiter = NSConditionLock(condition: 0)
    let factoryStartedExpectation = expectation(description: "Factory started")
    let factoryFinishedExpectation = expectation(description: "Factory finished")
    let factory: () -> TestItem = {
      factoryStartedExpectation.fulfill()

      factoryWaiter.lock(whenCondition: 1)
      defer { factoryWaiter.unlock() }

      factoryFinishedExpectation.fulfill()
      return TestItem()
    }

    let testState = TestState()

    let taskStartedExpectation = expectation(description: "Task one started")
    taskStartedExpectation.expectedFulfillmentCount = 2

    let taskFinishedExpectation = expectation(description: "Task finished")
    taskFinishedExpectation.expectedFulfillmentCount = 2

    Task.detached {
      taskStartedExpectation.fulfill()

      let fetched = map.getValue(for: "test", factory: factory)
      await testState.setTaskOneValue(fetched)

      taskFinishedExpectation.fulfill()
    }

    Task.detached {
      taskStartedExpectation.fulfill()

      let fetched = map.getValue(for: "test", factory: factory)
      await testState.setTaskTwoValue(fetched)

      taskFinishedExpectation.fulfill()
    }

    wait(
      for: [taskStartedExpectation, factoryStartedExpectation],
      timeout: 5.0)

    // Now that we know both tasks have started, give them a few seconds to store the
    await Task.sleep(3_000000000)

    // Verify that neither task has set a value (indicating that they are blocked waiting for the
    // factory to return.
    let taskOneState = await testState.taskOneValue
    XCTAssertNil(taskOneState)
    let taskTwoState = await testState.taskTwoValue
    XCTAssertNil(taskTwoState)

    // Allow the factory to proceed.
    await testState.markReady()
    factoryWaiter.lock()
    factoryWaiter.unlock(withCondition: 1)

    wait(
      for: [factoryFinishedExpectation, taskFinishedExpectation],
      timeout: 5.0)
  }

  func testItReturnsSameValue() async throws {
    let map = SingletonMap<String>()
    let factory: () -> TestItem = { TestItem() }

    let items = await withTaskGroup(of: TestItem.self) { group -> [TestItem] in
      var items = [TestItem]()

      for _ in 0..<30 {
        group.addTask { map.getValue(for: "test", factory: factory) }
      }

      for await item in group {
        items.append(item)
      }

      return items
    }

    XCTAssertEqual(items.count, 30)
    for item in items {
      XCTAssertIdentical(item, items[0])
    }
  }

  func testItDoesNotDeadlockWithCompetingKeys() async throws {
    // Use a single bucket to force all keys to compete.
    let map = SingletonMap<String>(bucketCount: 1)
    let dependencyFactory: () -> TestItem = { TestItem() }

    let value: TestItem = map.getValue(for: "test") {
      // Access a different key (which will map to the same bucket) inside of the factory function.
      let dep = map.getValue(for: "dep", factory: dependencyFactory)
      return TestItem(parent: dep)
    }

    // Getting a value back means there wasn't a deadlock.
    XCTAssertNotNil(value)
  }
}
