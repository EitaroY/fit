import XCTest
@testable import FitCore

final class ShortcutTests: XCTestCase {
    func testDefaultBindingsCoverEveryActionExceptRowThirds() {
        // Row thirds (top/middle/bottom + two-thirds) are opt-in: reachable
        // by cycling from top/bottom halves, or by binding manually. Every
        // other action ships with a Magnet-compatible default.
        let optIn: Set<SnapAction> = [.topThird, .middleThird, .bottomThird, .topTwoThirds, .bottomTwoThirds]
        for action in SnapAction.allCases where !optIn.contains(action) {
            XCTAssertNotNil(Shortcut.defaultBindings[action], "\(action) has no default binding")
        }
    }

    func testDefaultBindingsHaveNoDuplicateCombos() {
        let all = Array(Shortcut.defaultBindings.values)
        for (i, a) in all.enumerated() {
            for b in all[(i + 1)...] {
                XCTAssertFalse(a.matches(b), "duplicate combo: \(a.display) vs \(b.display)")
            }
        }
    }

    func testMatchesIgnoresLabel() {
        let a = Shortcut(keyCode: 123, carbonModifiers: CarbonModifier.control, keyLabel: "←")
        let b = Shortcut(keyCode: 123, carbonModifiers: CarbonModifier.control, keyLabel: "Left")
        XCTAssertTrue(a.matches(b))
        XCTAssertNotEqual(a, b) // full equality includes the label
    }

    func testDisplayOrdersModifiersConventionally() {
        let s = Shortcut(
            keyCode: KeyCode.leftArrow,
            carbonModifiers: CarbonModifier.command | CarbonModifier.control | CarbonModifier.option,
            keyLabel: "←")
        XCTAssertEqual(s.display, "⌃⌥⌘←")
    }

    func testCodableRoundTrip() throws {
        let original = Shortcut.defaultBindings
        let data = try JSONEncoder().encode(
            Dictionary(uniqueKeysWithValues: original.map { ($0.key.rawValue, $0.value) }))
        let decoded = try JSONDecoder().decode([String: Shortcut].self, from: data)
        XCTAssertEqual(decoded.count, original.count)
        for (action, shortcut) in original {
            XCTAssertEqual(decoded[action.rawValue], shortcut)
        }
    }

    func testMenuGroupsContainEveryActionOnce() {
        let listed = SnapAction.menuGroups.flatMap(\.actions)
        XCTAssertEqual(listed.count, SnapAction.allCases.count)
        XCTAssertEqual(Set(listed).count, SnapAction.allCases.count)
    }
}
