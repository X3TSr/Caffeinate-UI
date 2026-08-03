import Foundation
import os

/// Thin wrapper so the rest of the code does not repeat the subsystem string.
/// View the output with:
///
///     log stream --predicate 'subsystem == "com.x3tsr.caffeinate-ui"'
public enum Log {
    public static let subsystem = "com.x3tsr.caffeinate-ui"

    private static let logger = Logger(subsystem: subsystem, category: "app")

    public static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    public static func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    public static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
