import OSLog

enum AppLogger {
    static let api = Logger(subsystem: "com.apsoftware.gato", category: "api")
    static let persistence = Logger(subsystem: "com.apsoftware.gato", category: "persistence")
    static let ui = Logger(subsystem: "com.apsoftware.gato", category: "ui")
}
