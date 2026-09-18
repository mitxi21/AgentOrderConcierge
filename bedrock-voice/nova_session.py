"""
One Nova 2 Sonic bidirectional stream = one call. Nova is the ears and mouth only.

Events reported through `on_event(kind, data)`:
  "text"        {"role", "stage" (SPECULATIVE/FINAL/?), "text"}  transcript line
  "audio"       bytes, 24 kHz mono s16le                          speech to play
  "interrupted" None                                              barge-in: flush playback
  "tool_start"  {"utterance", "model_arg"}                        relay to Agentforce began
  "tool_blocked" {"attempted"}                                    Nova called the tool with no
                                                                  new caller speech: not relayed
  "tool_end"    {"utterance", "reply", "seconds"}                 relay finished
  "content_end" {"contentType", "role", "stopReason"}             turn boundaries
  "error"       str
"""
import asyncio
import base64
import json
import os
import time
import uuid

from smithy_http.aio.crt import AWSCRTHTTPClient

from aws_sdk_bedrock_runtime.client import AsyncBedrockRuntimeClient
from aws_sdk_bedrock_runtime.config import AsyncBedrockRuntimeConfig
from aws_sdk_bedrock_runtime.models import (
    BidirectionalInputPayloadPart,
    InvokeModelWithBidirectionalStreamInputChunk,
    InvokeModelWithBidirectionalStreamOperationInput,
    InvokeModelWithBidirectionalStreamOutputChunk,
)

MODEL_ID = "amazon.nova-2-sonic-v1:0"
TOOL_NAME = "ask_keyburn_agent"
CALL_CONNECTED = "[call connected]"

SYSTEM_PROMPT = """You are the voice of Keyburn's customer service line on a phone call. \
A separate Keyburn service agent does all the thinking; you are only its voice.
- For everything the caller says (questions, answers, yes or no, corrections, goodbyes), call \
the ask_keyburn_agent tool with the caller's exact words.
- The tool returns say_to_caller: a message FOR THE CALLER, written by the service agent. Say it \
to the caller, word for word. It is often a question for the caller, such as "is that right?". \
You never answer it yourself: say it aloud, then stay silent until the caller answers, and only \
then call the tool again with the caller's answer.
- Never answer from your own knowledge, and never speak for the caller. Never add, drop or \
change a fact, number, date, email address or case number from say_to_caller, and never add \
questions of your own.
- Say nothing of your own before or after the reply: no fillers such as "One moment". The \
phone line plays its own hold sound while the tool runs.
- When you receive "[call connected]", do not call the tool. Say exactly this greeting: {greeting}"""

TOOL_SPEC = {"toolSpec": {
    "name": TOOL_NAME,
    "description": "Send the caller's words to the Keyburn customer service agent and get the "
                   "reply to speak. Use it for every caller turn.",
    "inputSchema": {"json": json.dumps({
        "type": "object",
        "properties": {"utterance": {"type": "string",
                                     "description": "What the caller said, verbatim."}},
        "required": ["utterance"]})},
}}


def _ev(name, body):
    return {"event": {name: body}}


