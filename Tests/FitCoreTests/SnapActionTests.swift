import XCTest
@testable import FitCore

final class SnapActionCycleTests: XCTestCase {
    func testCycleChainsStartWithSelfAndHaveNoDuplicates() {
        for action in SnapAction.allCases {
            guard let chain = action.cycleChain else { continue }
            XCTAssertEqual(chain.first, action, "\(action) chain must start with itself")
            XCTAssertGreaterThan(chain.count, 1, "\(action) chain must actually cycle")
            XCTAssertEqual(Set(chain).count, chain.count, "\(action) chain has duplicates")
        }
    }

    func testHorizontalHalvesCycleThroughWidths() {
        XCTAssertEqual(SnapAction.leftHalf.cycleChain, [.leftHalf, .leftTwoThirds, .leftThird])
        XCTAssertEqual(SnapAction.rightHalf.cycleChain, [.rightHalf, .rightTwoThirds, .rightThird])
    }

    func testVerticalHalvesCycleThroughHeights() {
        XCTAssertEqual(SnapAction.topHalf.cycleChain, [.topHalf, .topTwoThirds, .topThird])
        XCTAssertEqual(SnapAction.bottomHalf.cycleChain, [.bottomHalf, .bottomTwoThirds, .bottomThird])
    }

    func testOnlyFourHalvesCycle() {
        let cycling = SnapAction.allCases.filter { $0.cycleChain != nil }
        XCTAssertEqual(Set(cycling), [.leftHalf, .rightHalf, .topHalf, .bottomHalf])
    }

    func testCycleChainMembersResolveToFrames() {
        // Every chain member must be a purely geometric action.
        let vf = CGRect(x: 0, y: 25, width: 1600, height: 875)
        let calc = LayoutCalculator(gap: 0)
        for action in SnapAction.allCases {
            for member in action.cycleChain ?? [] {
                XCTAssertNotNil(calc.frame(for: member, in: vf), "\(member) has no frame")
            }
        }
    }
}

final class CombinedQuarterTests: XCTestCase {
    func testPerpendicularPairsProduceCorrectCorner() {
        // Order doesn't matter — pressing ← then ↑ or ↑ then ← both give top-left.
        let cases: [(SnapAction, SnapAction, SnapAction)] = [
            (.leftHalf, .topHalf, .topLeftQuarter),
            (.topHalf, .leftHalf, .topLeftQuarter),
            (.leftHalf, .bottomHalf, .bottomLeftQuarter),
            (.bottomHalf, .leftHalf, .bottomLeftQuarter),
            (.rightHalf, .topHalf, .topRightQuarter),
            (.topHalf, .rightHalf, .topRightQuarter),
            (.rightHalf, .bottomHalf, .bottomRightQuarter),
            (.bottomHalf, .rightHalf, .bottomRightQuarter),
        ]
        for (base, add, expected) in cases {
            XCTAssertEqual(SnapAction.combinedQuarter(base: base, add: add), expected,
                           "\(base) + \(add) should give \(expected)")
        }
    }

    func testParallelHalvesDoNotCombine() {
        // Same-axis pairs (left + right, top + bottom) don't form a corner.
        XCTAssertNil(SnapAction.combinedQuarter(base: .leftHalf, add: .rightHalf))
        XCTAssertNil(SnapAction.combinedQuarter(base: .topHalf, add: .bottomHalf))
        XCTAssertNil(SnapAction.combinedQuarter(base: .leftHalf, add: .leftHalf))
    }

    func testNonHalfBasesDoNotCombine() {
        // Only pure halves are combining bases — thirds, quarters, and other
        // states drop through to a fresh snap.
        XCTAssertNil(SnapAction.combinedQuarter(base: .leftThird, add: .topHalf))
        XCTAssertNil(SnapAction.combinedQuarter(base: .topLeftQuarter, add: .topHalf))
        XCTAssertNil(SnapAction.combinedQuarter(base: .maximize, add: .topHalf))
    }
}

final class DragSuppressModifierTests: XCTestCase {
    func testRawValueRoundTrip() {
        for modifier in DragSuppressModifier.allCases {
            XCTAssertEqual(DragSuppressModifier(rawValue: modifier.rawValue), modifier)
        }
    }

    func testTitlesAreUnique() {
        let titles = DragSuppressModifier.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count)
    }
}
