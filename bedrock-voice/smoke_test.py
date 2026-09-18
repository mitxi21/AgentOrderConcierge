"""
Phase 11 smoke test: open a Nova 2 Sonic stream and check the relay-tool round trip.

Proves, in one run: IAM auth + region + model access; that Nova calls
`ask_keyburn_agent` for a customer request instead of answering itself; and that
it speaks a tool result. The tool returns a STUB here, so no Salesforce call.

    . .\\load_secrets.ps1          # repo root
    py -3.12 bedrock-voice\\smoke_test.py [out.wav]

Needs Python 3.12+ and `aws-sdk-bedrock-runtime[awscrt]`. Credentials come from
AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (IAM keys; a Bedrock API key can't
open this stream).
"""
import asyncio
import base64
import json
import os
import sys
import time
import uuid
import wave

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
REGION = os.environ.get("AWS_REGION", "eu-north-1")
TIMEOUT_SECONDS = 45

SYSTEM_PROMPT = (
    "You are the voice of Keyburn customer service on a phone call. You do not answer "
    "customer questions yourself. For every caller request, call the ask_keyburn_agent tool "
    "with the caller's words, then say the tool's reply to the caller naturally, without "
    "adding facts. Keep your own words to short fillers like 'let me check that'."
)
CALLER_TURN = "Hi, what's the status of order 1042? My email is jane.doe@example.com."
STUB_REPLY = (
    "Order 1042 for jane.doe@example.com has shipped and should arrive on "
    "September twenty-fourth. (stub reply, not from Salesforce)"
)

TOOL_SPEC = {
    "toolSpec": {
        "name": "ask_keyburn_agent",
        "description": "Send the caller's words to the Keyburn customer service agent and get "
                       "the reply to speak back. Use it for every customer request.",
        "inputSchema": {"json": json.dumps({
            "type": "object",
            "properties": {"utterance": {"type": "string",
                                         "description": "What the caller said, verbatim."}},
            "required": ["utterance"],
        })},
    }
}


def ev(name, body):
    return {"event": {name: body}}


async def send(stream, event):
    await stream.input_stream.send(InvokeModelWithBidirectionalStreamInputChunk(
        value=BidirectionalInputPayloadPart(bytes_=json.dumps(event).encode("utf-8"))))


