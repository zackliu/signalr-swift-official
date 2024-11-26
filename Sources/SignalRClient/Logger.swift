import Foundation

public protocol Logger: Sendable {
    func log(level: LogLevel, message: String)
}

class DefaultLogger: Logger, @unchecked Sendable {
    func log(level: LogLevel, message: String) {
        print("[\(Date().description(with: Locale.current))]: [\(level)] \(message)")
    }
}

public enum LogLevel {
    case debug, information, warning, error
}