"""
Relay from the voice channel to Agentforce: one Agent API session per call.

Agentforce stays the brain. Every caller turn goes through the same Agent API path the eval
harness uses (`src/agent_client.py`, bypassUser=True, so actions run as the agent user under
its least-privilege permset). Nova only speaks what comes back.

Delivery map: the Agent API returns text only, so the map is fetched separately from
`OCC_OrderMapRest`, which re-verifies email + order in Salesforce. The page never chooses what to
look up. The fetch happens only after Agentforce has answered about the order: a tracking answer,
or a status answer saying it shipped. That means Agentforce has already verified the caller.
OCC_OrderMapRest returns a map only for a Shipped order with a position. The candidate emails
are Agentforce's confirm-back ("I heard order 1042 with the email …") and emails the caller said.
The call locks to the first one Salesforce verifies. Caveat: that REST call runs as the External
Client App's Run As user (admin), not the agent user.
"""
import asyncio
import os
import re
import sys
import time

import requests

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src"))
from agent_client import client_from_env  # noqa: E402

# Spoken when Agentforce returns no text (e.g. a platform Escalate) or the API call fails.
FALLBACK_REPLY = ("I'm sorry, I'm having trouble reaching our system right now. "
                  "Please try again in a moment.")

# Agentforce's combined confirm-back, e.g. "I heard order 1042 with the email jane.doe@example.com"
CONFIRM_BACK = re.compile(r"\border\s+(?:number\s+)?([A-Za-z0-9-]+)\b.{0,40}?\bemail\s+"
                          r"(?:address\s+)?([\w.+-]+@[\w-]+(?:\.[\w-]+)+)", re.I | re.S)
# The spoken tracking answer from OCC_GetOrderDeliveryInfo: "... about 12 minutes by car."
TRACKING_ANSWER = re.compile(r"\bminutes?\s+by\s+car\b", re.I)
# A status answer for a shipped order ("Order 1042 is currently shipped", "… was shipped and …").
# The laptop mic can turn "where is my order" into "what is my order", which gets a status answer
# instead of a tracking one; the map shows either way. Deliberately not matched: "has shipped" in
# workflow explanations ("once it has shipped, cancellation …") and any negation.
SHIPPED_ANSWER = re.compile(r"\b(?:is|was|has been)\s+(?:currently\s+|already\s+)?shipped\b", re.I)
# Any order number Agentforce mentions ("I can help you track order 1042").
ORDER_MENTION = re.compile(r"\border\s+(?:number\s+)?((?:ORD-?)?\d{3,})\b", re.I)
# An email as the caller said it: written ("jane.doe@example.com") or spoken ("jane dot doe at
# example dot com"), as Nova's transcript renders it.
WRITTEN_EMAIL = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+")
SPOKEN_EMAIL = re.compile(r"\b([a-z0-9_]+(?:\s+(?:dot|underscore|dash)\s+[a-z0-9_]+)*)\s+at\s+"
                          r"([a-z0-9-]+(?:\s+dot\s+[a-z0-9-]+)+)\b", re.I)


# Agentforce's closing line, e.g. "Thank you for calling today. ... Have a great day!". A reply with
# a question in it ("Is there anything else …?") is never a goodbye: the call stays open.
GOODBYE = re.compile(r"\b(?:have a (?:great|good|nice|wonderful|lovely) (?:day|evening|one|weekend)"
                     r"|goodbye|good-bye|thank(?:s| you) for calling)\b", re.I)


def is_goodbye(reply):
    return bool(reply) and "?" not in reply and bool(GOODBYE.search(reply))


# The caller's own call-control words, as a net for a closing line that drifts. Agentforce's reply
# stays the primary signal; on 2026-09-23 a call ran ten turns without one, because every reply was
# either a question or the escalation subagent repeating the same handoff sentence, so is_goodbye
# never matched and the call never ended. Deliberately narrow: phrases that mean "end this call",
# never a bare "no".
CALLER_HANGUP = re.compile(r"\b(?:hang\s*up|end (?:the|this) call|cancel the call|good-?bye|bye"
                           r"|that'?s all|that is all|nothing else|we'?re done)\b", re.I)


