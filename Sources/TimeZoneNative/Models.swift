import AppKit
import Foundation
import SwiftUI

struct ZoneItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let timeZoneIdentifier: String
    var nickname: String?

    init(
        id: UUID = UUID(),
        timeZoneIdentifier: String,
        nickname: String? = nil
    ) {
        self.id = id
        self.timeZoneIdentifier = timeZoneIdentifier
        self.nickname = nickname
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    var displayName: String {
        if let nickname, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nickname
        }
        return Self.friendlyName(for: timeZoneIdentifier)
    }

    static func friendlyName(for identifier: String) -> String {
        let component = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return component.replacingOccurrences(of: "_", with: " ")
    }

    static func regionName(for identifier: String) -> String {
        let parts = identifier.split(separator: "/").map {
            String($0).replacingOccurrences(of: "_", with: " ")
        }
        guard parts.count > 1 else { return identifier }
        return parts.dropLast().joined(separator: ", ")
    }
}

enum AppTheme: String, CaseIterable, Codable, Sendable {
    case midnight
    case graphite
    case daylight

    var title: String {
        switch self {
        case .midnight: "Black"
        case .graphite: "Graphite"
        case .daylight: "White"
        }
    }

    var symbolName: String {
        switch self {
        case .midnight: "moon.stars.fill"
        case .graphite: "circle.lefthalf.filled"
        case .daylight: "sun.max.fill"
        }
    }

    var colorScheme: ColorScheme {
        self == .daylight ? .light : .dark
    }

    var background: Color {
        switch self {
        case .midnight: Color(red: 0.105, green: 0.095, blue: 0.125)
        case .graphite: Color(red: 0.245, green: 0.265, blue: 0.315)
        case .daylight: Color(red: 0.985, green: 0.985, blue: 0.985)
        }
    }

    var card: Color {
        switch self {
        case .midnight: Color.white.opacity(0.025)
        case .graphite: Color.white.opacity(0.025)
        case .daylight: Color.white
        }
    }

    var secondaryCard: Color {
        switch self {
        case .midnight: Color.black.opacity(0.08)
        case .graphite: Color.black.opacity(0.055)
        case .daylight: Color.white
        }
    }

    var palette: ClonePalette {
        switch self {
        case .midnight:
            ClonePalette(
                background: background,
                primary: .white.opacity(0.92),
                secondary: .white.opacity(0.48),
                sleepy: .white.opacity(0.26),
                separator: .white.opacity(0.075),
                ruler: .white.opacity(0.34),
                rulerFade: background,
                control: .white.opacity(0.28)
            )
        case .graphite:
            ClonePalette(
                background: background,
                primary: .white.opacity(0.94),
                secondary: .white.opacity(0.48),
                sleepy: .white.opacity(0.26),
                separator: .black.opacity(0.15),
                ruler: .white.opacity(0.34),
                rulerFade: background,
                control: .white.opacity(0.28)
            )
        case .daylight:
            ClonePalette(
                background: background,
                primary: .black,
                secondary: .black.opacity(0.48),
                sleepy: .black.opacity(0.25),
                separator: .black.opacity(0.12),
                ruler: .black.opacity(0.31),
                rulerFade: background,
                control: .black.opacity(0.25)
            )
        }
    }
}

struct ClonePalette {
    let background: Color
    let primary: Color
    let secondary: Color
    let sleepy: Color
    let separator: Color
    let ruler: Color
    let rulerFade: Color
    let control: Color
}

enum Availability: String, Sendable {
    case business
    case overtime
    case personal
    case sleeping

    static func classify(hour: Int) -> Availability {
        switch hour {
        case 9..<18: .business
        case 7..<9, 18..<20: .overtime
        case 6..<7, 20..<24: .personal
        default: .sleeping
        }
    }

    var title: String {
        switch self {
        case .business: "Business time"
        case .overtime: "Business overtime"
        case .personal: "Personal time"
        case .sleeping: "Sleeping time"
        }
    }

    var color: Color {
        switch self {
        case .business: Color(red: 0.22, green: 0.85, blue: 0.52)
        case .overtime: Color(red: 1.00, green: 0.75, blue: 0.26)
        case .personal: Color(red: 1.00, green: 0.32, blue: 0.43)
        case .sleeping: Color(red: 0.78, green: 0.84, blue: 0.90)
        }
    }

    var symbol: String {
        self == .sleeping ? "moon.fill" : "circle.fill"
    }
}

@MainActor
enum ZoneFormatting {
    static func timeString(
        for date: Date,
        in timeZone: TimeZone,
        uses24HourTime: Bool
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeZone = timeZone
        formatter.dateFormat = uses24HourTime ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }

    static func fullDateString(for date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    static func dayRelation(
        for date: Date,
        in timeZone: TimeZone,
        relativeTo localTimeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = localTimeZone
        var zoneCalendar = Calendar(identifier: .gregorian)
        zoneCalendar.timeZone = timeZone

        var neutralCalendar = Calendar(identifier: .gregorian)
        neutralCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let localComponents = localCalendar.dateComponents([.year, .month, .day], from: date)
        let zoneComponents = zoneCalendar.dateComponents([.year, .month, .day], from: date)
        let localDay = neutralCalendar.date(from: localComponents) ?? date
        let zoneDay = neutralCalendar.date(from: zoneComponents) ?? date
        let difference = neutralCalendar.dateComponents([.day], from: localDay, to: zoneDay).day ?? 0

        switch difference {
        case -1: return "yesterday"
        case 0: return "today"
        case 1: return "tomorrow"
        default: return fullDateString(for: date, in: timeZone)
        }
    }

    static func abbreviation(for date: Date, in timeZone: TimeZone) -> String {
        timeZone.abbreviation(for: date) ?? timeZone.identifier
    }

    static func offsetString(
        for date: Date,
        in timeZone: TimeZone,
        relativeTo localTimeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        let seconds = timeZone.secondsFromGMT(for: date) - localTimeZone.secondsFromGMT(for: date)
        guard seconds != 0 else { return "local" }

        let sign = seconds > 0 ? "+" : "−"
        let absoluteMinutes = abs(seconds) / 60
        let hours = absoluteMinutes / 60
        let minutes = absoluteMinutes % 60
        if minutes == 0 {
            return "\(sign)\(hours)h"
        }
        return "\(sign)\(hours)h \(minutes)m"
    }

    static func availability(for date: Date, in timeZone: TimeZone) -> Availability {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return Availability.classify(hour: calendar.component(.hour, from: date))
    }

    static func copyText(
        for item: ZoneItem,
        date: Date,
        uses24HourTime: Bool
    ) -> String {
        let time = timeString(for: date, in: item.timeZone, uses24HourTime: uses24HourTime)
        let day = fullDateString(for: date, in: item.timeZone)
        let abbreviation = abbreviation(for: date, in: item.timeZone)
        return "\(item.displayName) — \(day), \(time) \(abbreviation)"
    }
}
