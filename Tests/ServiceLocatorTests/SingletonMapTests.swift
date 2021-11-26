import XCTest
import Dispatch
@testable import ServiceLocator

final class SingletonMapTests: XCTestCase {
  func testItExecutesFactory() throws {
    let map = SingletonMap<String>()

    let factoryExpectation = expectation(description: "Factory fulfilled")
    let factory: () -> TestItem = {
      factoryExpectation.fulfill()
      return TestItem()
    }

    let _ = map.getValue(for: "test", factory: factory)
    wait(for: [factoryExpectation], timeout: 5.0)
  }

  func testItBlocksOtherThreads() throws {
    let map = SingletonMap<String>()

    var factoryReady = false
    let factoryWaiter = NSCondition()

    let factoryStartedExpectation = expectation(description: "Factory started")
    let factoryFinishedExpectation = expectation(description: "Factory finished")
    let factory: () -> TestItem = {
      factoryStartedExpectation.fulfill()

      // Wait until the factory is ready.
      factoryWaiter.lock()
      while !factoryReady {
        factoryWaiter.wait()
      }
      factoryWaiter.unlock()

      factoryFinishedExpectation.fulfill()
      return TestItem()
    }

    let taskOneStartedExpectation = expectation(description: "Task one started")
    let taskOneFinishedExpectation = expectation(description: "Task one finished")
    taskOneFinishedExpectation.isInverted = true  // Fail if fulfilled prematurely
    DispatchQueue.global().async {
      taskOneStartedExpectation.fulfill()
      let _ = map.getValue(for: "test", factory: factory)
      taskOneFinishedExpectation.fulfill()
    }

    let taskTwoStartedExpectation = expectation(description: "Task two started")
    let taskTwoFinishedExpectation = expectation(description: "Task two finished")
    taskTwoFinishedExpectation.isInverted = true  // Fail if fulfilled prematurely
    DispatchQueue.global().async {
      taskTwoStartedExpectation.fulfill()
      let _ = map.getValue(for: "test", factory: factory)
      taskTwoFinishedExpectation.fulfill()
    }

    wait(
      for: [taskOneStartedExpectation, taskTwoStartedExpectation, factoryStartedExpectation],
      timeout: 5.0)

    // Now that the background tasks have started, wait a few seconds to ensure that they don't
    // end prematurely (indicating that they didn't block in `getValue()`).
    Thread.sleep(forTimeInterval: 3.0)

    // Before we allow the factory to proceed (and unblock the background threads), mark their
    // expectations as non-inverted so we don't fail the test once we unblock.
    taskOneFinishedExpectation.isInverted = false
    taskTwoFinishedExpectation.isInverted = false

    // Signal the factory that it can now proceed.
    factoryWaiter.lock()
    factoryReady = true
    factoryWaiter.broadcast()
    factoryWaiter.unlock()

    wait(
      for: [factoryFinishedExpectation, taskOneFinishedExpectation, taskTwoFinishedExpectation],
      timeout: 5.0)
  }

  func testItReturnsSameValue() throws {
    let map = SingletonMap<String>()
    let factory: () -> TestItem = { TestItem() }

    let firstItem = map.getValue(for: "test", factory: factory)

    DispatchQueue.concurrentPerform(iterations: 50) { i in
      let item = map.getValue(for: "test", factory: factory)
      XCTAssertIdentical(item, firstItem)
    }
  }

  func testItDoesNotDeadlockWithCompetingKeys() throws {
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
