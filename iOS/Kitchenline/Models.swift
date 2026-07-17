import Foundation
import CoreGraphics

// MARK: - Court geometry

/// A regulation pickleball court is 20ft (sideline-to-sideline) by 44ft
/// (baseline-to-baseline), with the net at the 22ft midline and the non-volley
/// zone ("the kitchen") extending 7ft from the net on each side. Every court
/// position in Kitchenline is expressed in these real-world feet, then mapped
/// into view-space by whichever `CourtDiagramView` is drawing it.
enum CourtGeometry {
    static let widthFeet: Double = 20
    static let lengthFeet: Double = 44
    static let kitchenDepthFeet: Double = 7

    static let netY: Double = lengthFeet / 2 // 22
    static let nearKitchenY: Double = netY - kitchenDepthFeet // 15 (opponent side)
    static let farKitchenY: Double = netY + kitchenDepthFeet // 29 (user side)

    /// Maps a court point (feet) into a drawing rect's local coordinate space.
    static func viewPoint(for court: CourtPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: CGFloat(court.x / widthFeet) * size.width,
            y: CGFloat(court.y / lengthFeet) * size.height
        )
    }

    /// Mirrors a court point across the center line (x-axis flip) — used to
    /// alternate cross-court drill reps left/right instead of repeating the
    /// identical path every time.
    static func mirrored(_ point: CourtPoint) -> CourtPoint {
        CourtPoint(x: widthFeet - point.x, y: point.y)
    }
}

/// A single position on the court, in feet. `x` runs sideline-to-sideline
/// (0...20), `y` runs baseline-to-baseline (0...44).
struct CourtPoint: Codable, Equatable, Hashable {
    var x: Double
    var y: Double

    static func clamped(x: Double, y: Double) -> CourtPoint {
        CourtPoint(
            x: min(max(x, 0), CourtGeometry.widthFeet),
            y: min(max(y, 0), CourtGeometry.lengthFeet)
        )
    }
}

// MARK: - Drills

enum DrillCategory: String, CaseIterable, Identifiable, Codable {
    case dinking = "Dinking"
    case thirdShotDrop = "Third Shot Drop"
    case serveReturn = "Serve & Return"
    case footwork = "Footwork"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dinking: return "circle.dashed"
        case .thirdShotDrop: return "arrow.down.forward.circle"
        case .serveReturn: return "arrow.up.forward.circle"
        case .footwork: return "figure.run"
        }
    }

    var blurb: String {
        switch self {
        case .dinking: return "Soft-game control at the net."
        case .thirdShotDrop: return "The transition shot into the kitchen."
        case .serveReturn: return "Starting the point on your terms."
        case .footwork: return "Positioning that makes every shot easier."
        }
    }
}

enum DrillDifficulty: String, CaseIterable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

/// A single named, real pickleball drill. `origin`/`target` describe the ball's
/// flight for one rep of the animated court diagram; `mirrorsEachRep` flips
/// them left/right on alternating reps so a repeated drill still looks (and
/// plays) like a real alternating drill instead of one static shot replayed.
struct Drill: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let category: DrillCategory
    let difficulty: DrillDifficulty
    let summary: String
    let cues: [String]
    let defaultReps: Int
    let origin: CourtPoint
    let target: CourtPoint
    let mirrorsEachRep: Bool

    /// Origin/target for a given rep index (0-based), applying the mirror flip
    /// on odd reps when `mirrorsEachRep` is true.
    func path(forRep repIndex: Int) -> (origin: CourtPoint, target: CourtPoint) {
        guard mirrorsEachRep, repIndex % 2 == 1 else { return (origin, target) }
        return (CourtGeometry.mirrored(origin), CourtGeometry.mirrored(target))
    }
}

