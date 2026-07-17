import XCTest
@testable import Kitchenline

final class KitchenlineLogicTests: XCTestCase {

    // MARK: CourtGeometry

    func testCourtGeometry_MirroredFlipsXKeepsY() {
        let mirrored = CourtGeometry.mirrored(CourtPoint(x: 5, y: 30))
        XCTAssertEqual(mirrored.x, 15, accuracy: 0.001)
        XCTAssertEqual(mirrored.y, 30, accuracy: 0.001)
    }

    func testCourtGeometry_ViewPointMapsProportionally() {
        let point = CourtGeometry.viewPoint(for: CourtPoint(x: 10, y: 22), in: CGSize(width: 200, height: 440))
        XCTAssertEqual(point.x, 100, accuracy: 0.01)
        XCTAssertEqual(point.y, 220, accuracy: 0.01)
    }

    // MARK: Drill library integrity

    func testDrillLibrary_HasAtLeast15UniqueDrillsAcrossAllFourCategories() {
        XCTAssertGreaterThanOrEqual(DrillLibrary.all.count, 15)
        XCTAssertEqual(Set(DrillLibrary.all.map(\.id)).count, DrillLibrary.all.count, "drill ids must be unique")
        XCTAssertEqual(Set(DrillLibrary.all.map(\.name)).count, DrillLibrary.all.count, "drill names must be unique")
        XCTAssertEqual(Set(DrillLibrary.all.map(\.category)), Set(DrillCategory.allCases), "every category must have at least one drill")
    }

    func testDrillLibrary_NamedLookupIsCaseInsensitiveAndRejectsUnrelatedText() {
        XCTAssertNotNil(DrillLibrary.drill(named: "cross-court dinking"))
        XCTAssertNil(DrillLibrary.drill(named: "Not A Real Drill"))
    }

    // MARK: Drill rep mirroring

    func testDrill_PathForRep_MirrorsOnOddRepsWhenEnabled() {
        let drill = DrillLibrary.drill(id: "cross-court-dinking")!
        let rep0 = drill.path(forRep: 0)
        let rep1 = drill.path(forRep: 1)
        XCTAssertEqual(rep0.origin, drill.origin)
        XCTAssertEqual(rep0.target, drill.target)
        XCTAssertEqual(rep1.origin, CourtGeometry.mirrored(drill.origin))
        XCTAssertEqual(rep1.target, CourtGeometry.mirrored(drill.target))
    }

    func testDrill_PathForRep_NeverMirrorsWhenDisabled() {
        let drill = DrillLibrary.drill(id: "split-step-ladder")!
        XCTAssertFalse(drill.mirrorsEachRep)
        XCTAssertEqual(drill.path(forRep: 1).origin, drill.origin)
        XCTAssertEqual(drill.path(forRep: 1).target, drill.target)
    }

    // MARK: FallbackPlanner

    func testFallbackPlanner_RepsPerDrillClampsToSaneRange() {
        XCTAssertEqual(FallbackPlanner.repsPerDrill(minutes: 10, drillCount: 2), 10) // 20/2
        XCTAssertEqual(FallbackPlanner.repsPerDrill(minutes: 100, drillCount: 1), 30) // 200 clamped down
        XCTAssertEqual(FallbackPlanner.repsPerDrill(minutes: 10, drillCount: 5), 6) // 4 clamped up
    }

    func testFallbackPlanner_GenerateProducesFourDaysWithValidLibraryDrillNames() {
        let plan = FallbackPlanner.generate(weakShots: [.thirdShotDrop], minutesAvailable: 30)
        XCTAssertEqual(plan.days.count, 4)
        for day in plan.days {
            XCTAssertEqual(day.focus, "Third Shot Drop")
            XCTAssertEqual(day.drills.count, 2)
            for planned in day.drills {
                XCTAssertNotNil(DrillLibrary.drill(named: planned.drillName), "\(planned.drillName) must be a real bundled drill")
            }
        }
    }

    func testFallbackPlanner_GhostWaypointsStayWithinCourtBoundsAndAdvanceInTime() {
        for drill in DrillLibrary.all {
            let waypoints = FallbackPlanner.ghostWaypoints(for: drill)
            XCTAssertGreaterThanOrEqual(waypoints.count, 2, "\(drill.name) needs at least 2 waypoints to animate")
            var lastTime = -1.0
            for waypoint in waypoints {
                XCTAssertGreaterThan(waypoint.time, lastTime, "\(drill.name) waypoints must strictly advance in time")
                XCTAssertTrue((0...CourtGeometry.widthFeet).contains(waypoint.x), "\(drill.name) x out of bounds")
                XCTAssertTrue((0...CourtGeometry.lengthFeet).contains(waypoint.y), "\(drill.name) y out of bounds")
                lastTime = waypoint.time
            }
        }
    }

    // MARK: PracticePlanParser

    func testPracticePlanParser_ParsesValidJSONAndDropsUnknownDrillNames() {
        let text = """
        Here is your plan:
        {"days":[{"day":"Monday","focus":"Dinking","minutes":25,"drills":[{"drillName":"Cross-Court Dinking","reps":12},{"drillName":"Not A Real Drill","reps":99}]}]}
        """
        let plan = PracticePlanParser.parse(text)
        XCTAssertNotNil(plan)
        XCTAssertEqual(plan?.days.count, 1)
        XCTAssertEqual(plan?.days.first?.drills.count, 1, "the unrecognized drill name must be dropped")
        XCTAssertEqual(plan?.days.first?.drills.first?.drillName, "Cross-Court Dinking")
        XCTAssertEqual(plan?.days.first?.drills.first?.reps, 12)
    }

    func testPracticePlanParser_ReturnsNilForTextWithNoJSON() {
        XCTAssertNil(PracticePlanParser.parse("Sorry, I can't help with that right now."))
    }

    // MARK: GhostRallyParser

    func testGhostRallyParser_FiltersOutOfBoundsWaypointsAndSortsByTime() {
        let text = """
        [{"time":0.5,"courtX":10,"courtY":20},{"time":0.0,"courtX":5,"courtY":25},{"time":0.2,"courtX":999,"courtY":20}]
        """
        let waypoints = GhostRallyParser.parse(text)
        XCTAssertNotNil(waypoints)
        XCTAssertEqual(waypoints?.count, 2, "the out-of-bounds courtX=999 waypoint must be dropped")
        XCTAssertEqual(waypoints?.first?.time, 0.0)
        XCTAssertEqual(waypoints?.last?.time, 0.5)
    }

    // MARK: DailyProgressLogic

    func testDailyProgressLogic_RolloverKeepsSameDayAndDropsDifferentDay() {
        let now = Date()
        let arc = LockedArc(origin: CourtPoint(x: 0, y: 0), target: CourtPoint(x: 1, y: 1), categoryRaw: DrillCategory.dinking.rawValue, timestamp: now)
        let sameDayKey = DailyProgressLogic.dayKey(for: now)

        XCTAssertEqual(DailyProgressLogic.rollover(storedArcs: [arc], storedDayKey: sameDayKey, now: now), [arc])
        XCTAssertEqual(DailyProgressLogic.rollover(storedArcs: [arc], storedDayKey: "1999-1-1", now: now), [])
        XCTAssertEqual(DailyProgressLogic.rollover(storedArcs: [arc], storedDayKey: nil, now: now), [])
    }
}
