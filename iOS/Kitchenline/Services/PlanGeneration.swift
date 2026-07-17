import Foundation

/// Pure, deterministic fallback generation — used whenever the AI proxy is
/// unreachable or returns something that doesn't parse. Never touches the
/// network, so it is fully unit-testable and always succeeds.
enum FallbackPlanner {
    static let dayLabels = ["Day 1", "Day 2", "Day 3", "Day 4"]

    static func generate(weakShots: [WeakShotTag], minutesAvailable: Int) -> PracticePlan {
        let minutes = max(10, minutesAvailable)
        let shots = weakShots.isEmpty ? Array(WeakShotTag.allCases.prefix(4)) : weakShots

        var days: [PracticePlanDay] = []
        for (index, label) in dayLabels.enumerated() {
            let shot = shots[index % shots.count]
            let drills = Array(shot.recommendedDrillIDs.prefix(2)).compactMap { DrillLibrary.drill(id: $0) }
            guard !drills.isEmpty else { continue }
            let reps = repsPerDrill(minutes: minutes, drillCount: drills.count)
            let planned = drills.map { PlannedDrill(drillName: $0.name, reps: reps) }
            days.append(PracticePlanDay(day: label, focus: shot.rawValue, minutes: minutes, drills: planned))
        }
        return PracticePlan(days: days)
    }

    /// ~2 reps/minute (each rep, including the reset between reps, runs
    /// roughly 25-30 seconds), split evenly across that day's drills and
    /// clamped to a sane range.
    static func repsPerDrill(minutes: Int, drillCount: Int) -> Int {
        guard drillCount > 0 else { return 0 }
        let totalReps = minutes * 2
        let perDrill = totalReps / drillCount
        return min(max(perDrill, 6), 30)
    }

    /// A hand-written opponent path shaped by the drill's own category —
    /// roughly mirrors the drill's own ball flight back at the player, since a
    /// real opponent would be returning from near where the drilled ball lands.
    static func ghostWaypoints(for drill: Drill) -> [GhostWaypoint] {
        let mirroredOrigin = CourtGeometry.mirrored(drill.target)
        let mirroredTarget = CourtGeometry.mirrored(drill.origin)
        let midX = (mirroredOrigin.x + mirroredTarget.x) / 2

        switch drill.category {
        case .dinking:
            return [
                GhostWaypoint(time: 0.0, x: mirroredOrigin.x, y: mirroredOrigin.y),
                GhostWaypoint(time: 0.6, x: midX, y: CourtGeometry.netY - 3),
                GhostWaypoint(time: 1.2, x: mirroredTarget.x, y: mirroredTarget.y),
            ]
        case .thirdShotDrop:
            return [
                GhostWaypoint(time: 0.0, x: mirroredOrigin.x, y: CourtGeometry.nearKitchenY - 5),
                GhostWaypoint(time: 0.7, x: midX, y: CourtGeometry.nearKitchenY),
                GhostWaypoint(time: 1.4, x: mirroredTarget.x, y: CourtGeometry.nearKitchenY + 3),
            ]
        case .serveReturn:
            return [
                GhostWaypoint(time: 0.0, x: mirroredOrigin.x, y: mirroredOrigin.y),
                GhostWaypoint(time: 0.5, x: midX, y: CourtGeometry.netY - 2),
                GhostWaypoint(time: 1.0, x: mirroredTarget.x, y: mirroredTarget.y),
            ]
        case .footwork:
            return [
                GhostWaypoint(time: 0.0, x: mirroredOrigin.x, y: mirroredOrigin.y),
                GhostWaypoint(time: 1.0, x: mirroredTarget.x, y: mirroredTarget.y),
            ]
        }
    }
}

/// Shared "find the JSON inside the model's prose" helper — the proxy returns
/// a plain string, and models occasionally wrap JSON in a sentence or code
/// fence even when told not to.
enum AIJSONExtractor {
    static func extractObject(from content: String) -> String? {
        guard let start = content.firstIndex(of: "{"), let end = content.lastIndex(of: "}"), start < end else { return nil }
        return String(content[start...end])
    }

    static func extractArray(from content: String) -> String? {
        guard let start = content.firstIndex(of: "["), let end = content.lastIndex(of: "]"), start < end else { return nil }
        return String(content[start...end])
    }
}

/// Lenient parser for the AI's weekly-plan JSON-in-text response. Any drill
/// name that doesn't fuzzy-match the bundled library is dropped rather than
/// failing the whole plan; a day with no valid drills left is dropped too.
enum PracticePlanParser {
    private struct RawDrill: Decodable { let drillName: String?; let reps: Int? }
    private struct RawDay: Decodable { let day: String?; let focus: String?; let minutes: Int?; let drills: [RawDrill]? }
    private struct RawPlan: Decodable { let days: [RawDay]? }

    static func parse(_ text: String, library: [Drill] = DrillLibrary.all) -> PracticePlan? {
        guard let jsonSlice = AIJSONExtractor.extractObject(from: text),
              let data = jsonSlice.data(using: .utf8),
              let raw = try? JSONDecoder().decode(RawPlan.self, from: data),
              let rawDays = raw.days, !rawDays.isEmpty
        else { return nil }

        var days: [PracticePlanDay] = []
        for rawDay in rawDays {
            guard let rawDrills = rawDay.drills, !rawDrills.isEmpty else { continue }
            var planned: [PlannedDrill] = []
            for rawDrill in rawDrills {
                guard let name = rawDrill.drillName, let matched = DrillLibrary.drill(named: name) else { continue }
                let reps = min(max(rawDrill.reps ?? matched.defaultReps, 4), 40)
                planned.append(PlannedDrill(drillName: matched.name, reps: reps))
            }
            guard !planned.isEmpty else { continue }
            let label = (rawDay.day?.isEmpty == false) ? rawDay.day! : "Day \(days.count + 1)"
            let focus = (rawDay.focus?.isEmpty == false) ? rawDay.focus! : "Mixed practice"
            let minutes = min(max(rawDay.minutes ?? 30, 5), 180)
            days.append(PracticePlanDay(day: label, focus: focus, minutes: minutes, drills: planned))
        }
        guard !days.isEmpty else { return nil }
        return PracticePlan(days: days)
    }
}

/// Lenient parser for the AI's ghost-rally waypoint JSON-in-text response.
/// Waypoints outside court bounds, with a negative time, or malformed are
/// dropped; the result is sorted and capped so a runaway response can't
/// produce an absurd animation.
enum GhostRallyParser {
    private struct RawWaypoint: Decodable { let time: Double?; let courtX: Double?; let courtY: Double? }

    static func parse(_ text: String) -> [GhostWaypoint]? {
        guard let jsonSlice = AIJSONExtractor.extractArray(from: text),
              let data = jsonSlice.data(using: .utf8),
              let raw = try? JSONDecoder().decode([RawWaypoint].self, from: data)
        else { return nil }

        let waypoints = raw
            .compactMap { w -> GhostWaypoint? in
                guard let time = w.time, let x = w.courtX, let y = w.courtY,
                      time >= 0,
                      (0...CourtGeometry.widthFeet).contains(x),
                      (0...CourtGeometry.lengthFeet).contains(y)
                else { return nil }
                return GhostWaypoint(time: time, x: x, y: y)
            }
            .sorted { $0.time < $1.time }

        let capped = Array(waypoints.prefix(12))
        return capped.count >= 2 ? capped : nil
    }
}