enum DrillLibrary {
    static let all: [Drill] = [
        // MARK: Dinking
        Drill(
            id: "cross-court-dinking",
            name: "Cross-Court Dinking",
            category: .dinking,
            difficulty: .beginner,
            summary: "Soft, arcing dinks hit diagonally cross-court, landing shallow in the kitchen.",
            cues: [
                "Paddle low, ball low — clear the net by inches, not feet.",
                "Aim for the diagonal, not straight ahead: it gives you the longest court to work with.",
                "Bend your knees to get under the ball rather than reaching with your arm.",
            ],
            defaultReps: 15,
            origin: CourtPoint(x: 5, y: 30), target: CourtPoint(x: 15, y: 18),
            mirrorsEachRep: true
        ),
        Drill(
            id: "straight-on-dinking",
            name: "Straight-On Dinking",
            category: .dinking,
            difficulty: .beginner,
            summary: "Dinking straight ahead down the same lane, building a consistent soft-hands rally.",
            cues: [
                "Same target every time — this drill is about consistency, not variety.",
                "Keep the paddle face open and let the ball come to you.",
                "A rally that dies in the net means you're hitting down, not through.",
            ],
            defaultReps: 15,
            origin: CourtPoint(x: 5, y: 29), target: CourtPoint(x: 5, y: 17),
            mirrorsEachRep: true
        ),
        Drill(
            id: "dink-volley-rally",
            name: "Dink Volley Rally",
            category: .dinking,
            difficulty: .intermediate,
            summary: "Both players stay at the kitchen line and volley dinks out of the air — no bounce allowed.",
            cues: [
                "Stay tall and ready at the line; don't drift backward between shots.",
                "Short backswing — a volley dink is a punch, not a stroke.",
                "The rally ends the moment either player lets the ball bounce.",
            ],
            defaultReps: 20,
            origin: CourtPoint(x: 8, y: 29), target: CourtPoint(x: 12, y: 17),
            mirrorsEachRep: true
        ),
        Drill(
            id: "dink-target-zones",
            name: "Dink Target Zones",
            category: .dinking,
            difficulty: .intermediate,
            summary: "Aiming dinks at the sideline corners of the kitchen instead of the safe middle.",
            cues: [
                "Corners force a weaker reply — the middle just restarts the rally.",
                "Widen your target gradually; don't chase corners before the rally is stable.",
                "A dink that lands past the kitchen line on the fly is out — control matters more than power here.",
            ],
            defaultReps: 15,
            origin: CourtPoint(x: 10, y: 28), target: CourtPoint(x: 2, y: 16),
            mirrorsEachRep: true
        ),
        Drill(
            id: "erne-fake-drill",
            name: "Erne Fake Drill",
            category: .dinking,
            difficulty: .advanced,
            summary: "Faking a wide erne move around the kitchen, then resetting back into dink position.",
            cues: [
                "Sell the fake with your first step before recovering — a half-hearted fake teaches nothing.",
                "Never let your foot land inside the kitchen while the ball is in play.",
                "Recover to a ready dink stance the instant the fake is read.",
            ],
            defaultReps: 12,
            origin: CourtPoint(x: 2, y: 30), target: CourtPoint(x: 18, y: 16),
            mirrorsEachRep: true
        ),
        Drill(
            id: "around-the-post",
            name: "Around-the-Post (ATP)",
            category: .dinking,
            difficulty: .advanced,
            summary: "The trick shot for a ball that bounces wide of the sideline: hit it around the net post, below net height, without it touching the net.",
            cues: [
                "The ball must stay below the top of the net the entire flight — going over doesn't count.",
                "Commit fully once you've decided to go for it; a half-swing usually nets the ball.",
                "Only attempt this when the bounce is genuinely outside the sideline.",
            ],
            defaultReps: 10,
            origin: CourtPoint(x: 0.5, y: 34), target: CourtPoint(x: 0.5, y: 8),
            mirrorsEachRep: true
        ),

        // MARK: Third Shot Drop
        Drill(
            id: "third-shot-drop-baseline",
            name: "Third Shot Drop from Baseline",
            category: .thirdShotDrop,
            difficulty: .intermediate,
            summary: "The classic soft arcing shot from the baseline that lands in the opponent's kitchen, turning your team from defense to the net.",
            cues: [
                "Low-to-high paddle path with soft hands — this is a lob, not a drive.",
                "Aim for the shot to land in the kitchen, not just clear the net.",
                "Start moving forward the instant you make contact, not after you see where it lands.",
            ],
            defaultReps: 12,
            origin: CourtPoint(x: 10, y: 42), target: CourtPoint(x: 10, y: 18),
            mirrorsEachRep: true
        ),
        Drill(
            id: "drop-and-move",
            name: "Drop-and-Move",
            category: .thirdShotDrop,
            difficulty: .intermediate,
            summary: "Hit a third shot drop, then immediately advance toward your own kitchen line before the next ball arrives.",
            cues: [
                "The drop buys you time — spend it closing the distance, not admiring the shot.",
                "Split-step just before your opponent makes contact on the next shot.",
                "Arrive at the kitchen line, don't drift past your split-step timing.",
            ],
            defaultReps: 12,
            origin: CourtPoint(x: 12, y: 40), target: CourtPoint(x: 8, y: 17),
            mirrorsEachRep: true
        ),
        Drill(
            id: "two-ball-third-shot",
            name: "Two-Ball Third Shot",
            category: .thirdShotDrop,
            difficulty: .advanced,
            summary: "A feeder returns your first drop; you must drop a second consecutive ball, rehearsing soft hands under pressure.",
            cues: [
                "The second drop is harder because you're already moving forward — stay low.",
                "If the first drop is weak, the second one has to bail you out — don't panic-drive it.",
                "Reset your grip pressure between the two shots; tension creeps in under pressure.",
            ],
            defaultReps: 10,
            origin: CourtPoint(x: 9, y: 38), target: CourtPoint(x: 11, y: 19),
            mirrorsEachRep: true
        ),
        Drill(
            id: "reset-drill",
            name: "Reset Drill",
            category: .thirdShotDrop,
            difficulty: .advanced,
            summary: "A feeder hits hard, fast balls at you from mid-court; you must absorb the pace and drop a soft reset into the kitchen.",
            cues: [
                "Loosen your grip on contact — a firm grip sends the pace right back.",
                "Let the paddle absorb the ball's speed rather than swinging at it.",
                "A reset that lands mid-court instead of the kitchen just restarts the attack against you.",
            ],
            defaultReps: 12,
            origin: CourtPoint(x: 10, y: 36), target: CourtPoint(x: 10, y: 20),
            mirrorsEachRep: true
        ),

        // MARK: Serve & Return
        Drill(
            id: "deep-serve-placement",
            name: "Deep Serve Placement",
            category: .serveReturn,
            difficulty: .beginner,
            summary: "Serving deep into the back third of the service box to push the returner off the baseline.",
            cues: [
                "A deep serve buys your team time to get to the kitchen line before the return arrives.",
                "Toss consistency matters more than swing speed for placement.",
                "Vary which side of the box you target so the return isn't predictable.",
            ],
            defaultReps: 12,
            origin: CourtPoint(x: 4, y: 44), target: CourtPoint(x: 16, y: 4),
            mirrorsEachRep: true
        ),
        Drill(
            id: "return-deep-move-in",
            name: "Return Deep and Move In",
            category: .serveReturn,
            difficulty: .intermediate,
            summary: "Returning serve deep toward the server's baseline, then immediately advancing toward the kitchen line.",
            cues: [
                "A deep return pins the serving team back — a short return invites an easy attack.",
                "Start your approach the instant you make contact; don't watch the ball land.",
                "Aim for depth over pace — a return that sails long is worse than one that's slightly short.",
            ],
            defaultReps: 12,
            origin: CourtPoint(x: 16, y: 2), target: CourtPoint(x: 4, y: 42),
            mirrorsEachRep: true
        ),
        Drill(
            id: "serve-return-split-step",
            name: "Serve-Return-Split Step",
            category: .serveReturn,
            difficulty: .intermediate,
            summary: "Serving or returning, then timing a split-step at the transition line right as the next shot is struck.",
            cues: [
                "The split-step should land the instant your opponent's paddle touches the ball, not before or after.",
                "A flat-footed player is always a step late — stay light on your feet.",
                "This timing is what makes the third shot drop actually reachable.",
            ],
            defaultReps: 12,
            origin: CourtPoint(x: 4, y: 44), target: CourtPoint(x: 16, y: 3),
            mirrorsEachRep: true
        ),
        Drill(
            id: "body-bag-serve",
            name: "Body Bag Serve",
            category: .serveReturn,
            difficulty: .advanced,
            summary: "Serving directly at the returner's body to jam their swing and force a weak, blocked return.",
            cues: [
                "Target the hip or the chest — jammed arms can't generate a clean swing.",
                "This is a tactical placement drill, not a power drill; disguise matters more than pace.",
                "Use it to break a returner's rhythm, not on every single serve.",
            ],
            defaultReps: 10,
            origin: CourtPoint(x: 10, y: 44), target: CourtPoint(x: 9, y: 5),
            mirrorsEachRep: true
        ),

        // MARK: Footwork
        Drill(
            id: "split-step-ladder",
            name: "Split Step Ladder",
            category: .footwork,
            difficulty: .beginner,
            summary: "A sequence of timed split-steps advancing toward the kitchen line, syncing footwork to an opponent's contact moment.",
            cues: [
                "Small, quick hops — a split-step is a reset, not a jump.",
                "Land with your weight balanced on both feet, ready to push in any direction.",
                "Each split-step should bring you one step closer to the kitchen line.",
            ],
            defaultReps: 15,
            origin: CourtPoint(x: 10, y: 40), target: CourtPoint(x: 10, y: 24),
            mirrorsEachRep: false
        ),
        Drill(
            id: "side-shuffle-kitchen-line",
            name: "Side Shuffle to Kitchen Line",
            category: .footwork,
            difficulty: .beginner,
            summary: "Shuffling laterally through the transition zone into ready position at the kitchen line, feet never crossing.",
            cues: [
                "Feet stay parallel — a crossover step here leaves you off balance.",
                "Keep your paddle up throughout the shuffle; don't let it drop to your side.",
                "Arrive at the line already balanced, not still decelerating.",
            ],
            defaultReps: 15,
            origin: CourtPoint(x: 4, y: 32), target: CourtPoint(x: 16, y: 17),
            mirrorsEachRep: true
        ),
        Drill(
            id: "crossover-recovery-step",
            name: "Crossover Recovery Step",
            category: .footwork,
            difficulty: .intermediate,
            summary: "Recovering to center court with a crossover step after being pulled wide, then re-splitting before the next shot.",
            cues: [
                "The crossover step covers ground fast — use it only when a shuffle can't get there in time.",
                "Recover toward the middle of your side's coverage, not all the way back to center court.",
                "Re-split the instant you arrive; recovering into a standstill defeats the purpose.",
            ],
            defaultReps: 12,
            origin: CourtPoint(x: 2, y: 26), target: CourtPoint(x: 18, y: 20),
            mirrorsEachRep: true
        ),
        Drill(
            id: "transition-zone-sprint",
            name: "Transition Zone Sprint",
            category: .footwork,
            difficulty: .intermediate,
            summary: "Advancing quickly from the baseline through the no-man's-land transition zone to the kitchen line after a deep return.",
            cues: [
                "Sprint the middle of the transition zone, then decelerate into a split-step before the kitchen line.",
                "Getting caught mid-transition when the ball arrives is the single most common unforced error at this level.",
                "Depth on your own shot buys you the time this sprint needs.",
            ],
            defaultReps: 12,
            origin: CourtPoint(x: 10, y: 42), target: CourtPoint(x: 10, y: 16),
            mirrorsEachRep: false
        ),
    ]

