"""
Relay from the voice channel to Agentforce: one Agent API session per call.

Agentforce stays the brain. Every caller turn goes through the same Agent API path the eval
harness uses (`src/agent_client.py`, bypassUser=True, so actions run as the agent user under
its least-privilege permset). Nova only speaks what comes back.
"""
import asyncio
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src"))
from agent_client import client_from_env  # noqa: E402

# Spoken when Agentforce returns no text (e.g. a platform Escalate) or the API call fails.
FALLBACK_REPLY = ("I'm sorry, I'm having trouble reaching our system right now. "
                  "Please try again in a moment.")


def extract_text(messages):
    """Same rule as run_eval.py: only Inform messages carry text for the caller."""
    return "\n".join(m["message"] for m in messages if m.get("type") == "Inform" and m.get("message"))


class KeyburnRelay:
    def __init__(self):
        self._client = client_from_env()
        self._lock = asyncio.Lock()  # Agent API turns are sequenced; never overlap them
        self.greeting = ""
        self.turns = []  # {"utterance", "reply", "seconds", "non_text"} per caller turn

    async def start(self):
        messages = await asyncio.to_thread(self._client.start_session, True)
        self.greeting = extract_text(messages)
        return self.greeting

    async def ask(self, utterance):
        async with self._lock:
            t0 = time.monotonic()
            try:
                messages = await asyncio.to_thread(self._client.send_message, utterance)
                reply = extract_text(messages)
                non_text = [m.get("type") for m in messages if m.get("type") != "Inform"]
            except Exception as e:  # never let a relay failure leave the caller in silence
                print(f"[relay] Agent API error: {e!r}", file=sys.stderr)
                reply, non_text = "", ["error"]
            seconds = time.monotonic() - t0
            self.turns.append({"utterance": utterance, "reply": reply,
                               "seconds": round(seconds, 2), "non_text": non_text})
            return reply or FALLBACK_REPLY

    async def close(self):
        await asyncio.to_thread(self._client.end_session)
