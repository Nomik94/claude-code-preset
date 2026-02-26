---
name: websocket
description: |
  FastAPI WebSocket 패턴 레퍼런스.
  Use when: 웹소켓, WebSocket, 실시간, 채팅, 알림, 실시간 통신,
  ws 연결, 양방향 통신, 브로드캐스트, 소켓, pub/sub.
  NOT for: HTTP API (fastapi skill 참조), SSE.
---

# FastAPI WebSocket 패턴

## 1. 기본 WebSocket 엔드포인트

```python
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI()

@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await ws.accept()
    try:
        while True:
            data = await ws.receive_json()
            await ws.send_json({"echo": data})
    except WebSocketDisconnect:
        pass  # client disconnected cleanly
    except Exception:
        await ws.close(code=1011, reason="Internal error")
```

## 2. 커넥션 매니저

```python
from fastapi import WebSocket
import structlog

logger = structlog.get_logger()


class ConnectionManager:
    def __init__(self) -> None:
        self._active: dict[str, WebSocket] = {}  # user_id -> ws

    async def connect(self, user_id: str, ws: WebSocket) -> None:
        await ws.accept()
        old = self._active.pop(user_id, None)
        if old:
            await old.close(code=1000, reason="Replaced by new connection")
        self._active[user_id] = ws
        logger.info("ws_connect", user_id=user_id, total=len(self._active))

    def disconnect(self, user_id: str) -> None:
        self._active.pop(user_id, None)
        logger.info("ws_disconnect", user_id=user_id, total=len(self._active))

    async def send_personal(self, user_id: str, message: dict) -> None:
        ws = self._active.get(user_id)
        if ws:
            await ws.send_json(message)

    async def broadcast(self, message: dict, *, exclude: set[str] | None = None) -> None:
        exclude = exclude or set()
        for uid, ws in self._active.items():
            if uid not in exclude:
                await ws.send_json(message)


manager = ConnectionManager()
```

## 3. 연결 시 인증

```python
from fastapi import WebSocket, WebSocketDisconnect, Query, status

async def get_ws_user(ws: WebSocket, token: str = Query(...)) -> str:
    """Validate token from query param: ws://host/ws?token=xxx"""
    try:
        payload = decode_access_token(token)  # project-specific
        return payload["sub"]
    except Exception:
        await ws.close(code=status.WS_1008_POLICY_VIOLATION)
        raise WebSocketDisconnect(code=status.WS_1008_POLICY_VIOLATION)


@app.websocket("/ws")
async def ws_endpoint(ws: WebSocket, token: str = Query(...)):
    user_id = await get_ws_user(ws, token)
    await manager.connect(user_id, ws)
    try:
        while True:
            data = await ws.receive_json()
            await handle_message(user_id, data)
    except WebSocketDisconnect:
        manager.disconnect(user_id)
```

## 4. Room / Channel 패턴

```python
from collections import defaultdict

class RoomManager:
    def __init__(self) -> None:
        self._rooms: dict[str, set[str]] = defaultdict(set)  # room -> {user_ids}
        self._connections: dict[str, WebSocket] = {}          # user_id -> ws

    async def connect(self, user_id: str, ws: WebSocket) -> None:
        await ws.accept()
        self._connections[user_id] = ws

    def disconnect(self, user_id: str) -> None:
        self._connections.pop(user_id, None)
        for members in self._rooms.values():
            members.discard(user_id)

    def join(self, user_id: str, room: str) -> None:
        self._rooms[room].add(user_id)

    def leave(self, user_id: str, room: str) -> None:
        self._rooms[room].discard(user_id)

    async def broadcast_to_room(self, room: str, message: dict, *, exclude: str | None = None) -> None:
        for uid in self._rooms.get(room, set()):
            if uid != exclude and uid in self._connections:
                await self._connections[uid].send_json(message)
```

## 5. Heartbeat / Ping-Pong

```python
import asyncio
from fastapi import WebSocket, WebSocketDisconnect

HEARTBEAT_INTERVAL = 30  # seconds

async def heartbeat(ws: WebSocket) -> None:
    """Send periodic pings; starlette handles pong automatically."""
    try:
        while True:
            await asyncio.sleep(HEARTBEAT_INTERVAL)
            await ws.send_json({"type": "ping"})
    except Exception:
        pass  # connection closed


@app.websocket("/ws")
async def ws_with_heartbeat(ws: WebSocket, token: str = Query(...)):
    user_id = await get_ws_user(ws, token)
    await manager.connect(user_id, ws)
    hb_task = asyncio.create_task(heartbeat(ws))
    try:
        while True:
            data = await ws.receive_json()
            if data.get("type") == "pong":
                continue
            await handle_message(user_id, data)
    except WebSocketDisconnect:
        manager.disconnect(user_id)
    finally:
        hb_task.cancel()
```

## 6. 에러 처리 및 연결 해제

```python
from starlette.websockets import WebSocketState

async def safe_close(ws: WebSocket, code: int = 1000, reason: str = "") -> None:
    if ws.client_state == WebSocketState.CONNECTED:
        await ws.close(code=code, reason=reason)

# Common close codes:
# 1000 - Normal closure
# 1001 - Going away
# 1003 - Unsupported data
# 1008 - Policy violation (auth failure)
# 1011 - Internal error
```

## 7. 다중 인스턴스 확장을 위한 Redis Pub/Sub

```python
import redis.asyncio as aioredis
import json, asyncio

class RedisPubSubBridge:
    """Bridges local ConnectionManager with Redis for horizontal scaling."""

    def __init__(self, redis_url: str, channel: str = "ws:broadcast") -> None:
        self._redis = aioredis.from_url(redis_url)
        self._channel = channel

    async def publish(self, message: dict) -> None:
        await self._redis.publish(self._channel, json.dumps(message))

    async def subscribe_loop(self, manager: ConnectionManager) -> None:
        pubsub = self._redis.pubsub()
        await pubsub.subscribe(self._channel)
        async for msg in pubsub.listen():
            if msg["type"] == "message":
                data = json.loads(msg["data"])
                target = data.pop("_target_user", None)
                if target:
                    await manager.send_personal(target, data)
                else:
                    await manager.broadcast(data)

# Start in lifespan:
# asyncio.create_task(bridge.subscribe_loop(manager))
```