    static func drill(id: String) -> Drill? { all.first { $0.id == id } }

    static func drill(named name: String) -> Drill? {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all.first { $0.name.lowercased() == needle }
            ?? all.first { $0.name.lowercased().contains(needle) || needle.contains($0.name.lowercased()) }
    }

    static func drills(in category: DrillCategory) -> [Drill] {
        all.filter { $0.category == category }
    }
}

// MARK: - Self-rated weak shots (also used as tags for the AI weekly plan)

enum WeakShotTag: String, CaseIterable, Identifiable, Codable {
    case backhandDink = "Backhand Dink"
    case forehandDink = "Forehand Dink"
    case thirdShotDrop = "Third Shot Drop"
    case resets = "Resets"
    case serveDepth = "Serve Depth"
    case returnDepth = "Return Depth"
    case splitStepTiming = "Split-Step Timing"
    case transitionFootwork = "Transition Footwork"
    case erneAndATP = "Erne / ATP Shots"

    var id: String { rawValue }

    /// Drills recommended for this weak shot, used both as the fallback plan's
    /// source of truth and as grounding context in the AI prompt.
    var recommendedDrillIDs: [String] {
        switch self {
        case .backhandDink: return ["cross-court-dinking", "straight-on-dinking", "dink-target-zones"]
        case .forehandDink: return ["straight-on-dinking", "dink-volley-rally", "dink-target-zones"]
        case .thirdShotDrop: return ["third-shot-drop-baseline", "drop-and-move", "two-ball-third-shot"]
        case .resets: return ["reset-drill", "two-ball-third-shot"]
        case .serveDepth: return ["deep-serve-placement", "body-bag-serve"]
        case .returnDepth: return ["return-deep-move-in", "serve-return-split-step"]
        case .splitStepTiming: return ["split-step-ladder", "serve-return-split-step"]
        case .transitionFootwork: return ["transition-zone-sprint", "side-shuffle-kitchen-line", "crossover-recovery-step"]
        case .erneAndATP: return ["erne-fake-drill", "around-the-post"]
        }
    }
}

