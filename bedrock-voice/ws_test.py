"""
Headless check of the call page's server path with real audio: plays caller WAVs (16 kHz mono
s16) into /ws in real time, as the browser would, and prints what the page would receive.
Doubles as a demo-day preflight.

    py -3.12 bedrock-voice\\server.py            # in another shell, secrets loaded
    py -3.12 bedrock-voice\\ws_test.py caller_0.wav caller_1.wav
"""
import asyncio
import json
import sys
import time
import wave

import aiohttp

URL = "ws://127.0.0.1:8765/ws"
CHUNK = 512  # samples = 32 ms at 16 kHz
TURN_TIMEOUT = 60


async def main(wavs):
    t0 = time.monotonic()
    log = lambda msg: print(f"[{time.monotonic() - t0:5.1f}s] {msg}", flush=True)
    state = {"audio_bytes": 0, "first_audio": None, "tool_end": False}
    turn_done = asyncio.Event()
    speaking = asyncio.Event()  # set while a caller WAV is being played in
    caller_turn_start = {}

    async with aiohttp.ClientSession() as http, http.ws_connect(URL) as ws:

        async def mic():
            silence = bytes(CHUNK * 2)
            while not ws.closed:
                if not speaking.is_set():
                    await ws.send_bytes(silence)
                await asyncio.sleep(CHUNK / 16000)

        async def receive():
            async for msg in ws:
                if msg.type == aiohttp.WSMsgType.BINARY:
                    if state["first_audio"] is None:
                        state["first_audio"] = time.monotonic()
                        if "t" in caller_turn_start:
                            log(f"(first audio {state['first_audio'] - caller_turn_start['t']:.2f}s "
                                "after caller stopped)")
                    state["audio_bytes"] += len(msg.data)
                    continue
                m = json.loads(msg.data)
                k = m["type"]
                if k == "text":
                    if m["role"] == "USER" or m["stage"] == "SPECULATIVE":
                        log(f"text {m['role']}/{m['stage']}: {m['text']}")
                elif k == "content_end":
                    if m["contentType"] == "AUDIO" and m["stopReason"] == "END_TURN" and (
                            state["tool_end"] or not caller_turn_start):
                        turn_done.set()
                elif k == "tool_end":
                    state["tool_end"] = True
                    log(f"tool_end ({m['seconds']}s): {m['reply']}")
                elif k in ("tool_start", "tool_blocked", "ready", "error", "ended", "interrupted"):
                    log(f"{k}: {json.dumps({x: y for x, y in m.items() if x != 'type'})}")
                    if k in ("error", "ended"):
                        turn_done.set()

        async def wait_turn():
            await asyncio.wait_for(turn_done.wait(), TURN_TIMEOUT)
            if state["first_audio"]:
                end = state["first_audio"] + state["audio_bytes"] / 48000
                await asyncio.sleep(max(0.0, end - time.monotonic()) + 0.8)

        tasks = [asyncio.create_task(mic()), asyncio.create_task(receive())]
        await wait_turn()  # greeting
        for path in wavs:
            turn_done.clear()
            state.update(audio_bytes=0, first_audio=None, tool_end=False)
            with wave.open(path, "rb") as w:
                assert w.getframerate() == 16000 and w.getnchannels() == 1 and w.getsampwidth() == 2
                pcm = w.readframes(w.getnframes())
            log(f"CALLER speaks {path} ({len(pcm) / 32000:.1f}s)")
            speaking.set()
            for i in range(0, len(pcm), CHUNK * 2):
                await ws.send_bytes(pcm[i:i + CHUNK * 2])
                await asyncio.sleep(CHUNK / 16000)
            speaking.clear()
            caller_turn_start["t"] = time.monotonic()
            try:
                await wait_turn()
            except asyncio.TimeoutError:
                log("turn timed out")
        await ws.send_str(json.dumps({"type": "hangup"}))
        await asyncio.sleep(1.5)
        for t in tasks:
            t.cancel()


if __name__ == "__main__":
    asyncio.run(main(sys.argv[1:]))
