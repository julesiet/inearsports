import Foundation
import Network

final class LocalUDPSender {

    // godot listens in this connections
    private let connection = NWConnection(
        host: "127.0.0.1",
        port: 5055,
        using: .udp
    )

    private let queue = DispatchQueue(
        label: "airpod.bridge.udp"
    )

    func start() {
        connection.start(queue: queue)
    }

    // accepts raw bytes of data
    func send(_ data: Data) {
        connection.send(
            content: data,
            completion: .contentProcessed { error in
                if let error = error {
                    print("UDP error: \(error)")
                }
            }
        )
    }

    func stop() {
        connection.cancel()
    }
}
