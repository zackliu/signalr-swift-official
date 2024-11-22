import Foundation

// Define error types for better error handling
enum SignalRError: Error {
    case incompleteMessage
    case invalidDataType
    case failedToEncodeHandshakeRequest
    case failedToDecodeResponseData
    case expectedHandshakeResponse
    case noHandshakeMessageReceived
    case duplicatedStart
    case unsupportedHandshakeVersion
    case handshakeError(String)
    case connectionAborted
    case negotiationError(String)
    case failedToStartConnection(String)

    var localizedDescription: String {
        switch self {
        case .incompleteMessage:
            return "Message is incomplete."
        case .invalidDataType:
            return "Invalid data type."
        case .failedToEncodeHandshakeRequest:
            return "Failed to encode handshake request to JSON string."
        case .failedToDecodeResponseData:
            return "Failed to decode response data."
        case .expectedHandshakeResponse:
            return "Expected a handshake response from the server."
        case .noHandshakeMessageReceived:
            return "No handshake message received."
        case .duplicatedStart:
            return "Start client while not in a disconnected state."
        case .unsupportedHandshakeVersion:
            return "Unsupported handshake version"
        case .handshakeError(let message):
            return "Handshake error: \(message)"
        case .connectionAborted:
            return "Connection aborted."
        case .negotiationError(let message):
            return "Negotiation error: \(message)"
        case .failedToStartConnection(let message):
            return "Failed to start connection: \(message)"
        }
    }
}