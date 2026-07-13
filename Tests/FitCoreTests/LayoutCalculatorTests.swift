import XCTest
@testable import FitCore

final class LayoutCalculatorTests: XCTestCase {
    // A 1600x875 visible frame offset by the 25pt menu bar, CG coordinates.
    let vf = CGRect(x: 0, y: 25, width: 1600, height: 875)

    func assertRect(_ actual: CGRect?, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else {
            XCTFail("expected \(expected), got nil", file: file, line: line)
            return
        }
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.01, "minX", file: file, line: line)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.01, "minY", file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: 0.01, "width", file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: 0.01, "height", file: file, line: line)
    }

    // MARK: - No gap

    func testHalvesWithoutGap() {
        let calc = LayoutCalculator(gap: 0)
        assertRect(calc.frame(for: .leftHalf, in: vf), CGRect(x: 0, y: 25, width: 800, height: 875))
        assertRect(calc.frame(for: .rightHalf, in: vf), CGRect(x: 800, y: 25, width: 800, height: 875))
        assertRect(calc.frame(for: .topHalf, in: vf), CGRect(x: 0, y: 25, width: 1600, height: 437.5))
        assertRect(calc.frame(for: .bottomHalf, in: vf), CGRect(x: 0, y: 462.5, width: 1600, height: 437.5))
    }

    func testQuartersWithoutGap() {
        let calc = LayoutCalculator(gap: 0)
        assertRect(calc.frame(for: .topLeftQuarter, in: vf), CGRect(x: 0, y: 25, width: 800, height: 437.5))
        assertRect(calc.frame(for: .topRightQuarter, in: vf), CGRect(x: 800, y: 25, width: 800, height: 437.5))
        assertRect(calc.frame(for: .bottomLeftQuarter, in: vf), CGRect(x: 0, y: 462.5, width: 800, height: 437.5))
        assertRect(calc.frame(for: .bottomRightQuarter, in: vf), CGRect(x: 800, y: 462.5, width: 800, height: 437.5))
    }

    func testThirdsWithoutGap() {
        let calc = LayoutCalculator(gap: 0)
        let third = 1600.0 / 3
        assertRect(calc.frame(for: .leftThird, in: vf), CGRect(x: 0, y: 25, width: third, height: 875))
        assertRect(calc.frame(for: .centerThird, in: vf), CGRect(x: third, y: 25, width: third, height: 875))
        assertRect(calc.frame(for: .rightThird, in: vf), CGRect(x: 2 * third, y: 25, width: third, height: 875))
        assertRect(calc.frame(for: .leftTwoThirds, in: vf), CGRect(x: 0, y: 25, width: 2 * third, height: 875))
        assertRect(calc.frame(for: .rightTwoThirds, in: vf), CGRect(x: third, y: 25, width: 2 * third, height: 875))
    }

    func testRowThirdsWithoutGap() {
        let calc = LayoutCalculator(gap: 0)
        let third = 875.0 / 3
        assertRect(calc.frame(for: .topThird, in: vf), CGRect(x: 0, y: 25, width: 1600, height: third))
        assertRect(calc.frame(for: .middleThird, in: vf), CGRect(x: 0, y: 25 + third, width: 1600, height: third))
        assertRect(calc.frame(for: .bottomThird, in: vf), CGRect(x: 0, y: 25 + 2 * third, width: 1600, height: third))
        assertRect(calc.frame(for: .topTwoThirds, in: vf), CGRect(x: 0, y: 25, width: 1600, height: 2 * third))
        assertRect(calc.frame(for: .bottomTwoThirds, in: vf), CGRect(x: 0, y: 25 + third, width: 1600, height: 2 * third))
    }

    func testRowThirdsTileVertically() {
        let calc = LayoutCalculator(gap: 8)
        let top = calc.frame(for: .topThird, in: vf)!
        let mid = calc.frame(for: .middleThird, in: vf)!
        let bot = calc.frame(for: .bottomThird, in: vf)!
        XCTAssertEqual(mid.minY - top.maxY, 8, accuracy: 0.01, "gutter top→middle")
        XCTAssertEqual(bot.minY - mid.maxY, 8, accuracy: 0.01, "gutter middle→bottom")
        XCTAssertEqual(top.height, mid.height, accuracy: 0.01)
        XCTAssertEqual(mid.height, bot.height, accuracy: 0.01)
    }

    func testMaximizeWithoutGapFillsVisibleFrame() {
        let calc = LayoutCalculator(gap: 0)
        assertRect(calc.frame(for: .maximize, in: vf), vf)
    }

    // MARK: - With gap

    func testHalvesWithGapShareOneGutter() {
        let gap: CGFloat = 16
        let calc = LayoutCalculator(gap: gap)
        let left = calc.frame(for: .leftHalf, in: vf)!
        let right = calc.frame(for: .rightHalf, in: vf)!
        XCTAssertEqual(left.minX, vf.minX + gap, accuracy: 0.01)
        XCTAssertEqual(right.maxX, vf.maxX - gap, accuracy: 0.01)
        XCTAssertEqual(right.minX - left.maxX, gap, accuracy: 0.01, "gutter between halves")
        XCTAssertEqual(left.width, right.width, accuracy: 0.01)
        XCTAssertEqual(left.minY, vf.minY + gap, accuracy: 0.01)
        XCTAssertEqual(left.height, vf.height - 2 * gap, accuracy: 0.01)
    }

    func testThirdsWithGapTile() {
        let gap: CGFloat = 10
        let calc = LayoutCalculator(gap: gap)
        let l = calc.frame(for: .leftThird, in: vf)!
        let c = calc.frame(for: .centerThird, in: vf)!
        let r = calc.frame(for: .rightThird, in: vf)!
        XCTAssertEqual(c.minX - l.maxX, gap, accuracy: 0.01)
        XCTAssertEqual(r.minX - c.maxX, gap, accuracy: 0.01)
        XCTAssertEqual(l.width, c.width, accuracy: 0.01)
        XCTAssertEqual(c.width, r.width, accuracy: 0.01)
        XCTAssertEqual(r.maxX, vf.maxX - gap, accuracy: 0.01)
    }

    func testTwoThirdsWithGapSpansUnitPlusGutter() {
        let gap: CGFloat = 10
        let calc = LayoutCalculator(gap: gap)
        let one = calc.frame(for: .leftThird, in: vf)!
        let two = calc.frame(for: .leftTwoThirds, in: vf)!
        XCTAssertEqual(two.width, one.width * 2 + gap, accuracy: 0.01)
        // leftTwoThirds + rightThird tile the row exactly.
        let r = calc.frame(for: .rightThird, in: vf)!
        XCTAssertEqual(r.minX - two.maxX, gap, accuracy: 0.01)
    }

    func testQuarterWithGapMatchesHalfEdges() {
        let calc = LayoutCalculator(gap: 8)
        let tl = calc.frame(for: .topLeftQuarter, in: vf)!
        let left = calc.frame(for: .leftHalf, in: vf)!
        let top = calc.frame(for: .topHalf, in: vf)!
        XCTAssertEqual(tl.minX, left.minX, accuracy: 0.01)
        XCTAssertEqual(tl.width, left.width, accuracy: 0.01)
        XCTAssertEqual(tl.minY, top.minY, accuracy: 0.01)
        XCTAssertEqual(tl.height, top.height, accuracy: 0.01)
    }

    // MARK: - Center / proportional mapping

    func testCenteredKeepsSize() {
        let calc = LayoutCalculator(gap: 0)
        let rect = calc.centered(size: CGSize(width: 400, height: 300), in: vf)
        XCTAssertEqual(rect.width, 400)
        XCTAssertEqual(rect.height, 300)
        XCTAssertEqual(rect.midX, vf.midX, accuracy: 0.01)
        XCTAssertEqual(rect.midY, vf.midY, accuracy: 0.01)
    }

    func testCenteredClampsOversizedWindow() {
        let calc = LayoutCalculator(gap: 0)
        let rect = calc.centered(size: CGSize(width: 5000, height: 5000), in: vf)
        XCTAssertLessThanOrEqual(rect.width, vf.width)
        XCTAssertLessThanOrEqual(rect.height, vf.height)
        XCTAssertTrue(vf.contains(rect))
    }

    func testProportionalMappingPreservesRelativePosition() {
        let from = CGRect(x: 0, y: 25, width: 1600, height: 875)
        let to = CGRect(x: 1600, y: 0, width: 800, height: 600)
        // Left half of `from` maps to left half of `to`.
        let mapped = LayoutCalculator.proportionallyMapped(
            CGRect(x: 0, y: 25, width: 800, height: 875), from: from, to: to)
        XCTAssertEqual(mapped.minX, 1600, accuracy: 0.01)
        XCTAssertEqual(mapped.minY, 0, accuracy: 0.01)
        XCTAssertEqual(mapped.width, 400, accuracy: 0.01)
        XCTAssertEqual(mapped.height, 600, accuracy: 0.01)
    }

    func testProportionalMappingClampsIntoDestination() {
        let from = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let to = CGRect(x: 2000, y: 0, width: 500, height: 500)
        let mapped = LayoutCalculator.proportionallyMapped(
            CGRect(x: 900, y: 900, width: 300, height: 300), from: from, to: to)
        XCTAssertTrue(to.contains(mapped), "\(mapped) should fit in \(to)")
    }

    // MARK: - Non-geometric actions

    func testNonGeometricActionsReturnNil() {
        let calc = LayoutCalculator(gap: 0)
        for action: SnapAction in [.restore, .center, .previousDisplay, .nextDisplay] {
            XCTAssertNil(calc.frame(for: action, in: vf), "\(action)")
        }
    }
}
