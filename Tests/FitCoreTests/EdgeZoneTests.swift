import XCTest
@testable import FitCore

final class EdgeZoneTests: XCTestCase {
    // CG coordinates: y = 25 is just below the menu bar, y = 900 is the bottom.
    let vf = CGRect(x: 0, y: 25, width: 1600, height: 875)

    func zone(_ x: CGFloat, _ y: CGFloat) -> SnapAction? {
        EdgeZone.action(for: CGPoint(x: x, y: y), inVisibleFrame: vf)
    }

    func testLeftEdgeMiddleIsLeftHalf() {
        XCTAssertEqual(zone(0, 460), .leftHalf)
        XCTAssertEqual(zone(11, 460), .leftHalf)
    }

    func testLeftEdgeTopAndBottomAreQuarters() {
        XCTAssertEqual(zone(0, 30), .topLeftQuarter)
        XCTAssertEqual(zone(0, 890), .bottomLeftQuarter)
    }

    func testRightEdgeZones() {
        XCTAssertEqual(zone(1600, 460), .rightHalf)
        XCTAssertEqual(zone(1595, 40), .topRightQuarter)
        XCTAssertEqual(zone(1600, 880), .bottomRightQuarter)
    }

    func testTopEdgeCenterIsMaximize() {
        XCTAssertEqual(zone(800, 25), .maximize)
        XCTAssertEqual(zone(400, 30), .maximize)
    }

    func testPointerInMenuBarStillCountsAsTopEdge() {
        // The menu bar sits above the visible frame (y < vf.minY).
        XCTAssertEqual(zone(800, 5), .maximize)
    }

    func testCornerBeatsMaximize() {
        // A point in both the top band and the left band resolves to the corner.
        XCTAssertEqual(zone(5, 28), .topLeftQuarter)
        XCTAssertEqual(zone(1598, 28), .topRightQuarter)
    }

    func testBottomEdgeIsThirds() {
        XCTAssertEqual(zone(200, 900), .leftThird)
        XCTAssertEqual(zone(800, 900), .centerThird)
        XCTAssertEqual(zone(1400, 895), .rightThird)
    }

    func testPointerOverDockStillCountsAsBottomEdge() {
        // Dock area lies below the visible frame (y > vf.maxY).
        XCTAssertEqual(zone(800, 940), .centerThird)
    }

    func testInteriorIsNoZone() {
        XCTAssertNil(zone(800, 460))
        XCTAssertNil(zone(100, 100))
        XCTAssertNil(zone(1500, 800))
    }

    func testThresholdBoundary() {
        XCTAssertEqual(zone(12, 460), .leftHalf) // exactly at threshold
        XCTAssertNil(zone(13, 460)) // one point inside
    }
}
