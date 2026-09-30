import os

/// Unified logging categories. One logger per subsystem area so Console.app
/// filtering stays useful on device. Never log user-identifying content.
enum AppLog {
    private static let subsystem = "com.gabrielmotta.fretspace"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let calibration = Logger(subsystem: subsystem, category: "calibration")
    static let overlay = Logger(subsystem: subsystem, category: "overlay")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let network = Logger(subsystem: subsystem, category: "network")
}
