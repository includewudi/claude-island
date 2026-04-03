//
//  Settings.swift
//  ClaudeIsland
//
//  App settings manager using UserDefaults
//

import Foundation

/// Available notification sounds
enum NotificationSound: String, CaseIterable {
    case none = "None"
    case pop = "Pop"
    case ping = "Ping"
    case tink = "Tink"
    case glass = "Glass"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case hero = "Hero"
    case morse = "Morse"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case submarine = "Submarine"
    case basso = "Basso"

    /// The system sound name to use with NSSound, or nil for no sound
    var soundName: String? {
        self == .none ? nil : rawValue
    }
}

enum AppSettings {
    private static let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let notificationSound = "notificationSound"
        static let sseEnabled = "sseEnabled"
        static let sseEndpointURL = "sseEndpointURL"
        static let sseAuthToken = "sseAuthToken"
    }

    // MARK: - Notification Sound

    /// The sound to play when Claude finishes and is ready for input
    static var notificationSound: NotificationSound {
        get {
            guard let rawValue = defaults.string(forKey: Keys.notificationSound),
                  let sound = NotificationSound(rawValue: rawValue) else {
                return .pop // Default to Pop
            }
            return sound
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.notificationSound)
        }
    }

    // MARK: - SSE (TmuxWeb/OpenCode)

    static var sseEnabled: Bool {
        get { defaults.bool(forKey: Keys.sseEnabled) }
        set { defaults.set(newValue, forKey: Keys.sseEnabled) }
    }

    static var sseEndpointURL: String? {
        get { defaults.string(forKey: Keys.sseEndpointURL) }
        set { defaults.set(newValue, forKey: Keys.sseEndpointURL) }
    }

    static var sseAuthToken: String? {
        get { defaults.string(forKey: Keys.sseAuthToken) }
        set { defaults.set(newValue, forKey: Keys.sseAuthToken) }
    }
}