def wants_hangup(utterance, reply):
    """The caller asked to end the call AND the agent did not come back with a question.

    A reply containing "?" is still owed an answer - including step one of the close, "is there
    anything else I can help you with?" - so the line stays open, exactly as is_goodbye treats it.
    Both signals land on the same turn: the utterance is the caller's "no thanks, that's all" and
    the reply is the goodbye it triggered.
    """
    if not utterance or "?" in (reply or ""):
        return False
    # An address is not a farewell: "my email is bye@example.com" must not end the call.
    return bool(CALLER_HANGUP.search(WRITTEN_EMAIL.sub(" ", utterance)))


def emails_in(text):
    """Emails in a caller utterance, in the order spoken."""
    found = [m.group(0).rstrip(".").lower() for m in WRITTEN_EMAIL.finditer(text or "")]
    for m in SPOKEN_EMAIL.finditer(text or ""):
        local = re.sub(r"\s+dot\s+", ".", m.group(1), flags=re.I)
        local = re.sub(r"\s+underscore\s+", "_", local, flags=re.I)
        local = re.sub(r"\s+dash\s+", "-", local, flags=re.I)
        domain = re.sub(r"\s+dot\s+", ".", m.group(2), flags=re.I)
        found.append(f"{local}@{domain}".replace(" ", "").lower())
    return found


def extract_text(messages):
    """Same rule as run_eval.py: only Inform messages carry text for the caller."""
    return "\n".join(m["message"] for m in messages if m.get("type") == "Inform" and m.get("message"))


class KeyburnRelay:
    def __init__(self, on_map=None):
        self._client = client_from_env()
        self._lock = asyncio.Lock()  # Agent API turns are sequenced; never overlap them
        self._on_map = on_map        # async (dict) -> None; the page's map panel
        self._verified = None        # first email OCC_OrderMapRest verified; locked for the call
        self._candidates = []        # emails read back by Agentforce or said by the caller, newest last
        self._order = None           # latest order number Agentforce mentioned
        self._shown = set()          # orders whose map was already sent
        self.greeting = ""
        self.turns = []  # {"utterance", "reply", "seconds", "non_text"} per caller turn
        self.maps = []   # {"order", "found", "inTransit", "seconds"} per map fetch

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
            self._track(utterance, reply)
            return reply or FALLBACK_REPLY

    def _remember(self, email):
        if email in self._candidates:
            self._candidates.remove(email)
        self._candidates.append(email)

    def _track(self, utterance, reply):
        # A read-back can be wrong ("jen.doe" for "jane.doe") and the caller corrects it by voice.
        # Agentforce then answers without reading the corrected email back, so the caller's own
        # words are candidates too. Nothing is trusted until OCC_OrderMapRest verifies it.
        for email in emails_in(utterance):
            self._remember(email)
        m = CONFIRM_BACK.search(reply or "")
        if m:
            self._remember(m.group(2).rstrip(".").lower())
        orders = ORDER_MENTION.findall(reply or "")
        if orders:
            self._order = orders[-1]
        answered = TRACKING_ANSWER.search(reply or "") or SHIPPED_ANSWER.search(reply or "")
        if answered and self._order and self._on_map \
                and self._order not in self._shown:
            self._shown.add(self._order)
            # In the background: the spoken answer must not wait for the map.
            asyncio.create_task(self._fetch_map(self._order))

    async def _fetch_map(self, order):
        # Mirror the agent's identity lock: once an email is verified, only that email is used.
        emails = [self._verified] if self._verified else list(reversed(self._candidates))
        t0 = time.monotonic()
        for email in emails:
            try:
                data = await asyncio.to_thread(self._get_map, email, order)
            except Exception as e:
                print(f"[relay] map fetch failed: {e!r}", file=sys.stderr)
                self._shown.discard(order)
                return
            self.maps.append({"order": order, "email_tried": email, "found": data.get("found"),
                              "inTransit": data.get("inTransit"),
                              "seconds": round(time.monotonic() - t0, 2)})
            if data.get("found"):
                self._verified = email
                if data.get("inTransit") and data.get("mapUrl"):
                    await self._on_map({"order": order, **data})
                return
        self._shown.discard(order)  # nothing verified; a later tracking answer may retry

    def _get_map(self, email, order):
        r = requests.get(f"{self._client.my_domain_url}/services/apexrest/keyburn/ordermap",
                         params={"email": email, "orderNumber": order},
                         headers={"Authorization": f"Bearer {self._client._get_token()}"},
                         timeout=30)
        r.raise_for_status()
        return r.json()

    async def close(self):
        await asyncio.to_thread(self._client.end_session)
