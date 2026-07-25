import Foundation
import Testing
@testable import TimeZoneNative

@Suite("Time zone conversion")
@MainActor
struct TimeZoneNativeTests {
    @Test("Half-hour offsets are formatted correctly")
    func halfHourOffset() throws {
        let kolkata = try #require(TimeZone(identifier: "Asia/Kolkata"))
        let utc = try #require(TimeZone(identifier: "UTC"))
        let date = Date(timeIntervalSince1970: 1_704_067_200)

        #expect(
            ZoneFormatting.offsetString(for: date, in: kolkata, relativeTo: utc) == "+5h 30m"
        )
    }

    @Test("DST comes from the system time-zone database")
    func daylightSavingTime() throws {
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        let january = Date(timeIntervalSince1970: 1_704_067_200)
        let july = Date(timeIntervalSince1970: 1_719_792_000)

        #expect(newYork.secondsFromGMT(for: january) == -18_000)
        #expect(newYork.secondsFromGMT(for: july) == -14_400)
    }

    @Test("Availability bands match the documented hours")
    func availabilityBands() {
        #expect(Availability.classify(hour: 10) == .business)
        #expect(Availability.classify(hour: 8) == .overtime)
        #expect(Availability.classify(hour: 19) == .overtime)
        #expect(Availability.classify(hour: 22) == .personal)
        #expect(Availability.classify(hour: 2) == .sleeping)
    }

    @Test("Friendly city names use the IANA city component")
    func friendlyName() {
        #expect(ZoneItem.friendlyName(for: "America/Los_Angeles") == "Los Angeles")
        #expect(ZoneItem.friendlyName(for: "Asia/Kolkata") == "Kolkata")
    }

    @Test("City aliases reproduce the original app's searchable names")
    func cityAliases() throws {
        let sanFrancisco = try #require(CityCatalog.search("San Fra").first)
        let saintPetersburg = try #require(CityCatalog.search("St. Peter").first)

        #expect(sanFrancisco.name == "San Francisco")
        #expect(sanFrancisco.timeZoneIdentifier == "America/Los_Angeles")
        #expect(saintPetersburg.name == "St. Petersburg")
        #expect(saintPetersburg.timeZoneIdentifier == "Europe/Moscow")
    }

    @Test("The clone migration matches the reference city list and white theme")
    func cloneMigration() throws {
        let suiteName = "TimeZoneNative.CloneMigration.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let model = AppModel(defaults: defaults)

        #expect(model.zones.map(\.displayName) == [
            "San Francisco",
            "New York",
            "Lisbon",
            "Berlin",
            "St. Petersburg"
        ])
        #expect(model.theme == .daylight)
    }

    @Test("A settled row drag commits exactly once at its target index")
    func rowReordering() throws {
        let suiteName = "TimeZoneNative.RowReordering.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = AppModel(defaults: defaults)
        let first = try #require(model.zones.first)
        let originalOrder = model.zones

        model.move(first, to: 3)

        #expect(model.zones[3] == first)
        #expect(model.zones.map(\.id) == [
            originalOrder[1].id,
            originalOrder[2].id,
            originalOrder[3].id,
            originalOrder[0].id,
            originalOrder[4].id
        ])
    }

    @Test("Day labels reveal date-boundary differences")
    func dayRelations() throws {
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let components = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: losAngeles,
            year: 2026,
            month: 7,
            day: 24,
            hour: 18
        )
        let date = try #require(components.date)

        #expect(
            ZoneFormatting.dayRelation(
                for: date,
                in: tokyo,
                relativeTo: losAngeles
            ) == "tomorrow"
        )
    }
}