// MARK: - AI weekly practice plan

struct PlannedDrill: Codable, Equatable {
    var drillName: String
    var reps: Int
}

struct PracticePlanDay: Codable, Equatable {
    var day: String
    var focus: String
    var minutes: Int
    var drills: [PlannedDrill]
}

struct PracticePlan: Codable, Equatable {
    var days: [PracticePlanDay]
}

// MARK: - Ghost-rally (Pro)

/// One waypoint of the AI-generated "opponent" dot for ghost-rally mode. `time`
/// is seconds from the start of the rep; `x`/`y` are court feet, matching
/// `CourtPoint`. Rendered as a labeled dot, never a photo/video opponent.
struct GhostWaypoint: Codable, Equatable {
    var time: Double
    var x: Double
    var y: Double

    var courtPoint: CourtPoint { CourtPoint(x: x, y: y) }
}

// MARK: - Progress tracking

/// One completed ("in") rep, recorded permanently onto the daily progress
/// court diagram as a bright, locked arc.
struct LockedArc: Codable, Equatable {
    var origin: CourtPoint
    var target: CourtPoint
    var categoryRaw: String
    var timestamp: Date

    var category: DrillCategory? { DrillCategory(rawValue: categoryRaw) }
}

enum DailyProgressLogic {
    /// Locked arcs only survive to "today" — the tracker is a daily court, not
    /// a lifetime one. Returns the arcs that should still be shown given the
    /// last-saved date.
    static func rollover(storedArcs: [LockedArc], storedDayKey: String?, now: Date, calendar: Calendar = .current) -> [LockedArc] {
        guard let storedDayKey, storedDayKey == dayKey(for: now, calendar: calendar) else { return [] }
        return storedArcs
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }
}