class NovaSession:
    def __init__(self, tool_handler, on_event, greeting, voice_id="matthew", region=None):
        self._tool_handler = tool_handler  # async (utterance) -> reply text
        self._on_event = on_event          # async (kind, data)
        self._greeting = greeting
        self._voice_id = voice_id
        self._region = region or os.environ.get("AWS_REGION", "eu-north-1")
        self._prompt = str(uuid.uuid4())
        self._audio_content = str(uuid.uuid4())
        self._send_lock = asyncio.Lock()
        self._stage = "?"
        self._roles = {}
        self._heard = []  # caller transcript not yet relayed: the ONLY source of relayed words
        self._last_typed = None
        self._last_reply = ""
        self._tasks = []
        self._client = self._stream = None
        self.closed = False

    # ---- lifecycle ----
    async def start(self):
        config = await AsyncBedrockRuntimeConfig.resolve(region=self._region,
                                                         transport=AWSCRTHTTPClient())
        self._client = AsyncBedrockRuntimeClient(config=config)
        self._stream = await self._client.invoke_model_with_bidirectional_stream(
            InvokeModelWithBidirectionalStreamOperationInput(model_id=MODEL_ID))
        await self._send(_ev("sessionStart", {
            "inferenceConfiguration": {"maxTokens": 1024, "topP": 0.9, "temperature": 0.3},
            # LOW = end the caller's turn after 2.0 s of silence (default 1.75 s). Callers pause
            # between an order number and an email; a shorter wait split one turn into two.
            "turnDetectionConfiguration": {"endpointingSensitivity": "LOW"}}))
        await self._send(_ev("promptStart", {
            "promptName": self._prompt,
            "textOutputConfiguration": {"mediaType": "text/plain"},
            "audioOutputConfiguration": {"mediaType": "audio/lpcm", "sampleRateHertz": 24000,
                                         "sampleSizeBits": 16, "channelCount": 1,
                                         "voiceId": self._voice_id, "encoding": "base64",
                                         "audioType": "SPEECH"},
            "toolUseOutputConfiguration": {"mediaType": "application/json"},
            "toolConfiguration": {"tools": [TOOL_SPEC]}}))
        await self._text_block("SYSTEM", SYSTEM_PROMPT.format(greeting=self._greeting),
                               interactive=False)
        # The mic stays open for the whole call as one audio content block.
        await self._send(_ev("contentStart", {
            "promptName": self._prompt, "contentName": self._audio_content, "type": "AUDIO",
            "interactive": True, "role": "USER",
            "audioInputConfiguration": {"mediaType": "audio/lpcm", "sampleRateHertz": 16000,
                                        "sampleSizeBits": 16, "channelCount": 1,
                                        "audioType": "SPEECH", "encoding": "base64"}}))
        self._tasks.append(asyncio.create_task(self._receive()))

    async def close(self):
        if self.closed:
            return
        self.closed = True
        try:
            for e in (_ev("contentEnd", {"promptName": self._prompt,
                                         "contentName": self._audio_content}),
                      _ev("promptEnd", {"promptName": self._prompt}),
                      _ev("sessionEnd", {})):
                await self._send(e)
            await self._stream.input_stream.close()
        except Exception:
            pass
        for t in self._tasks:
            t.cancel()

    # ---- input ----
    async def send_audio(self, pcm16k):
        """Caller audio: 16 kHz mono signed 16-bit PCM."""
        await self._send(_ev("audioInput", {"promptName": self._prompt,
                                            "contentName": self._audio_content,
                                            "content": base64.b64encode(pcm16k).decode()}))

    async def send_text(self, text):
        """A typed caller turn (tests, or the page's text box)."""
        if text != CALL_CONNECTED:
            self._heard.append(text)
            self._last_typed = text  # Nova may echo it back as a USER transcript
        await self._text_block("USER", text, interactive=True)

    async def _text_block(self, role, text, interactive):
        c = str(uuid.uuid4())
        await self._send(_ev("contentStart", {
            "promptName": self._prompt, "contentName": c, "type": "TEXT", "role": role,
            "interactive": interactive, "textInputConfiguration": {"mediaType": "text/plain"}}))
        await self._send(_ev("textInput", {"promptName": self._prompt, "contentName": c,
                                           "content": text}))
        await self._send(_ev("contentEnd", {"promptName": self._prompt, "contentName": c}))

    async def _send(self, event):
        if self.closed and "sessionEnd" not in event["event"] and "promptEnd" not in event["event"] \
                and "contentEnd" not in event["event"]:
            return
        async with self._send_lock:
            await self._stream.input_stream.send(InvokeModelWithBidirectionalStreamInputChunk(
                value=BidirectionalInputPayloadPart(bytes_=json.dumps(event).encode("utf-8"))))

    # ---- output ----
    async def _receive(self):
        try:
            _, output = await self._stream.await_output()
            async for item in output:
                if not isinstance(item, InvokeModelWithBidirectionalStreamOutputChunk):
                    msg = getattr(getattr(item, "value", None), "message", None) or type(item).__name__
                    await self._on_event("error", f"Nova stream error: {msg}")
                    return
                if item.value.bytes_:
                    await self._handle(json.loads(item.value.bytes_).get("event", {}))
        except asyncio.CancelledError:
            raise
        except Exception as e:
            if not self.closed:
                await self._on_event("error", f"Nova stream ended: {e!r}")

    async def _handle(self, e):
        if "contentStart" in e:
            cs = e["contentStart"]
            self._roles[cs.get("contentId")] = cs.get("role")
            extra = json.loads(cs.get("additionalModelFields") or "{}")
            self._stage = extra.get("generationStage", self._stage)
        elif "textOutput" in e:
            t = e["textOutput"]
            content = t.get("content", "")
            if '"interrupted"' in content and "true" in content:
                await self._on_event("interrupted", None)
                return
            if t.get("role") == "USER" and self._stage != "SPECULATIVE" and content.strip() \
                    and content.strip() not in (self._last_typed, CALL_CONNECTED):
                self._heard.append(content.strip())
            await self._on_event("text", {"role": t.get("role"), "stage": self._stage,
                                          "text": content})
        elif "audioOutput" in e:
            await self._on_event("audio", base64.b64decode(e["audioOutput"]["content"]))
        elif "toolUse" in e:
            tu = e["toolUse"]
            # Relay in the background so Nova's output keeps flowing (fillers) meanwhile.
            self._tasks.append(asyncio.create_task(self._run_tool(tu)))
        elif "contentEnd" in e:
            ce = e["contentEnd"]
            await self._on_event("content_end", {"contentType": ce.get("type"),
                                                 "role": self._roles.get(ce.get("contentId")),
                                                 "stopReason": ce.get("stopReason")})

    async def _run_tool(self, tu):
        try:
            model_arg = json.loads(tu.get("content") or "{}").get("utterance", "")
        except ValueError:
            model_arg = tu.get("content") or ""
        # Guardrail: relay what the caller was HEARD saying, never the model's tool argument.
        # In testing, Nova invented a caller "yes" to the identity confirm-back and relayed it.
        if not self._heard:
            await asyncio.sleep(0.5)  # the transcript normally precedes toolUse; allow a race
        utterance = " ".join(self._heard)
        self._heard.clear()
        if not utterance:
            await self._on_event("tool_blocked", {"attempted": model_arg})
            await self._tool_result(tu["toolUseId"], {
                "say_to_caller": self._last_reply,
                "note": "NOT SENT: the caller has not spoken since the last message, so there is "
                        "nothing to relay. Do not call the tool again. If you have not yet said "
                        "say_to_caller to the caller, say it now, then wait silently for the "
                        "caller to speak."})
            return
        await self._on_event("tool_start", {"utterance": utterance, "model_arg": model_arg})
        t0 = time.monotonic()
        reply = await self._tool_handler(utterance)
        seconds = round(time.monotonic() - t0, 2)
        await self._on_event("tool_end", {"utterance": utterance, "reply": reply,
                                          "seconds": seconds})
        self._last_reply = reply
        await self._tool_result(tu["toolUseId"], {"say_to_caller": reply})

    async def _tool_result(self, tool_use_id, result):
        c = str(uuid.uuid4())
        await self._send(_ev("contentStart", {
            "promptName": self._prompt, "contentName": c, "interactive": False,
            "type": "TOOL", "role": "TOOL",
            "toolResultInputConfiguration": {"toolUseId": tool_use_id, "type": "TEXT",
                                             "textInputConfiguration": {"mediaType": "text/plain"}}}))
        await self._send(_ev("toolResult", {"promptName": self._prompt, "contentName": c,
                                            "content": json.dumps(result)}))
        await self._send(_ev("contentEnd", {"promptName": self._prompt, "contentName": c}))
