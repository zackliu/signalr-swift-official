import Foundation

public class HubConnectionBuilder {
    private var connection: HttpConnection?
    private var logger: Logger?
    private var hubProtocol: HubProtocol?
    private var serverTimeout: TimeInterval?
    private var keepAliveInterval: TimeInterval?
    private var url: String?

    public init() {}

    public func withLogger(logger: Logger) -> HubConnectionBuilder {
        self.logger = logger
        return self
    }

    public func withHubProtocol(hubProtocol: HubProtocol) -> HubConnectionBuilder {
        self.hubProtocol = hubProtocol
        return self
    }

    public func withServerTimeout(serverTimeout: TimeInterval) -> HubConnectionBuilder {
        self.serverTimeout = serverTimeout
        return self
    }

    public func withKeepAliveInterval(keepAliveInterval: TimeInterval) -> HubConnectionBuilder {
        self.keepAliveInterval = keepAliveInterval
        return self
    }

    public func withUrl(url: String) -> HubConnectionBuilder {
        self.url = url
        return self
    }

    public func build() -> HubConnection {
        guard let url = url else {
            fatalError("url must be set with .withUrl(String:)")
        }

        let connection = connection ?? HttpConnection(url: url)
        let logger = logger ?? DefaultLogger()
        let hubProtocol = hubProtocol ?? JsonHubProtocol()

        return HubConnection(connection: connection,
                             logger: logger,
                             hubProtocol: hubProtocol,
                             serverTimeout: serverTimeout,
                             keepAliveInterval: keepAliveInterval)
    }
}