import Foundation

public actor HubConnection {
    private let defaultTimeout: TimeInterval = 30
    private let defaultPingInterval: TimeInterval = 15

    private let serverTimeout: TimeInterval
    private let keepAliveInterval: TimeInterval
    private let logger: Logger
    private let hubProtocol: HubProtocol
    private let connection: HttpConnection
    // private let connectionState: ConnectionState

    private var connectionStarted: Bool = false
    private var receivedHandshakeResponse: Bool = false
    private var invocationId: Int = 0
    private var connectionStatus: HubConnectionState = .Disconnected
    nonisolated(unsafe) private var handshakeResoler: ((HandshakeResponseMessage) -> Void)?
    nonisolated(unsafe) private var handshakeRejector: ((Error) -> Void)?

    internal init(connection: HttpConnection,
                logger: Logger,
                hubProtocol: HubProtocol,
                serverTimeout: TimeInterval?,
                keepAliveInterval: TimeInterval?) {
        self.serverTimeout = serverTimeout ?? defaultTimeout
        self.keepAliveInterval = keepAliveInterval ?? defaultPingInterval
        self.logger = logger

        self.connection = connection
        self.hubProtocol = hubProtocol
        // self.connectionState = ConnectionState()
    }

    public func start() async throws {
        self.connection.onClose = handleConnectionClose
        self.connection.onReceive = processIncomingData

        try await startInternal()
    }

    public func stop() async throws {
        // Stop the connection
    }

    public func send(method: String, arguments: Any...) async throws {
        // Send a message
    }

    public func invoke(method: String, arguments: Any...) async throws -> Any {
        // Invoke a method
        return ""
    }

    public func on(method: String, handler: @escaping ([Any]) async -> Void) {
        // Register a handler
    }

    public func off(method: String) {
        // Unregister a handler
    }

    public func onClosed(handler: @escaping (Error?) async -> Void) {
        // Register a handler for the connection closing
    }

    public func onReconnecting(handler: @escaping () async -> Void) {
        // Register a handler for the connection reconnecting
    }

    public func onReconnected(handler: @escaping (_ connectionId: String) async -> Void) {
        // Register a handler for the connection reconnected
    }

    @Sendable private func handleConnectionClose(error: Error?) async {
        logger.log(level: .information, message: "Connection closed")

        if (connectionStatus == .Disconnected) {
            completeClose()
            return
        }

        connectionStatus = .Disconnecting

        if (handshakeResoler != nil) {
            handshakeRejector!(SignalRError.connectionAborted)
        }

        completeClose()
    }

    @Sendable private func processIncomingData(_ prehandledData: StringOrData) async {
        var data = prehandledData
        if (!receivedHandshakeResponse) {
            do {
                data = try await processHandshakeResponse(data)
            } catch {
                // close connection
            }
        }

        // show the data now
        if case .string(let str) = data {
            logger.log(level: .debug, message: "Received data: \(str)")
        } else if case .data(let data) = data {
            logger.log(level: .debug, message: "Received data: \(data)")
        }
    }

    private func completeClose() {
        connectionStatus = .Disconnected
    }

    private func startInternal() async throws {
        try Task.checkCancellation()

        logger.log(level: .information, message: "Connection starting")

        if (connectionStatus != .Disconnected) {
            throw SignalRError.duplicatedStart
        }

        try await connection.start()

        // After connection open, perform handshake
        let version = hubProtocol.version
        // As we don't support version 2 now
        guard version == 1 else {
            throw SignalRError.unsupportedHandshakeVersion
        }

        let handshakeRequset = HandshakeRequestMessage(protocol: hubProtocol.name, version: version)

        logger.log(level: .debug, message: "Sending handshake request message.")
        async let handshakeTask = withCheckedThrowingContinuation { continuation in 
            var hanshakeFinished: Bool = false
            handshakeResoler = { message in
                if (hanshakeFinished) {
                    return
                }
                hanshakeFinished = true
                continuation.resume(returning: message)
            }
            handshakeRejector = { error in
                if (hanshakeFinished) {
                    return
                }
                hanshakeFinished = true
                continuation.resume(throwing: error)
            }
        }

        try await sendMessageInternal(.string(HandshakeProtocol.writeHandshakeRequest(handshakeRequest: handshakeRequset)))
        logger.log(level: .debug, message: "Sent handshake request message with version: \(version), protocol: \(hubProtocol.name)")

        _ = try await handshakeTask
    }

    private func sendMessageInternal(_ content: StringOrData) async throws {

    }

    private func processHandshakeResponse(_ content: StringOrData) async throws -> StringOrData {
        var remainingData: StringOrData?
        var handshakeResponse: HandshakeResponseMessage

        do {
            (remainingData, handshakeResponse) = try HandshakeProtocol.parseHandshakeResponse(data: content)
        } catch{
            logger.log(level: .error, message: "Error parsing handshake response: \(error)")
            handshakeRejector!(error)
            throw error
        }
        
        if (handshakeResponse.error != nil) {
            logger.log(level: .error, message: "Server returned handshake error: \(handshakeResponse.error!)") 
            let error = SignalRError.handshakeError(handshakeResponse.error!)
            handshakeRejector!(error)
            throw error
        } else {
            logger.log(level: .debug, message: "Handshake compeleted")
        }

        handshakeResoler!(handshakeResponse)
        return remainingData!
    }
}

enum HubConnectionState {
    case Disconnected
    case Connecting
    case Connected
    case Disconnecting
    case Reconnecting
}