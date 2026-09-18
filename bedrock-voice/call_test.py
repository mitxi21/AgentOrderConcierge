"""
Typed end-to-end call: caller text -> Nova 2 Sonic -> ask_keyburn_agent -> Agentforce (Agent API)
-> Nova speaks the reply. No mic needed; silence is streamed as the open mic.

    . .\\load_secrets.ps1          # repo root
    py -3.12 bedrock-voice\\call_test.py [out.wav]

Prints the transcript and per-turn latency: caller turn -> tool call -> Agentforce reply ->
first audio byte heard.
"""
import asyncio
import sys
import time
import wave

from nova_session import CALL_CONNECTED, NovaSession
from relay import KeyburnRelay

CALLER_TURNS = [
    CALL_CONNECTED,
    "Hi, what's the status of my order 1042? My email is jane.doe@example.com.",
    "Yes, that's right.",
]
TURN_TIMEOUT = 60


async def main(out_wav):
    relay = KeyburnRelay()
    t0 = time.monotonic()
    log = lambda msg: print(f"[{time.monotonic() - t0:5.1f}s] {msg}", flush=True)

    greeting = await relay.start()
    log(f"Agentforce session started; greeting: {greeting!r}")

    audio = bytearray()
    turn = {}
    turn_done = asyncio.Event()
    stats = []

    async def on_event(kind, data):
        now = time.monotonic()
        if kind == "audio":
            if "first_audio" not in turn:
                turn["first_audio"] = now
                turn["audio_bytes"] = 0
            turn["audio_bytes"] += len(data)
            audio.extend(data)
        elif kind == "text":
            if data["role"] == "ASSISTANT":
                log(f"NOVA [{data['stage']}]: {data['text']}")
        elif kind == "tool_start":
            turn["tool_start"] = now
            log(f"-> Agentforce: {data['utterance']!r}")
        elif kind == "tool_end":
            turn["tool_end"] = now
            log(f"<- Agentforce ({data['seconds']}s): {data['reply']!r}")
        elif kind == "content_end":
            if data["contentType"] == "AUDIO":
                log(f"(audio segment end: {data['stopReason']})")
                # Nova's audio arrives in segments (PARTIAL_TURN); END_TURN closes the reply.
                # The answering turn follows the relay, or it's the greeting (no relay).
                if data["stopReason"] == "END_TURN" and (
                        "tool_end" in turn or turn.get("text") == CALL_CONNECTED):
                    turn_done.set()
        elif kind == "interrupted":
            log("(barge-in)")
        elif kind == "error":
            log(f"ERROR {data}")
            turn_done.set()

    nova = NovaSession(relay.ask, on_event, greeting)
    await nova.start()
    log("Nova stream opened")

    async def mic_silence():
        chunk = bytes(512)
        while not nova.closed:
            await nova.send_audio(chunk)
            await asyncio.sleep(0.016)

    mic = asyncio.create_task(mic_silence())
    try:
        for text in CALLER_TURNS:
            turn.clear()
            turn_done.clear()
            turn.update(text=text, start=time.monotonic())
            log(f"CALLER: {text}")
            await nova.send_text(text)
            try:
                await asyncio.wait_for(turn_done.wait(), TURN_TIMEOUT)
            except asyncio.TimeoutError:
                log(f"turn timed out after {TURN_TIMEOUT}s")
            s = turn["start"]
            stats.append({
                "caller": text,
                "to_tool_call": round(turn["tool_start"] - s, 2) if "tool_start" in turn else None,
                "agentforce": round(turn["tool_end"] - turn["tool_start"], 2) if "tool_end" in turn else None,
                "to_first_audio": round(turn["first_audio"] - s, 2) if "first_audio" in turn else None,
                "audio_seconds": round(turn.get("audio_bytes", 0) / 48000, 1),
            })
            # Nova generates faster than real time: let the reply "play out" (24 kHz s16 = 48000
            # bytes/s) before the caller speaks again, or the next turn is a barge-in.
            if "first_audio" in turn:
                played_until = turn["first_audio"] + turn["audio_bytes"] / 48000
                await asyncio.sleep(max(0.0, played_until - time.monotonic()))
            await asyncio.sleep(1.0)  # caller pause
    finally:
        await nova.close()
        mic.cancel()
        await relay.close()

    with wave.open(out_wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(24000)
        w.writeframes(bytes(audio))

    print("\nPer-turn latency (seconds):")
    print(f"{'caller turn':<60} {'->tool':>7} {'agentforce':>11} {'->1st audio':>12} {'spoken':>7}")
    for st in stats:
        fmt = lambda v: "-" if v is None else f"{v:.2f}"
        print(f"{st['caller'][:60]:<60} {fmt(st['to_tool_call']):>7} "
              f"{fmt(st['agentforce']):>11} {fmt(st['to_first_audio']):>12} {st['audio_seconds']:>6}s")
    print(f"\naudio: {len(audio) / 48000:.1f}s -> {out_wav}")
    print("relay turns:", relay.turns)


if __name__ == "__main__":
    asyncio.run(main(sys.argv[1] if len(sys.argv) > 1 else "call_test.wav"))