async def main(out_wav):
    config = await AsyncBedrockRuntimeConfig.resolve(region=REGION, transport=AWSCRTHTTPClient())
    prompt, system_c, user_c, audio_c = (str(uuid.uuid4()) for _ in range(4))
    t0 = time.monotonic()
    log = lambda msg: print(f"[{time.monotonic() - t0:5.1f}s] {msg}")
    audio_out = bytearray()
    tool_calls, spoken = [], []
    stage = ["?"]
    done = asyncio.Event()

    async with AsyncBedrockRuntimeClient(config=config) as client:
        stream = await client.invoke_model_with_bidirectional_stream(
            InvokeModelWithBidirectionalStreamOperationInput(model_id=MODEL_ID))
        log(f"stream opened ({MODEL_ID}, {REGION})")

        async def silence():
            # A live call keeps the mic open; Nova expects continuous audio input.
            chunk = base64.b64encode(bytes(512)).decode()
            while not done.is_set():
                await send(stream, ev("audioInput", {"promptName": prompt, "contentName": audio_c,
                                                     "content": chunk}))
                await asyncio.sleep(0.016)

        async def receive():
            _, output = await stream.await_output()
            async for item in output:
                if not isinstance(item, InvokeModelWithBidirectionalStreamOutputChunk):
                    raise RuntimeError(f"stream error: {type(item).__name__}: "
                                       f"{getattr(getattr(item, 'value', None), 'message', item)}")
                if not item.value.bytes_:
                    continue
                e = json.loads(item.value.bytes_).get("event", {})
                if "contentStart" in e:
                    # Assistant text arrives twice: SPECULATIVE (while speaking), then FINAL.
                    extra = json.loads(e["contentStart"].get("additionalModelFields") or "{}")
                    stage[0] = extra.get("generationStage", stage[0])
                elif "textOutput" in e:
                    t = e["textOutput"]
                    log(f"text [{t.get('role')}/{stage[0]}]: {t.get('content')}")
                    if t.get("role") == "ASSISTANT" and stage[0] == "FINAL":
                        spoken.append(t.get("content", ""))
                        # No completionEnd arrives while the mic stays open, so stop on the
                        # first final reply after the tool round trip.
                        if tool_calls and audio_out:
                            done.set()
                            return
                elif "audioOutput" in e:
                    audio_out.extend(base64.b64decode(e["audioOutput"]["content"]))
                elif "toolUse" in e:
                    tu = e["toolUse"]
                    log(f"toolUse {tu['toolName']}: {tu.get('content')}")
                    tool_calls.append(tu)
                    await answer_tool(tu["toolUseId"])
                elif "completionEnd" in e:
                    log("completionEnd")

        async def answer_tool(tool_use_id):
            c = str(uuid.uuid4())
            await send(stream, ev("contentStart", {
                "promptName": prompt, "contentName": c, "interactive": False,
                "type": "TOOL", "role": "TOOL",
                "toolResultInputConfiguration": {"toolUseId": tool_use_id, "type": "TEXT",
                                                 "textInputConfiguration": {"mediaType": "text/plain"}}}))
            await send(stream, ev("toolResult", {"promptName": prompt, "contentName": c,
                                                 "content": json.dumps({"reply": STUB_REPLY})}))
            await send(stream, ev("contentEnd", {"promptName": prompt, "contentName": c}))
            log("toolResult sent (stub)")

        async with stream:
            await send(stream, ev("sessionStart", {"inferenceConfiguration": {
                "maxTokens": 1024, "topP": 0.9, "temperature": 0.7}}))
            await send(stream, ev("promptStart", {
                "promptName": prompt,
                "textOutputConfiguration": {"mediaType": "text/plain"},
                "audioOutputConfiguration": {"mediaType": "audio/lpcm", "sampleRateHertz": 24000,
                                             "sampleSizeBits": 16, "channelCount": 1,
                                             "voiceId": "matthew", "encoding": "base64",
                                             "audioType": "SPEECH"},
                "toolUseOutputConfiguration": {"mediaType": "application/json"},
                "toolConfiguration": {"tools": [TOOL_SPEC]}}))
            for c, role, text, interactive in ((system_c, "SYSTEM", SYSTEM_PROMPT, False),
                                               (user_c, "USER", CALLER_TURN, True)):
                await send(stream, ev("contentStart", {
                    "promptName": prompt, "contentName": c, "type": "TEXT", "role": role,
                    "interactive": interactive, "textInputConfiguration": {"mediaType": "text/plain"}}))
                await send(stream, ev("textInput", {"promptName": prompt, "contentName": c,
                                                    "content": text}))
                await send(stream, ev("contentEnd", {"promptName": prompt, "contentName": c}))
                if role == "SYSTEM":
                    await send(stream, ev("contentStart", {
                        "promptName": prompt, "contentName": audio_c, "type": "AUDIO",
                        "interactive": True, "role": "USER",
                        "audioInputConfiguration": {"mediaType": "audio/lpcm", "sampleRateHertz": 16000,
                                                    "sampleSizeBits": 16, "channelCount": 1,
                                                    "audioType": "SPEECH", "encoding": "base64"}}))
            log(f"caller (typed): {CALLER_TURN}")

            mic = asyncio.create_task(silence())
            try:
                await asyncio.wait_for(receive(), TIMEOUT_SECONDS)
            except asyncio.TimeoutError:
                log(f"timed out after {TIMEOUT_SECONDS}s")
            finally:
                done.set()
                await mic
                for e in (ev("contentEnd", {"promptName": prompt, "contentName": audio_c}),
                          ev("promptEnd", {"promptName": prompt}), ev("sessionEnd", {})):
                    await send(stream, e)
                await stream.input_stream.close()

    with wave.open(out_wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(24000)
        w.writeframes(bytes(audio_out))
    print()
    print(f"tool called:  {'YES' if tool_calls else 'NO'}")
    print(f"audio out:    {len(audio_out) / 48000:.1f}s -> {out_wav}")
    ok = bool(tool_calls and audio_out)
    print("SMOKE TEST " + ("PASSED" if ok else "FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main(sys.argv[1] if len(sys.argv) > 1 else "smoke_reply.wav")))
