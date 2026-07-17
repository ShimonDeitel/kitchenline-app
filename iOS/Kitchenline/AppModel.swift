import Foundation
import SwiftUI

/// App state: self-rated skill levels, the weak-shot picker used for the AI
/// weekly plan, today's practice minutes, the daily progress tracker's locked
/// arcs, and the last AI-fetched practice plan — all persisted to
/// `UserDefaults` as small JSON blobs (no server, no account, nothing shared
/// off-device).
@MainActor
final class AppModel: ObservableObject {
    @Published var skillRatings: [String: Int] {
        didSet { saveJSON(skillRatings, forKey: Keys.skillRatings) }
    }
    @Published var selectedWeakShots: Set<String> {
        didSet { saveJSON(Array(selectedWeakShots), forKey: Keys.weakShots) }
    }
    @Published var minutesAvailable: Int {
        didSet { defaults.set(minutesAvailable, forKey: Keys.minutesAvailable) }
    }
    @Published private(set) var lockedArcsToday: [LockedArc] {
        didSet { saveJSON(lockedArcsToday, forKey: Keys.lockedArcs) }
    }
    @Published var cachedPlan: PracticePlan? {
        didSet { saveJSON(cachedPlan, forKey: Keys.cachedPlan) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let skillRatings = "kitchenline.skillRatings"
        static let weakShots = "kitchenline.weakShots"
        static let minutesAvailable = "kitchenline.minutesAvailable"
        static let lockedArcs = "kitchenline.lockedArcsToday"
        static let lockedArcsDayKey = "kitchenline.lockedArcsDayKey"
        static let cachedPlan = "kitchenline.cachedPlan"
    }

    init() {
        let d = UserDefaults.standard
        _skillRatings = Published(initialValue: Self.loadJSON([String: Int].self, forKey: Keys.skillRatings, from: d) ?? [:])
        _selectedWeakShots = Published(initialValue: Set(Self.loadJSON([String].self, forKey: Keys.weakShots, from: d) ?? []))
        let storedMinutes = d.integer(forKey: Keys.minutesAvailable)
        _minutesAvailable = Published(initialValue: storedMinutes > 0 ? storedMinutes : 30)
        _cachedPlan = Published(initialValue: Self.loadJSON(PracticePlan.self, forKey: Keys.cachedPlan, from: d))

        let storedArcs = Self.loadJSON([LockedArc].self, forKey: Keys.lockedArcs, from: d) ?? []
        let storedDayKey = d.string(forKey: Keys.lockedArcsDayKey)
        let rolledOver = DailyProgressLogic.rollover(storedArcs: storedArcs, storedDayKey: storedDayKey, now: Date())
        _lockedArcsToday = Published(initialValue: rolledOver)
        d.set(DailyProgressLogic.dayKey(for: Date()), forKey: Keys.lockedArcsDayKey)
    }

    // MARK: Skill ratings

    func rating(for category: DrillCategory) -> Int {
        skillRatings[category.rawValue] ?? 3
    }

    func setRating(_ value: Int, for category: DrillCategory) {
        skillRatings[category.rawValue] = min(max(value, 1), 5)
    }

    // MARK: Weak shots

    func isWeakShotSelected(_ tag: WeakShotTag) -> Bool { selectedWeakShots.contains(tag.rawValue) }

    func toggleWeakShot(_ tag: WeakShotTag) {
        if selectedWeakShots.contains(tag.rawValue) {
            selectedWeakShots.remove(tag.rawValue)
        } else {
            selectedWeakShots.insert(tag.rawValue)
        }
    }

    var orderedSelectedWeakShots: [WeakShotTag] {
        WeakShotTag.allCases.filter { selectedWeakShots.contains($0.rawValue) }
    }

    // MARK: Daily progress

    /// Re-checks the stored day key and clears `lockedArcsToday` if the
    /// calendar day has rolled over since the app last ran or was foregrounded.
    func refreshDayRolloverIfNeeded(now: Date = Date()) {
        let key = DailyProgressLogic.dayKey(for: now)
        if defaults.string(forKey: Keys.lockedArcsDayKey) != key {
            lockedArcsToday = []
            defaults.set(key, forKey: Keys.lockedArcsDayKey)
        }
    }

    func recordRep(category: DrillCategory, origin: CourtPoint, target: CourtPoint) {
        refreshDayRolloverIfNeeded()
        lockedArcsToday.append(LockedArc(origin: origin, target: target, categoryRaw: category.rawValue, timestamp: Date()))
    }

    var repsCompletedToday: Int { lockedArcsToday.count }

    var categoriesPracticedToday: Set<DrillCategory> {
        Set(lockedArcsToday.compactMap { $0.category })
    }

    // MARK: Data management

    func deleteAllData() {
        skillRatings = [:]
        selectedWeakShots = []
        minutesAvailable = 30
        lockedArcsToday = []
        cachedPlan = nil
        defaults.removeObject(forKey: Keys.lockedArcsDayKey)
    }

    // MARK: JSON persistence helpers

    private func saveJSON<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func loadJSON<T: Decodable>(_ type: T.Type, forKey key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
