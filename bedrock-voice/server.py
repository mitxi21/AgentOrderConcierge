"""
Phase 11 call page backend: browser mic <-> this server <-> Nova 2 Sonic, with every caller turn
relayed to Agentforce. One WebSocket = one call = one Nova stream + one Agent API session.

    . .\\load_secrets.ps1          # repo root
    py -3.12 bedrock-voice\\server.py
    # open http://localhost:8765

Protocol on /ws:
  browser -> server   binary: caller audio, 16 kHz mono s16le
                      text:   {"type": "text", "text": "..."} typed turn | {"type": "hangup"}
  server -> browser   binary: Nova speech, 24 kHz mono s16le
                      text:   {"type": <NovaSession event kind> | "ready" | "ended", ...}

Binds to localhost only: the page has no auth of its own, and the relay runs with the
eval harness's Agent API credentials.
"""
import asyncio
import json
import os
import sys
import time

from aiohttp import WSMsgType, web

from nova_session import CALL_CONNECTED, NovaSession
from relay import KeyburnRelay

HERE = os.path.dirname(os.path.abspath(__file__))
HOST, PORT = "127.0.0.1", int(os.environ.get("VOICE_PAGE_PORT", "8765"))
LOG_DIR = os.path.join(HERE, "call_logs")


async def index(_request):
    return web.FileResponse(os.path.join(HERE, "static", "index.html"))


async def call(request):
    ws = web.WebSocketResponse(max_msg_size=4 * 1024 * 1024)
    await ws.prepare(request)
    started = time.time()
    relay = KeyburnRelay()
    nova = None
    blocked = []

    async def send_json(obj):
        if not ws.closed:
            await ws.send_str(json.dumps(obj))

    async def on_event(kind, data):
        if kind == "tool_blocked":
            blocked.append({"at": round(time.time() - started, 1), **data})
        if ws.closed:
            return
        if kind == "audio":
            await ws.send_bytes(data)
        elif kind == "error":
            await send_json({"type": "error", "message": data})
        else:
            await send_json({"type": kind, **(data or {})})

    try:
        greeting = await relay.start()
        nova = NovaSession(relay.ask, on_event, greeting)
        await nova.start()
        await send_json({"type": "ready", "greeting": greeting})
        await nova.send_text(CALL_CONNECTED)

        async for msg in ws:
            if msg.type == WSMsgType.BINARY:
                await nova.send_audio(msg.data)
            elif msg.type == WSMsgType.TEXT:
                m = json.loads(msg.data)
                if m.get("type") == "text" and m.get("text", "").strip():
                    await nova.send_text(m["text"].strip())
                elif m.get("type") == "hangup":
                    break
            elif msg.type == WSMsgType.ERROR:
                break
    except Exception as e:
        print(f"[call] failed: {e!r}", file=sys.stderr)
        await send_json({"type": "error", "message": "The call could not be connected."})
    finally:
        if nova:
            await nova.close()
        try:
            await relay.close()
        except Exception:
            pass
        _save_log(started, relay.turns, blocked)
        await send_json({"type": "ended"})
        await ws.close()
    return ws


def _save_log(started, turns, blocked):
    """Per-call relay log with Agentforce latency per turn (runbook step 6), plus any tool calls
    blocked because the caller hadn't said anything (Nova trying to speak for the caller)."""
    if not turns and not blocked:
        return
    os.makedirs(LOG_DIR, exist_ok=True)
    name = time.strftime("call_%Y%m%d_%H%M%S.json", time.localtime(started))
    with open(os.path.join(LOG_DIR, name), "w", encoding="utf-8") as f:
        json.dump({"started": time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(started)),
                   "turns": turns, "blocked_relays": blocked}, f, indent=2)
    print(f"[call] {len(turns)} turns, {len(blocked)} blocked -> call_logs/{name}", flush=True)


def main():
    app = web.Application()
    app.router.add_get("/", index)
    app.router.add_get("/ws", call)
    print(f"Keyburn call page: http://localhost:{PORT}")
    web.run_app(app, host=HOST, port=PORT, print=None)


if __name__ == "__main__":
    main()
