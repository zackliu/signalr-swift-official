import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif


final class WebSocketTransport: NSObject, Transport, URLSessionTaskDelegate, @unchecked Sendable {
    private let logger: Logger
    private let accessTokenFactory: (@Sendable() async throws -> String?)?
    private let logMessageContent: Bool
    private let headers: [String: String]
    private let stopped: AtomicState<Bool> = AtomicState(initialState: false)

    private var transferFormat: TransferFormat = .text
    private var websocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var onReceive: OnReceiveHandler?
    private var onClose: OnCloseHander?

    init(accessTokenFactory: (@Sendable () async throws -> String?)?,
         logger: Logger,
         logMessageContent: Bool,
         headers: [String: String],
         urlSession: URLSession? = nil) {
        self.accessTokenFactory = accessTokenFactory
        self.logger = logger
        self.logMessageContent = logMessageContent
        self.headers = headers
        self.urlSession = urlSession ?? URLSession.shared
    }

    func onReceive(_ handler: OnReceiveHandler?) {
        self.onReceive = handler
    }

    func onClose(_ handler: OnCloseHander?) {
        self.onClose = handler
    }

    func connect(url: String, transferFormat: TransferFormat) async throws {
        self.logger.log(level: .debug, message: "(WebSockets transport) Connecting.")

        self.transferFormat = transferFormat

        var urlComponents = URLComponents(url: URL(string: url)!, resolvingAgainstBaseURL: false)!

        if urlComponents.scheme == "http" {
            urlComponents.scheme = "ws"
        } else if urlComponents.scheme == "https" {
            urlComponents.scheme = "wss"
        }

        var request = URLRequest(url: urlComponents.url!)

        // Add token to query
        if accessTokenFactory != nil {
            let token = try await accessTokenFactory!()
            urlComponents.queryItems = [URLQueryItem(name: "access_token", value: token)]
        }

        // Add headeres
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let websocket: URLSessionWebSocketTask = urlSession!.webSocketTask(with: request)

        websocket.resume()

        Task {
            await receiveMessage()
        }
    }

    func send(_ data: StringOrData) async throws {
        guard let ws = self.websocket else {
            throw NSError(domain: "WebSocketTransport",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "WebSocket is not in the OPEN state"])
        }

        switch data {
            case .string(let str):
                try await ws.send(URLSessionWebSocketTask.Message.string(str))
            case .data(let data):
                try await ws.send(URLSessionWebSocketTask.Message.data(data))
        }
    }

    func stop(error: Error?) async throws {
        // trigger once?
        if await stopped.compareExchange(expected: false, desired: true) != false {
            return
        }

        websocket?.cancel()
        urlSession?.finishTasksAndInvalidate()
        await onClose?(nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        Task {
            try await stop(error: error)
        }
    }

    private func receiveMessage() async {
        guard let websocket = websocket else { return }
        
        do {
            while true {
                let message = try await websocket.receive()

                switch message {
                    case .string(let text):
                        await onReceive?(.string(text))
                    case .data(let data):
                        await onReceive?(.data(data))
                }
            }
        } catch {
            logger.log(level: .error, message: "Failed to receive message: \(error)")
            websocket.cancel(with: .invalid, reason: nil)
        }
    }
}