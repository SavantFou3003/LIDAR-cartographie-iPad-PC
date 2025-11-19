# LIDAR-cartographie-iPad-PC

This project pairs an iPad LiDAR capture app (SwiftUI/ARKit) with a PC WebSocket relay and a futuristic Three.js dashboard.

## PC setup (Windows/macOS/Linux)
1. **Install Python 3.10+**.
2. (Recommended) create and activate a virtual environment.
3. Install dependencies:
   ```bash
   pip install -r PC/requirements.txt
   ```
4. Start the relay server (opens ports `8765` for the iPad and `9000` for the web UI):
   ```bash
   python PC/server.py
   ```
5. Serve the web dashboard (from another terminal):
   ```bash
   cd PC/web
   python -m http.server 8000
   ```
   Then open http://localhost:8000 in your browser.

## iPad app
- Open the `iPadApp` folder in Xcode (SwiftUI, ARKit). The app streams LiDAR point clouds to the PC at `ws://192.168.1.10:8765` (update the IP in `WebSocketClient.swift` if needed).
- Build and run on a LiDAR-capable device (iPad Pro/mini with LiDAR).

## Troubleshooting
- If you see `ModuleNotFoundError: No module named 'websockets'`, install the dependency with `pip install -r PC/requirements.txt` or `pip install websockets`.
- Ensure the PC firewall allows inbound connections on ports 8765 and 9000.
