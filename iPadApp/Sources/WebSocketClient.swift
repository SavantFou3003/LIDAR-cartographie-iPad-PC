import Foundation
import Combine

final class ConnectionState: ObservableObject {
    @Published var value: Bool = false
}

final class WebSocketClient: NSObject {
    private let url = URL(string: "ws://192.168.1.10:8765")!
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private var task: URLSessionWebSocketTask?
    private let queue = DispatchQueue(label: "WebSocketClientQueue")
    let isConnected = ConnectionState()

    override init() {
        super.init()
        connect()
    }

    func send(points: [PointData]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.task == nil {
                self.connect()
            }
            guard let task = self.task else { return }
            let payload = ["points": points.map { ["x": $0.x, "y": $0.y, "z": $0.z, "gray": $0.gray] }]
            guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else { return }
            task.send(.data(data)) { error in
                if let error = error {
                    print("WebSocket send error: \(error.localizedDescription)")
                    self.reconnect()
                }
            }
        }
    }

    private func connect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = session.webSocketTask(with: url)
        task?.resume()
        listen()
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("WebSocket receive error: \(error.localizedDescription)")
                self.reconnect()
            case .success:
                self.listen()
            }
        }
    }

    private func reconnect() {
        isConnected.value = false
        queue.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.connect()
        }
    }
}

extension WebSocketClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected.value = true
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected.value = false
        }
        reconnect()
    }
}
