import SwiftUI

struct ContentView: View {
    private let webSocketClient = WebSocketClient()
    private let pointExtractor = PointExtractor(downsampleRatio: 0.3)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LidarView(pointExtractor: pointExtractor, webSocketClient: webSocketClient)
                .edgesIgnoringSafeArea(.all)
            ConnectionIndicator(isConnected: webSocketClient.isConnected)
                .padding()
        }
    }
}

private struct ConnectionIndicator: View {
    @ObservedObject var isConnected: ConnectionState

    var body: some View {
        Text(isConnected.value ? "WS Connected" : "WS Disconnected")
            .font(.footnote.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isConnected.value ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
            .clipShape(Capsule())
            .foregroundColor(.white)
            .animation(.easeInOut(duration: 0.3), value: isConnected.value)
    }
}
