import Foundation

enum TMDBFormat {
    enum ImageSize: String {
        case w300
        case w780
    }

    static let dateStrategy = Date.ParseStrategy(
        format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: .gmt
    )

    static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        return try? Date(string, strategy: dateStrategy)
    }

    static func imageURL(path: String?, size: ImageSize = .w300) -> URL? {
        guard let path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size.rawValue)\(path)")
    }
}
