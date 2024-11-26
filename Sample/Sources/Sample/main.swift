import SignalRClient

print("Using SignalRClient")

let client = HubConnectionBuilder().withUrl(url: String("http://localhost:8080/Chat")).build()
try await client.start()

print("After start")
