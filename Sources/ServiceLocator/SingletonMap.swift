import Foundation

private enum Constants {
  #if os(iOS)
  static var defaultBucketCount = 8
  #else
  static var defaultBucketCount = 64
  #endif
}

/// An item within the singleton map.
private enum Item {
  /// Default state. The singleton has not been requested yet.
  case none
  /// The singleton is in the process of being constructed. The thread doing the initializing is
  /// responsible for updating the state once initialization is finished.
  case initializing
  /// The singleton has already been initialized.
  case value(_ value: Any)
}

/// A bucket in the singleton map.
///
/// The acutal item storage is within the bucket (as multiple types may map to a single bucket). All
/// access to the contents of th ebucket
private class Bucket<Key: Hashable> {
  /// Lock used to guard access to the bucket's contents.
  let lock = NSCondition()

  /// The contents of the bucket.
  ///
  /// - Attention: All access must be done while holding `lock`.
  var contents = [Key: Item]()

  /// Creates a new `Bucket` representing the given index.
  init(idx: Int) {
    if #available(macOS 10.5, *) {
      lock.name = "StripedMap.\(idx)"
    }
  }
}

/// Provides efficient thread-safe storage of singletons, for use in a service locator.
internal class SingletonMap<Key: Hashable> {
  /// The number of buckets to use.
  private let bucketCount: Int

  /// The buckets to use.
  ///
  /// - Note: For thread safety purposes, the full set of buckets are created at init and are
  ///   read-only. The contents of a bucket are still mutable (assuming the bucket's lock is held).
  private let buckets: [Bucket<Key>]

  // MARK: Constructors

  /// Creates a new `SingletonMap` with the given number of buckets.
  internal init(bucketCount: Int? = nil) {
    let bucketCount = bucketCount ?? Constants.defaultBucketCount
    precondition(bucketCount > 0)

    var buckets = [Bucket<Key>]()
    buckets.reserveCapacity(bucketCount)
    for i in 0..<bucketCount {
      buckets.append(Bucket<Key>(idx: i))
    }

    self.bucketCount = bucketCount
    self.buckets = buckets
  }

  // MARK: External API

  internal func getValue<T>(for key: Key, factory: () -> T) -> T {
    let bucket = getBucket(for: key)
    let lock = bucket.lock

    lock.lock()

    while(true) {
      let item = bucket.contents[key, default: .none]
      switch item {
      case .none:
        // Since nobody is working on constructing the value, this thread will become responsible.
        // Mark it down so that other threads that come along while we're in the middle of it will
        // wait until the object has been constructed.
        bucket.contents[key] = .initializing

        // No need to hold the lock while we're in the middle of constructing the value (which
        // might take a long time). Other threads will wait due to `contents` being `initializing`.
        lock.unlock()

        // Construct the object.
        let constructed = factory()

        // Grab the lock again to update our status and signal all the other waiting threads.
        lock.lock()

        bucket.contents[key] = .value(constructed)

        // All the parked threads should be able to quickly make forward progress, so a broadcast
        // is reasonable to use here.
        lock.broadcast()
        lock.unlock()

        // Return the value we constructed.
        return constructed
      case .initializing:
        // Someone else is in the middle of constructing the object, so just park this thread and
        // wait until the value is ready.
        //
        // Once the thread wakes we'll re-enter the loop and take a different course.
        lock.wait()
      case .value(let value):
        // We've already got a cached value, so just use it.
        lock.unlock()
        return value as! T
      }
    }
  }

  // MARK: Internals

  /// Returns the index into `locks` to use for the given key.
  private func getBucket(for key: Key) -> Bucket<Key> {
    let idx = abs(key.hashValue) % bucketCount
    return buckets[idx]
  }
}
