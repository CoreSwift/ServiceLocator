class TestItem: @unchecked Sendable, CustomStringConvertible, Equatable {
  var parentItems: [TestItem]

  init() {
    self.parentItems = []
  }

  init(parent: TestItem) {
    self.parentItems = [parent]
  }

  init(parents: [TestItem]) {
    self.parentItems = parents
  }

  var description: String {
    let address = Unmanaged.passUnretained(self).toOpaque()
    return """
      TestItem<\(address); parents=[\(parentItems.map({ $0.description }).joined(separator: ","))]>
    """
  }

  static func == (lhs: TestItem, rhs: TestItem) -> Bool {
    return lhs === rhs
  }
}
