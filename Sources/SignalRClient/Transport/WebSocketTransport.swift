import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif


final class WebSocketTransport: NSObject, Transport, URLSessionWebSocketDelegate, @unchecked Sendable {
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
        self.urlSession = urlSession
    }

    func onReceive(_ handler: OnReceiveHandler?) {
        self.onReceive = handler
    }

    func onClose(_ handler: OnCloseHander?) {
        self.onClose = handler
    }

    func connect(url: String, transferFormat: TransferFormat) async throws {
        self.logger.log(level: .debug, message: "(WebSockets transport) Connecting.")

        // self.urlSession = self.urlSession ?? URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        self.urlSession = URLSession.shared
        self.transferFormat = transferFormat

        var urlComponents = URLComponents(url: URL(string: "http://localhost:8080/Chat")!, resolvingAgainstBaseURL: false)!

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

        logger.log(level: .debug, message: "Connecting to \(String(describing: urlComponents))")

        websocket = urlSession!.webSocketTask(with: URL(string: urlComponents.string!)!)

        guard websocket != nil else {
            logger.log(level: .error, message: "(WebSockets transport) WebSocket is nil")
            return
        }

        logger.log(level: .debug, message: "(WebSockets transport) Before resume")
        websocket!.resume()
        logger.log(level: .debug, message: "(WebSockets transport) After resume")

        do {
            let message = try await websocket!.receive()
            logger.log(level: .debug, message: "(WebSockets transport) Connecting to \(String(describing: message))")
        } catch {
            if let nsError = error as? URLError {
                logger.log(level: .error, message: "(WebSockets transport Error) \(nsError.userInfo)")
            }
            logger.log(level: .error, message: "(WebSockets transport Error) \(error)")
        }

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

    // When connection close by any reasion?
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        logger.log(level: .debug, message: "(WebSockets transport) URLSession didCompleteWithError: \(String(describing: error))")

        Task {
            try await stop(error: error)
        }
    }

    // When receive websocket close message?
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logger.log(level: .debug, message: "(WebSockets transport) URLSession didCloseWith: \(closeCode)")

        Task {
            try await stop(error: nil)
        }
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        logger.log(level: .debug, message: "(WebSockets transport) urlSession didOpenWithProtocol invoked. WebSocket open")
    }

    private func receiveMessage() async {
        guard let websocket = websocket else {
            logger.log(level: .error, message: "(WebSockets transport) WebSocket is nil")
            return 
        }
        
        logger.log(level: .error, message: "(WebSockets transport) Start receiving messages")

        do {
            while true {
                let message = try await websocket.receive()

                switch message {
                    case .string(let text):
                        logger.log(level: .debug, message: "(WebSockets transport) Received message: \(text)")
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