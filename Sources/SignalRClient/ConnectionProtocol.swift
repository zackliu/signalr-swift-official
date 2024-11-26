protocol ConnectionProtocol: AnyObject, Sendable {
    var onReceive: Transport.OnReceiveHandler? { get set }
    var onClose: Transport.OnCloseHander? { get set }
    func start(transferFormat: TransferFormat) async throws
    func send(_ data: StringOrData) async throws
    func stop(error: Error?) async
}