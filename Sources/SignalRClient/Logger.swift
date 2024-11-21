public protocol Logger: Sendable {
    func log(level: LogLevel, message: String)
}

class DefaultLogger: Logger, @unchecked Sendable {
    func log(level: LogLevel, message: String) {
        print("[\(level)] \(message)")
    }
}

public enum LogLevel {
    case debug, information, warning, error
}