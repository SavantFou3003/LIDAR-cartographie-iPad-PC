import asyncio
import json
from collections import deque
from datetime import datetime
from typing import Deque, Set

import websockets
from websockets import WebSocketServerProtocol

LIDAR_PORT = 8765
WEB_UI_PORT = 9000
LOG_LIMIT = 500


class PointRelayServer:
    def __init__(self) -> None:
        self.web_clients: Set[WebSocketServerProtocol] = set()
        self.message_log: Deque[str] = deque(maxlen=LOG_LIMIT)
        self.lock = asyncio.Lock()

    async def lidar_handler(self, websocket: WebSocketServerProtocol) -> None:
        async for message in websocket:
            await self.handle_lidar_message(message)

    async def handle_lidar_message(self, message: str) -> None:
        try:
            payload = json.loads(message)
        except json.JSONDecodeError:
            print("[Relay] Invalid JSON received, ignoring")
            return
        payload["receivedAt"] = datetime.utcnow().isoformat()
        serialized = json.dumps(payload)
        async with self.lock:
            self.message_log.append(serialized)
        await self.broadcast(serialized)

    async def broadcast(self, message: str) -> None:
        if not self.web_clients:
            return
        coroutines = []
        for client in list(self.web_clients):
            coroutines.append(self._send_or_drop(client, message))
        await asyncio.gather(*coroutines, return_exceptions=True)

    async def _send_or_drop(self, client: WebSocketServerProtocol, message: str) -> None:
        try:
            await client.send(message)
        except Exception as exc:  # noqa: BLE001
            print(f"[Relay] dropping client due to error: {exc}")
            await self.unregister_client(client)

    async def web_handler(self, websocket: WebSocketServerProtocol) -> None:
        await self.register_client(websocket)
        try:
            async for _ in websocket:
                continue
        finally:
            await self.unregister_client(websocket)

    async def register_client(self, websocket: WebSocketServerProtocol) -> None:
        async with self.lock:
            self.web_clients.add(websocket)
            history = list(self.message_log)
        for message in history[-20:]:
            await websocket.send(message)
        print(f"[Relay] web client connected. total={len(self.web_clients)}")

    async def unregister_client(self, websocket: WebSocketServerProtocol) -> None:
        async with self.lock:
            self.web_clients.discard(websocket)
        print(f"[Relay] web client disconnected. total={len(self.web_clients)}")


async def main() -> None:
    relay = PointRelayServer()
    lidar_server = websockets.serve(relay.lidar_handler, "0.0.0.0", LIDAR_PORT)
    web_server = websockets.serve(relay.web_handler, "0.0.0.0", WEB_UI_PORT)

    async with lidar_server, web_server:
        print(f"[Relay] Listening for iPad on ws://0.0.0.0:{LIDAR_PORT}")
        print(f"[Relay] Serving web clients on ws://0.0.0.0:{WEB_UI_PORT}")
        await asyncio.Future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("[Relay] Shutdown requested")
