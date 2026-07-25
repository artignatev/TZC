import Foundation

struct CityOption: Identifiable, Hashable, Sendable {
    let name: String
    let timeZoneIdentifier: String
    let region: String
    let preferredNickname: String?

    var id: String {
        "\(name)|\(timeZoneIdentifier)"
    }
}

enum CityCatalog {
    static let aliases: [CityOption] = [
        city("San Francisco", "America/Los_Angeles", "America"),
        city("Seattle", "America/Los_Angeles", "America"),
        city("Vancouver", "America/Vancouver", "America"),
        city("New York", "America/New_York", "America"),
        city("Washington, D.C.", "America/New_York", "America"),
        city("Boston", "America/New_York", "America"),
        city("Miami", "America/New_York", "America"),
        city("Chicago", "America/Chicago", "America"),
        city("Dallas", "America/Chicago", "America"),
        city("Denver", "America/Denver", "America"),
        city("Phoenix", "America/Phoenix", "America"),
        city("Mexico City", "America/Mexico_City", "America"),
        city("Toronto", "America/Toronto", "America"),
        city("Montreal", "America/Toronto", "America"),
        city("São Paulo", "America/Sao_Paulo", "America"),
        city("Buenos Aires", "America/Argentina/Buenos_Aires", "America, Argentina"),
        city("Santiago", "America/Santiago", "America"),
        city("Bogotá", "America/Bogota", "America"),
        city("Lima", "America/Lima", "America"),
        city("London", "Europe/London", "Europe"),
        city("Lisbon", "Europe/Lisbon", "Europe"),
        city("Dublin", "Europe/Dublin", "Europe"),
        city("Paris", "Europe/Paris", "Europe"),
        city("Berlin", "Europe/Berlin", "Europe"),
        city("Amsterdam", "Europe/Amsterdam", "Europe"),
        city("Brussels", "Europe/Brussels", "Europe"),
        city("Madrid", "Europe/Madrid", "Europe"),
        city("Rome", "Europe/Rome", "Europe"),
        city("Vienna", "Europe/Vienna", "Europe"),
        city("Prague", "Europe/Prague", "Europe"),
        city("Warsaw", "Europe/Warsaw", "Europe"),
        city("Stockholm", "Europe/Stockholm", "Europe"),
        city("Oslo", "Europe/Oslo", "Europe"),
        city("Copenhagen", "Europe/Copenhagen", "Europe"),
        city("Helsinki", "Europe/Helsinki", "Europe"),
        city("Athens", "Europe/Athens", "Europe"),
        city("Bucharest", "Europe/Bucharest", "Europe"),
        city("Kyiv", "Europe/Kyiv", "Europe"),
        city("St. Petersburg", "Europe/Moscow", "Europe"),
        city("Moscow", "Europe/Moscow", "Europe"),
        city("Istanbul", "Europe/Istanbul", "Europe"),
        city("Cairo", "Africa/Cairo", "Africa"),
        city("Cape Town", "Africa/Johannesburg", "Africa"),
        city("Johannesburg", "Africa/Johannesburg", "Africa"),
        city("Lagos", "Africa/Lagos", "Africa"),
        city("Nairobi", "Africa/Nairobi", "Africa"),
        city("Casablanca", "Africa/Casablanca", "Africa"),
        city("Dubai", "Asia/Dubai", "Asia"),
        city("Tel Aviv", "Asia/Jerusalem", "Asia"),
        city("Jerusalem", "Asia/Jerusalem", "Asia"),
        city("Riyadh", "Asia/Riyadh", "Asia"),
        city("New Delhi", "Asia/Kolkata", "Asia"),
        city("Mumbai", "Asia/Kolkata", "Asia"),
        city("Bengaluru", "Asia/Kolkata", "Asia"),
        city("Singapore", "Asia/Singapore", "Asia"),
        city("Bangkok", "Asia/Bangkok", "Asia"),
        city("Jakarta", "Asia/Jakarta", "Asia"),
        city("Hong Kong", "Asia/Hong_Kong", "Asia"),
        city("Shanghai", "Asia/Shanghai", "Asia"),
        city("Beijing", "Asia/Shanghai", "Asia"),
        city("Taipei", "Asia/Taipei", "Asia"),
        city("Seoul", "Asia/Seoul", "Asia"),
        city("Tokyo", "Asia/Tokyo", "Asia"),
        city("Manila", "Asia/Manila", "Asia"),
        city("Perth", "Australia/Perth", "Australia"),
        city("Adelaide", "Australia/Adelaide", "Australia"),
        city("Melbourne", "Australia/Melbourne", "Australia"),
        city("Sydney", "Australia/Sydney", "Australia"),
        city("Brisbane", "Australia/Brisbane", "Australia"),
        city("Auckland", "Pacific/Auckland", "Pacific"),
        city("Honolulu", "Pacific/Honolulu", "Pacific"),
        city("UTC", "UTC", "Universal")
    ]

    static let all: [CityOption] = {
        var seen = Set(aliases.map(\.id))
        let canonical = TimeZone.knownTimeZoneIdentifiers
            .filter { !$0.hasPrefix("Etc/") && !$0.hasPrefix("SystemV/") }
            .map {
                CityOption(
                    name: ZoneItem.friendlyName(for: $0),
                    timeZoneIdentifier: $0,
                    region: ZoneItem.regionName(for: $0),
                    preferredNickname: nil
                )
            }
            .filter { seen.insert($0.id).inserted }
        return aliases + canonical
    }()

    static func search(_ query: String) -> [CityOption] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        return all
            .filter {
                $0.name.localizedCaseInsensitiveContains(needle)
                    || $0.region.localizedCaseInsensitiveContains(needle)
                    || $0.timeZoneIdentifier.localizedCaseInsensitiveContains(needle)
            }
            .sorted { left, right in
                let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .anchored]
                let leftPrefix = left.name.range(of: needle, options: options, locale: .autoupdatingCurrent) != nil
                let rightPrefix = right.name.range(of: needle, options: options, locale: .autoupdatingCurrent) != nil
                if leftPrefix != rightPrefix { return leftPrefix }
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
    }

    private static func city(_ name: String, _ identifier: String, _ region: String) -> CityOption {
        CityOption(
            name: name,
            timeZoneIdentifier: identifier,
            region: region,
            preferredNickname: name
        )
    }
}
