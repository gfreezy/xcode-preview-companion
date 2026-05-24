import Foundation

enum PrivacyAction: String, Sendable {
    case grant, revoke, reset

    var label: String {
        switch self {
        case .grant: "Granted"
        case .revoke: "Revoked"
        case .reset: "Reset"
        }
    }
}

/// Services accepted by `simctl privacy`. This list mirrors the binary's own help
/// output (verified against Xcode 26.5) — note there is intentionally no `camera`.
enum PrivacyService: String, CaseIterable, Identifiable, Sendable {
    case all
    case calendar
    case contactsLimited = "contacts-limited"
    case contacts
    case location
    case locationAlways = "location-always"
    case photosAdd = "photos-add"
    case photos
    case mediaLibrary = "media-library"
    case microphone
    case motion
    case reminders
    case siri

    var id: String { rawValue }
    var argument: String { rawValue }

    /// Per-service rows shown in the UI (`all` is handled by a dedicated button).
    static let grantable: [PrivacyService] = allCases.filter { $0 != .all }

    var displayName: String {
        switch self {
        case .all: "All Services"
        case .calendar: "Calendar"
        case .contactsLimited: "Contacts (Limited)"
        case .contacts: "Contacts"
        case .location: "Location (In Use)"
        case .locationAlways: "Location (Always)"
        case .photosAdd: "Photos (Add Only)"
        case .photos: "Photos"
        case .mediaLibrary: "Media Library"
        case .microphone: "Microphone"
        case .motion: "Motion & Fitness"
        case .reminders: "Reminders"
        case .siri: "Siri"
        }
    }

    var symbol: String {
        switch self {
        case .all: "checklist"
        case .calendar: "calendar"
        case .contactsLimited: "person.crop.circle.badge.minus"
        case .contacts: "person.crop.circle"
        case .location: "location"
        case .locationAlways: "location.fill"
        case .photosAdd: "photo.badge.plus"
        case .photos: "photo.on.rectangle"
        case .mediaLibrary: "music.note.list"
        case .microphone: "mic"
        case .motion: "figure.walk"
        case .reminders: "checklist"
        case .siri: "mic.circle"
        }
    }
}
