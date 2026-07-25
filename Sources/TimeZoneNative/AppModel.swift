import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    private enum Keys {
        static let zones = "savedZones.v1"
        static let uses24HourTime = "uses24HourTime"
        static let theme = "theme"
        static let cloneV2Migration = "cloneV2Migration"
        static let legacyBundleMigration = "legacyBundleMigration.v1"
    }

    private static let legacyBundleIdentifier = "local.codex.time-zone-converter-native"

    @Published var zones: [ZoneItem] {
        didSet { saveZones() }
    }
    @Published var shiftMinutes = 0
    @Published var isLive = true
    @Published var anchorDate = Date()
    @Published var uses24HourTime: Bool {
        didSet { defaults.set(uses24HourTime, forKey: Keys.uses24HourTime) }
    }
    @Published var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        if defaults === UserDefaults.standard {
            Self.migrateLegacyDefaults(into: defaults)
        }
        self.defaults = defaults

        if let data = defaults.data(forKey: Keys.zones),
           let decoded = try? JSONDecoder().decode([ZoneItem].self, from: data),
           !decoded.isEmpty {
            zones = decoded
        } else {
            zones = Self.defaultZones()
        }

        if defaults.object(forKey: Keys.uses24HourTime) == nil {
            uses24HourTime = Self.systemUses24HourTime()
        } else {
            uses24HourTime = defaults.bool(forKey: Keys.uses24HourTime)
        }

        theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .midnight

        if !defaults.bool(forKey: Keys.cloneV2Migration) {
            migrateToCloneDefaultsIfUnmodified()
            theme = .daylight
            defaults.set(true, forKey: Keys.cloneV2Migration)
        }
    }

    private static func migrateLegacyDefaults(into defaults: UserDefaults) {
        guard !defaults.bool(forKey: Keys.legacyBundleMigration) else { return }

        if let legacyValues = defaults.persistentDomain(forName: legacyBundleIdentifier) {
            for (key, value) in legacyValues where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }

        defaults.set(true, forKey: Keys.legacyBundleMigration)
    }

    func selectedDate(now: Date = Date()) -> Date {
        let base = isLive ? now : anchorDate
        return base.addingTimeInterval(TimeInterval(shiftMinutes * 60))
    }

    func resetToNow() {
        isLive = true
        shiftMinutes = 0
        anchorDate = Date()
    }

    func setAnchorDate(_ date: Date) {
        anchorDate = date
        isLive = false
        shiftMinutes = 0
    }

    func nudge(by minutes: Int) {
        shiftMinutes = min(10_080, max(-10_080, shiftMinutes + minutes))
    }

    func add(identifier: String, nickname: String? = nil) {
        guard TimeZone(identifier: identifier) != nil,
              !zones.contains(where: {
                  $0.timeZoneIdentifier == identifier
                      && ($0.nickname ?? $0.displayName) == (nickname ?? ZoneItem.friendlyName(for: identifier))
              }) else {
            return
        }
        zones.append(ZoneItem(timeZoneIdentifier: identifier, nickname: nickname))
    }

    func add(_ option: CityOption) {
        add(identifier: option.timeZoneIdentifier, nickname: option.preferredNickname)
    }

    func remove(_ item: ZoneItem) {
        zones.removeAll { $0.id == item.id }
    }

    func move(_ item: ZoneItem, to targetIndex: Int) {
        guard let sourceIndex = zones.firstIndex(where: { $0.id == item.id }),
              sourceIndex != targetIndex,
              targetIndex >= 0,
              targetIndex < zones.count else {
            return
        }
        let moved = zones.remove(at: sourceIndex)
        zones.insert(moved, at: min(targetIndex, zones.count))
    }

    func rename(_ item: ZoneItem, to nickname: String) {
        guard let index = zones.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        zones[index].nickname = trimmed.isEmpty ? nil : trimmed
    }

    func cycleTheme() {
        guard let index = AppTheme.allCases.firstIndex(of: theme) else {
            theme = .midnight
            return
        }
        theme = AppTheme.allCases[(index + 1) % AppTheme.allCases.count]
    }

    private func saveZones() {
        guard let data = try? JSONEncoder().encode(zones) else { return }
        defaults.set(data, forKey: Keys.zones)
    }

    private static func systemUses24HourTime() -> Bool {
        let template = DateFormatter.dateFormat(
            fromTemplate: "j",
            options: 0,
            locale: .autoupdatingCurrent
        ) ?? ""
        return !template.contains("a")
    }

    private static func defaultZones() -> [ZoneItem] {
        let identifiers = [
            TimeZone.autoupdatingCurrent.identifier,
            "America/Los_Angeles",
            "Europe/London",
            "Europe/Kyiv",
            "Asia/Tokyo"
        ]
        var seen = Set<String>()
        return identifiers.compactMap { identifier in
            guard TimeZone(identifier: identifier) != nil,
                  seen.insert(identifier).inserted else {
                return nil
            }
            return ZoneItem(timeZoneIdentifier: identifier)
        }
    }

    private func migrateToCloneDefaultsIfUnmodified() {
        let oldDefaults = [
            TimeZone.autoupdatingCurrent.identifier,
            "America/Los_Angeles",
            "Europe/London",
            "Europe/Kyiv",
            "Asia/Tokyo"
        ]
        let currentIdentifiers = zones.map(\.timeZoneIdentifier)
        let expectedIdentifiers = oldDefaults.reduce(into: [String]()) { result, identifier in
            if TimeZone(identifier: identifier) != nil, !result.contains(identifier) {
                result.append(identifier)
            }
        }
        guard currentIdentifiers == expectedIdentifiers,
              zones.allSatisfy({ $0.nickname == nil }) else {
            return
        }

        zones = [
            ZoneItem(timeZoneIdentifier: "America/Los_Angeles", nickname: "San Francisco"),
            ZoneItem(timeZoneIdentifier: "America/New_York", nickname: "New York"),
            ZoneItem(timeZoneIdentifier: "Europe/Lisbon", nickname: "Lisbon"),
            ZoneItem(timeZoneIdentifier: "Europe/Berlin", nickname: "Berlin"),
            ZoneItem(timeZoneIdentifier: "Europe/Moscow", nickname: "St. Petersburg")
        ]
    }
}
