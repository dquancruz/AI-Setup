---
name: iot-backend
description: Specialized patterns for IoT backends on Raspberry Pi with GPIO, FastAPI, async MongoDB, and WebSockets. Use when working with hardware, limit switches, bowling scoring, or any edge-device integration.
argument-hint: --component gpio|scoring|websocket
tools: [Read, Write, Edit, Bash]
tier: extended
---

# IoT Backend Best Practices

## Context
Backend for the semiautomatic bowling alley on Raspberry Pi. Stack: FastAPI + async MongoDB + RPi.GPIO + WebSocket.

## GPIO: Debounce (50ms standard)
```python
async def handle_limit_switch(pin_number: int):
    initial_state = GPIO.read(pin_number)
    await asyncio.sleep(0.05)  # 50ms debounce
    if GPIO.read(pin_number) == initial_state:
        await process_switch_event(pin_number, initial_state)
```

## Async MongoDB (motor)
```python
from motor.motor_asyncio import AsyncIOMotorClient

client = AsyncIOMotorClient(os.getenv("MONGODB_URL"))
db = client.bowling

async def save_frame(frame: dict):
    await db.frames.insert_one(frame)
```

## FastAPI + real-time WebSocket
```python
@app.websocket("/ws/game/{game_id}")
async def game_socket(websocket: WebSocket, game_id: str):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_json()
            await manager.broadcast(game_id, data)
    except WebSocketDisconnect:
        manager.disconnect(websocket)
```

## Testing on the Pi vs. mocks
- Unit tests: mock GPIO with `unittest.mock`
- Integration tests: run on a real Pi with hardware connected
- Never mock MongoDB in integration tests

## Critical rules
- GPIO cleanup in finally/signal handlers
- Timeout on hardware operations (never wait indefinitely)
- Structured logs for remote debugging
