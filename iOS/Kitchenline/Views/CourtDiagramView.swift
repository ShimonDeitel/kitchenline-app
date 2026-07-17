import SwiftUI

/// Describes one in-flight rep animation: the ball's court-space flight from
/// `origin` to `target`, timed from `startDate` over `duration` seconds, with
/// an optional ghost-rally opponent sequence to animate alongside it.
struct ActiveRepAnimation: Equatable {
    var origin: CourtPoint
    var target: CourtPoint
    var startDate: Date
    var duration: Double
    var ghostWaypoints: [GhostWaypoint] = []
}

/// The live top-down court schematic: bold painted court lines (baseline,
/// sidelines, net, kitchen/non-volley-zone lines) drawn with `Canvas`, plus
/// two optional overlays — permanently "locked" bright arcs from completed
/// reps, and a `TimelineView`-driven animated ball (with a glowing fading
/// trail) for the rep currently in flight, with an optional AI ghost-rally
/// opponent dot moving alongside it.
struct CourtDiagramView: View {
    var lockedArcs: [LockedArc] = []
    var activeRep: ActiveRepAnimation? = nil
    var showGhost: Bool = false
    var compact: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CourtSurfaceCanvas(compact: compact)
                if !lockedArcs.isEmpty {
                    LockedArcsCanvas(arcs: lockedArcs)
                }
                if let activeRep {
                    TimelineView(.animation) { timeline in
                        RepAnimationCanvas(rep: activeRep, now: timeline.date, showGhost: showGhost)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(CGFloat(CourtGeometry.widthFeet / CourtGeometry.lengthFeet), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 10 : 16, style: .continuous)
                .strokeBorder(KLColor.courtSurfaceEdge, lineWidth: 2)
        )
    }
}

/// Static court paint — surface fill, kitchen tint band, and the literal
/// straight-line geometry (baselines, sidelines, net, kitchen lines, and the
/// center service line on each half). Redrawn only when the view's inputs
/// change, never per-animation-frame.
private struct CourtSurfaceCanvas: View {
    let compact: Bool

    var body: some View {
        Canvas { context, size in
            let lineWidth: CGFloat = compact ? 1.5 : 3.5
            let rect = CGRect(origin: .zero, size: size)

            context.fill(Path(rect), with: .color(KLColor.courtSurface))

            let nearKY = CGFloat(CourtGeometry.nearKitchenY / CourtGeometry.lengthFeet) * size.height
            let farKY = CGFloat(CourtGeometry.farKitchenY / CourtGeometry.lengthFeet) * size.height
            let netY = CGFloat(CourtGeometry.netY / CourtGeometry.lengthFeet) * size.height

            let kitchenRect = CGRect(x: 0, y: nearKY, width: size.width, height: farKY - nearKY)
            context.fill(Path(kitchenRect), with: .color(KLColor.kitchenTint.opacity(0.55)))

            // Outer border: sidelines + baselines.
            context.stroke(Path(rect), with: .color(KLColor.courtLine), lineWidth: lineWidth)

            // Kitchen (non-volley-zone) lines.
            for y in [nearKY, farKY] {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(KLColor.courtLine), lineWidth: lineWidth)
            }

            // Center service line, each half only (never crosses the kitchen).
            let midX = size.width / 2
            var centerNear = Path()
            centerNear.move(to: CGPoint(x: midX, y: 0))
            centerNear.addLine(to: CGPoint(x: midX, y: nearKY))
            context.stroke(centerNear, with: .color(KLColor.courtLine.opacity(0.85)), lineWidth: lineWidth * 0.65)

            var centerFar = Path()
            centerFar.move(to: CGPoint(x: midX, y: farKY))
            centerFar.addLine(to: CGPoint(x: midX, y: size.height))
            context.stroke(centerFar, with: .color(KLColor.courtLine.opacity(0.85)), lineWidth: lineWidth * 0.65)

            // Net — thicker, dashed.
            var net = Path()
            net.move(to: CGPoint(x: 0, y: netY))
            net.addLine(to: CGPoint(x: size.width, y: netY))
            let dash: [CGFloat] = compact ? [] : [7, 5]
            context.stroke(net, with: .color(KLColor.net), style: StrokeStyle(lineWidth: lineWidth * 1.7, lineCap: .butt, dash: dash))
        }
    }
}

/// Permanently locked arcs from completed ("in") reps — each drawn as a
/// citrus line with a soft blurred glow behind it, from that rep's origin to
/// its target.
private struct LockedArcsCanvas: View {
    let arcs: [LockedArc]

