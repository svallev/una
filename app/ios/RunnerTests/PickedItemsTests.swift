import XCTest

@testable import Runner

/// CA-020-21 (016-c, CA-016-24) y CA-028-11: el tope de fotos se aplica antes de tocar ningún
/// elemento. Casos portados uno a uno de `PickedItemsTest.kt`.
class PickedItemsTests: XCTestCase {

  /// Un «selector» que cuenta cuántos elementos se le piden.
  private final class Counting {
    let count: Int
    private(set) var touched: [Int] = []

    init(_ count: Int) {
      self.count = count
    }

    func at(_ index: Int) -> String? {
      touched.append(index)
      return "photo-\(index)"
    }
  }

  func testCA02021_5000ItemsFromThePickerOnlyTouchTheFirst10() {
    let picker = Counting(5000)
    let items = PickedItems.firstItems(count: picker.count, max: 10) { picker.at($0) }
    XCTAssertEqual(picker.touched.count, 10)
    XCTAssertEqual(picker.touched, Array(0..<10))
    XCTAssertEqual(items, (0..<10).map { "photo-\($0)" })
  }

  func testCA02021_theRequestedCapRulesEvenWithManyMore() {
    for max in 1...10 {
      let picker = Counting(5000)
      let items = PickedItems.firstItems(count: picker.count, max: max) { picker.at($0) }
      XCTAssertEqual(picker.touched.count, max, "max=\(max)")
      XCTAssertEqual(items.count, max)
    }
  }

  func testCA02021_withFewerItemsThanTheCapOnlyThoseAreAskedFor() {
    let picker = Counting(3)
    let items = PickedItems.firstItems(count: picker.count, max: 10) { picker.at($0) }
    XCTAssertEqual(picker.touched, [0, 1, 2])
    XCTAssertEqual(items.count, 3)
  }

  func testCA02021_noItemsOrAnInvalidCapTouchNothing() {
    for (count, max) in [(0, 10), (-1, 10), (5000, 0), (5000, -3), (Int.max, 0)] {
      let picker = Counting(count)
      let items = PickedItems.firstItems(count: count, max: max) { picker.at($0) }
      XCTAssertTrue(picker.touched.isEmpty, "count=\(count) max=\(max)")
      XCTAssertTrue(items.isEmpty)
    }
  }

  func testCA02021_aHugeItemCountWalksNothingExtra() {
    let picker = Counting(Int.max)
    _ = PickedItems.firstItems(count: picker.count, max: 10) { picker.at($0) }
    XCTAssertEqual(picker.touched.count, 10)
  }

  func testCA02021_itemsWithoutAnAddressAreSkippedButStillCountForTheCap() {
    var touched: [Int] = []
    let items = PickedItems.firstItems(count: 5000, max: 10) { (i: Int) -> String? in
      touched.append(i)
      return i % 2 == 0 ? nil : "u\(i)"
    }
    // Se miran 10, no 20 para completar diez válidos: el tope es de accesos.
    XCTAssertEqual(touched.count, 10)
    XCTAssertEqual(items, ["u1", "u3", "u5", "u7", "u9"])
  }

  func testCA02021_theOrderIsTheOneThePickerReturned() {
    let items = PickedItems.firstItems(count: 4, max: 10) { "u\($0)" }
    XCTAssertEqual(items, ["u0", "u1", "u2", "u3"])
  }
}