    var body: some View {
        Canvas { context, size in
            for arc in arcs {
                let p0 = CourtGeometry.viewPoint(for: arc.origin, in: size)
                let p1 = CourtGeometry.viewPoint(for: arc.target, in: size)
                var path = Path()
                path.move(to: p0)
                path.addLine(to: p1)

                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 3))
                    layer.stroke(path, with: .color(KLColor.citrus.opacity(0.55)), lineWidth: 5)
                }
                context.stroke(path, with: .color(KLColor.citrus), lineWidth: 2.25)
                let dot = CGRect(x: p1.x - 3, y: p1.y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: dot), with: .color(KLColor.citrus))
            }
        }
    }
}

/// The moving parts, redrawn every frame by the parent's `TimelineView`: the
/// ball's glowing fading trail along its rep flight, and (if enabled) the
/// AI ghost-rally opponent dot.
private struct RepAnimationCanvas: View {
    let rep: ActiveRepAnimation
    let now: Date
    let showGhost: Bool

    private var elapsed: Double { max(0, now.timeIntervalSince(rep.startDate)) }

    var body: some View {
        Canvas { context, size in
            let progress = min(1, elapsed / rep.duration)
            let eased = Self.easeInOutQuad(progress)
            let ballPoint = CourtGeometry.viewPoint(for: Self.lerp(rep.origin, rep.target, eased), in: size)

            // Soft glow halo behind the ball at its current position.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 7))
                let glowRadius: CGFloat = 13
                let glowRect = CGRect(x: ballPoint.x - glowRadius, y: ballPoint.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
                layer.fill(Path(ellipseIn: glowRect), with: .color(KLColor.citrus.opacity(0.65)))
            }

            // Fading trail: several successively-more-transparent copies of
            // the ball's recent positions, sampled backward in time.
            let trailCount = 7
            let trailStep = 0.045
            for k in stride(from: trailCount - 1, through: 0, by: -1) {
                let t = elapsed - Double(k) * trailStep
                guard t >= 0 else { continue }
                let sampleProgress = min(1, t / rep.duration)
                let sampleEased = Self.easeInOutQuad(sampleProgress)
                let point = CourtGeometry.viewPoint(for: Self.lerp(rep.origin, rep.target, sampleEased), in: size)
                let opacity = k == 0 ? 1.0 : max(0, 0.6 - Double(k) * 0.085)
                let radius: CGFloat = k == 0 ? 7 : max(2, 7 - CGFloat(k) * 0.8)
                let ballRect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: ballRect), with: .color(KLColor.citrus.opacity(opacity)))
            }

            if showGhost, rep.ghostWaypoints.count >= 2 {
                let ghostCourtPoint = Self.ghostPosition(at: elapsed, waypoints: rep.ghostWaypoints)
                let ghostViewPoint = CourtGeometry.viewPoint(for: ghostCourtPoint, in: size)
                let radius: CGFloat = 8
                let ghostRect = CGRect(x: ghostViewPoint.x - radius, y: ghostViewPoint.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: ghostRect), with: .color(KLColor.net.opacity(0.88)))
                context.stroke(Path(ellipseIn: ghostRect), with: .color(.white), lineWidth: 1.5)
                let label = context.resolve(Text("OPP").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(.white))
                context.draw(label, at: CGPoint(x: ghostViewPoint.x, y: ghostViewPoint.y - radius - 8))
            }
        }
    }

    static func easeInOutQuad(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    static func lerp(_ a: CourtPoint, _ b: CourtPoint, _ t: Double) -> CourtPoint {
        CourtPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    /// Piecewise-linear interpolation across the waypoint sequence — holds at
    /// the first point before it starts and the last point once it's done.
    static func ghostPosition(at elapsed: Double, waypoints: [GhostWaypoint]) -> CourtPoint {
        guard let first = waypoints.first else { return CourtPoint(x: 10, y: 22) }
        guard elapsed > first.time else { return first.courtPoint }
        guard let last = waypoints.last, elapsed < last.time else { return waypoints.last?.courtPoint ?? first.courtPoint }
        for i in 0..<(waypoints.count - 1) {
            let a = waypoints[i], b = waypoints[i + 1]
            if elapsed >= a.time, elapsed <= b.time {
                let span = b.time - a.time
                let t = span > 0 ? (elapsed - a.time) / span : 0
                return lerp(a.courtPoint, b.courtPoint, t)
            }
        }
        return first.courtPoint
    }
}
