# Project status and decision log

Append-only log, newest entries first. `CLAUDE.md` holds the *current* state of the project; this
file records *how it got there* and what remains open, so that decisions are not re-litigated or
silently reversed. Entries whose conclusions were later revised are marked **Superseded** and point
to the entry that replaced them.

---

## 2026-09-19 — Phase 12 started: deck and demo guide

- **Deck** built as a claude.ai Slides artifact, "Order & Case Concierge — Builders Panel"
  (private until shared from its Share menu): 23 slides with speaker notes and timings,
  following the panel's four chapters. The eval slide plots all 35 saved runs (27% → 96%), with
  agent changes and test-only fixes marked differently. There are 3 trade-off slides (accuracy,
  latency and autonomy; platform and delivery; voice latency) plus a failures slide and a "with
  more time" slide. Placeholders to fill in: name, current role, career examples.
- **`docfiles/DEMO_GUIDE.md`** covers timing and what to cut, the pre-flight checklists (Tue /
  T–60 / T–10), the script for the four demo moments (website chat + map, diagram + refused identity
  switch, Nova call with a staged wrong digit + refund escalation, and the Case in the console),
  failure recovery, and a design-decision crib sheet.
- **Decision: stage the misheard number as a wrong digit** (1024 → corrected to 1042), not
  "O-1O42", because the voice layer's O→0 conversion can skip the confirm-back.
- Still to do on Tuesday: run the evals twice on v38, record the backup videos, rehearse twice.

---

## 2026-09-20 — Phase 11 CLOSED: external voice channel live, all demo surfaces verified

**Builder: "now it works, phase 11 finished."** Verified by the builder end to end, with the
laptop mic and speakers (the demo setup): the Nova call page, the branded Keyburn website (public
site and the in-Salesforce tab), and the Keyburn Service app with the Agentforce Escalations list
view. Apex after the Phase 11 changes: **73/73**.

What Phase 11 delivered, against the runbook:

1. **Agentforce stays the brain, Nova 2 Sonic is only speech** — as designed. Every caller turn
   goes through the Agent API session the eval harness uses (`bypassUser: true`), so the identity
   checks, `USER_MODE`, the least-privilege permset and the escalation path all still apply on the
   new channel, and the Phase 8 eval evidence stays valid.
2. **Two guardrails the voice layer forced on us**, both structural, not prompt-level: the relay
   sends only what the caller was *heard* saying (Nova invented a caller "yes" to the identity
   confirm-back), and the tool result is `say_to_caller`, a message Nova must speak and never
   answer.
3. **The map on the page** via `OCC_OrderMapRest`, locked to the first email Salesforce verifies.
4. **Latency measured** per turn, which the runbook asked for: Agentforce 2.9–7.5 s (average
   ~4.9 s), caller stops → first audio 3.8–6.7 s. A cold first turn hit 13.8 s, hence the warm-up
   call before the demo.
5. **Findings worth the deck:** the Agent API returns text only; in-chat voice writes nothing to
   the conversation; a page framed in Lightning can't use the microphone; the same agent serves
   three channels and the *channel* decides what can be shown.

Deferred by choice (with more time): a dedicated integration user for the ECA so the map call
doesn't run as admin; hosting the voice backend so the public site could offer it; an Experience
Cloud site instead of the Visualforce page.

**Next: Phase 12 only.** Freeze v38, re-run the eval suite twice, refresh the parcel position
(`set_demo_geodata.apex`), delete eval-generated escalation Cases (00001201, 00001202 and the
00001031+ batch) if the case list is on screen, record backup video, build the deck, rehearse.
No new features.

---

## 2026-09-19 — Demo surfaces inside Salesforce: branded customer page, public site, Keyburn Service app

**Decision (builder): A + C + better access through Salesforce.** An Experience Cloud site (B) was
rejected four days before the demo: the chat would look the same, and it adds a site, publishing,
a guest user, new CSP/CORS entries and a second republish after every agent publish. It goes in the
deck as the production path.

Built and deployed:

- **`KeyburnHelp`** VF page: a branded "Keyburn · Order help" storefront page. Promo strip, header,
  hero with "Chat with Keyburn" (calls `embeddedservice_bootstrap.utilAPI.launchChat()`),
  popular-question buttons, four help tiles, the Draft → Delivered journey. Same bootstrap as
  `KeyburnChatTest` (15-char org ID). When framed (i.e. opened as a tab), it shows an "Open full
  screen" bar.
- **Keyburn Service** console app (orange header): tabs Keyburn Website (VF tab), Cases,
  Contacts, Orders (new `Order__c` tab: the record page has the delivery map), Knowledge. Visible
  to System Administrator only.
- **Case list view "Agentforce Escalations"** + `Escalation_Summary__c` on the Case layout
  (read-only; Admin FLS read). Deployed from `mdapi/case-listview/` (see CLAUDE.md for why).
- **Public site `Keyburn`** (Visualforce site, `…my.salesforce-sites.com/keyburn/`), guest profile
  `Keyburn Profile` = the page + the standard error pages, no object access. CORS origin
  `Keyburn_Sites`. The ESW site's iframe allowlist gained the Sites and Lightning domains, the
  only change to the existing chat configuration.
- Redaction: the site files carry the admin username, so a new `REDACT_ADMIN_USERNAME` was added
  and `tools/setup_redaction.ps1` re-run. It wasn't in any commit before.

**Public site 503 "Down For Maintenance" on every path, resolved by the builder in Setup → Sites**
(a one-time UI step the Metadata API can't do). Checked by the builder: the public site, the
Keyburn Website tab (chat works inside Lightning) and the Agentforce Escalations list view.

**Builder test on the site: text chat fully works (answers + map card). Voice in the same chat
window: fluent, correct answers, but no transcript in the chat window and no map card.** This
matches the 09-17 voice-preview trace: voice runs as a separate voice connection
(`__current_modality__: voice`, `__current_connection__: telephony`), not as messaging entries,
and result display is unsupported there, so `show_command` never produces the card. The
deployment config (`embeddedServiceConfigs/`) has no voice or transcript setting to change. Not
proven from the org: the stored `MessagingSession`s don't identify which was voice. **Recommended
demo split:** the website = typed chat + map card; the Nova voice line = voice + transcript + map;
Keyburn Service = the escalated Case. Present the chat-voice limitation in Issues & Trade-offs, with
the Nova page as the workaround.
Confirmed by the builder: voice was started with the **mic button inside the chat window**
(Agentforce Voice in Enhanced Chat v2). Salesforce's material only says text and voice can be
switched "in the same conversation", and says nothing about showing voice turns or rich cards in
the window.

**Correction (2026-09-20): "platform limit" was concluded on bad evidence — retracted.**
The builder then showed that **voice in the Agentforce Studio preview transcribes speech into the
conversation without any problem**, so transcription per se is not the blocker; the deployed chat
window is a different surface. My supporting evidence was also worthless: the per-session
`ConversationEntry` counts were zero for *every* session, text ones included, because
**`ConversationEntry` is empty org-wide** (0 rows unfiltered) — not queryable/populated here, so it
proves nothing. Lesson (again): check that a query returns data for a known-good case before
reading meaning into a zero.
Also checked as the place to fix it: `EmbeddedServiceConfig` has no voice or transcript setting
(only receipts/typing/emoji toggles). **Correction (2026-09-20): I wrote that `MessagingChannel`
has no voice fields — wrong; I had queried the SOQL object, not the metadata.** The retrieved
`MessagingChannel` carries **`<isVoiceModeEnabled>true</isVoiceModeEnabled>`** (the mic button)
plus the Omni wiring `sessionHandlerAsa: Keyburn_Customer_Service` /
`sessionHandlerQueue: Service_Agent_Queue`. There is still no transcript setting anywhere, so the
finding above stands; only the "where voice is configured" claim was wrong. **Settled by an `entries` capture (builder, 2026-09-20; kept outside the repo as
`v38_entries.json`): in-chat voice turns are never written to the conversation.** The capture of a
voice session contains 6 entries and exactly **one** `Message` — the greeting, sent before voice
started. The conversation carries a `ModalityUpdate`: `activeModalities: ["Messaging"]` →
`["Voice"]` when the mic is pressed → back to `["Messaging"]` ~98 s later, and **no Message entry
is created in between**. So there is nothing to render live and nothing to find after a refresh
(the builder confirmed a refresh shows nothing), and a card cannot appear either, because a card
*is* an entry. `ParticipantChanged` shows the agent with
`supportedModalities: ["Messaging", "Voice"]`, so this is not an agent misconfiguration. The
Studio preview transcribes because it is a different surface drawing its own speech-to-text, not
messaging entries.
**Conclusion: for the deployed chat, voice = audio only; the screen shows nothing.** Not worth
further work before the demo. Demo split stands: website = typed chat + map card; Nova page =
voice + transcript + map; Keyburn Service = the escalated Case. Good Issues & Trade-offs material:
the same agent behind three channels, and the channel decides what can be shown.

**The microphone does not work in the Keyburn Website tab** (`/lightning/n/KeyburnHelp`), and
can't be made to: a browser only allows an iframe to use the mic when the parent sets
`allow="microphone"`, and the Lightning tab frame doesn't. Nothing in the page or in Setup changes
that. It costs little, since in-chat voice shows nothing on screen anyway. The framed banner now
says typed chat works but the mic doesn't, and links to the **public site** (top-level, mic
allowed) instead of the framed URL. **The public site is live** (HTTP 200) after the builder's
Setup → Sites activation.

---

## 2026-09-19 — Phase 11: first live voice test by the builder; delivery map added to the call page

**Live mic test (builder, headset): all good except the map, which the page didn't have yet.**
One 8-turn call (`call_logs/call_20260919_111942.json`): the spoken "one zero four two" and "jane
dot doe at example dot com" were resolved correctly. Confirm-back → a real "yes" → tracking. Then
return eligibility, the next status (from the workflow diagram), the current status, tracking
again, and "I want to cancel my order" escalated. **Case 00001201 verified in the org** (High,
`out_of_scope`, Jane Doe, created by the agent user). 0 blocked relays. Agentforce **3.2–7.5 s per
turn, average 4.9 s**. The slowest was the diagram question (GPT-4o on the image). Demo prep: the
parcel position was "15 hours ago", so re-run `set_demo_geodata.apex` before the demo.

**Decision (builder): Option A, show the map on the call page.** The Agent API returns text only,
so `relay.py` fetches it from `OCC_OrderMapRest` itself, under three rules:

- The identity is **Agentforce's own confirm-back** ("I heard order 1042 with the email …"),
  parsed from its reply, not from the caller's words. The call locks to the first email read back,
  mirroring the agent's identity lock.
- It fetches **only after Agentforce gave a tracking answer** ("… minutes by car"), so the map
  appears only when Agentforce has already verified the caller and disclosed the location. It
  fetches once per order, in the background, so speech isn't delayed.
- `OCC_OrderMapRest` re-verifies email + order in Salesforce.

**Trade-off for the deck:** the REST call uses the ECA token, so it runs as the **Run As user
(admin)**, not the least-privilege agent user. The email/order verification still applies, but
it's weaker than the agent's own action. It's also coupled to Agentforce's wording (two regexes in
`relay.py`). The "with more time" fix is a dedicated integration user for the ECA, with the agent
permset. The static-map URL carries the Google key to the browser, same as the deployed chat.

Headless check: map event 0.8 s after the tracking reply (2.5 km / 12 min), logged under `maps` in
the call log. That run also blocked one invented `"yes"` from Nova, so the guardrail was still
needed.

**Second live test (builder): map shows, but needed a Google Maps link, and one call lost it.**

- **Link:** `OCC_OrderMapRest` now returns `directionsUrl` (the same `OCC_DeliveryMap.directionsUrl`
  as the record page: warehouse → parcel waypoint → address, no API key). The image and an "Open
  route in Google Maps" link use it. Test asserts added. Deployed with `OCC_OrderMapSurfacesTest`
  5/5.
- **Lost map (`call_20260919_113440`): my identity rule was wrong.** Nova heard "jen dot doe",
  Agentforce read back jen.doe, the caller said "No, … jane dot doe", and Agentforce answered
  tracking *without a new read-back*. The relay had locked to the first read-back (jen.doe), so the
  REST call returned `found: false`. **New rule:** candidate emails = Agentforce read-backs **plus
  emails the caller said** (spoken "x dot y at z dot com" is parsed). Newest is tried first, and the
  call locks to the **first email Salesforce verifies**. Trying a candidate is safe: the endpoint
  needs a matching email + order, the same bar as the agent. A replay of all three recorded calls
  against the live endpoint: map + directions link in each, including the jen.doe call.
- **Agent observation (not a page issue):** after the correction, Agentforce went straight to the
  answer without reading the corrected email back. That's arguably fine, since the caller spelled it
  out, but it differs from the v15 "a correction earns one new combined question" rule. Watch it in
  voice.
- **Agent observation, `call_20260919_113555`:** the caller couldn't end the call by voice. "No"
  got a goodbye. A following "oh no" re-triggered tracking. Spanish "ya no te voy a ayudar más"
  (probably said to someone in the room) was read as frustration and **escalated: Case 00001202,
  High, `frustration`** (real, in the org; delete before the demo). "Hang up" was misheard as
  "hunt up", then "just hang up" drew generic replies. Nothing ends a call except the page's Hang up
  button. For the demo, hang up with the button. An optional fix: the page ends the call when
  Agentforce's reply is a goodbye.

**Third live test: good (builder). Decision (builder): auto hang-up after Agentforce's goodbye.**
The goodbye is detected on the **Agentforce reply** (`relay.is_goodbye`: "have a great day" /
"goodbye" / "thank you for calling", and **no question mark**, so "Anything else?" never ends a
call). This leaves the agent script untouched. The server sends `goodbye`; the page waits for Nova's
`END_TURN` plus local playback, then hangs up ("Keyburn ended the call after saying goodbye").
There's a 20 s fallback timer, and anything the caller says or types first cancels it.
Checked against all 45 logged replies: 4 flagged, all real closing lines. The greeting ("Thanks for
calling Keyburn … What can I help you with today?") isn't flagged. Headless call: no `goodbye`
after the policy answer (it ends in a question), `goodbye` right after "no, that's all". The page
loads without script errors. **The browser-side hang-up timing still needs one live call.**

**Fourth live test (builder): 1 perfect, 2 didn't hang up, 3 (laptop mic + speakers) got no map.**
Demo requirement from the builder: **laptop mic and speakers**, so the audience hears both sides.

- **Test 2, no hang-up:** the goodbye was detected ("…Have a great day!"). The page then cancelled
  the hang-up on *any* USER transcript text, most likely a late second ASR fragment of "forget it,
  that's all". With speakers, Nova's own voice through the mic would do the same. **Fix:** only a
  real new relay (`tool_start`) cancels a pending hang-up. Page-only change.
- **Test 3, no map: ASR, not speakers.** The laptop mic heard "**what** is my order 1042" for
  "where is …", so Agentforce gave a *status* answer ("… was shipped and was expected to arrive by
  September 11"), and the map only triggered on a tracking answer. The rest of the call was
  clean through the speakers: confirm-back, real "yes", 0 blocked relays, no echo loop.
  **Decision (builder): the map also shows after a status answer that says the order shipped**
  (`SHIPPED_ANSWER`: "is / was / has been (currently) shipped"). Deliberately not matched: "once it
  has shipped …" in workflow answers, and negations. Checked on 57 logged replies: it matches only
  the 3 real status answers. The endpoint still returns a map only for a Shipped order with a
  position. Replaying test 3 now shows the map; test 2 (no email given) shows none.
- First turn of test 1 took **13.8 s** in Agentforce (cold start after idle). Before the demo, make
  one warm-up call.

---

## 2026-09-19 — Moved out of OneDrive; published to GitHub (public)

**Decision:** projects live in a local `Projects` folder rather than OneDrive, with GitHub for
version control. Folder renamed `AgentFDE` → `AgentOrderConcierge`; public repo
`mitxi21/AgentOrderConcierge`, commits under the GitHub no-reply email.

- **Pre-push leak check caught one issue:** `.gitignore` excluded `set_keyburn_config.apex`, but
  the Google key lives in `set_keyburn_settings.apex`. Both names are now ignored.
- Not published: `secrets.env`, `sf-skills-1.55.0/` (vendored), local reference documents, call
  logs, CLI state.
- **Org identifiers are redacted by a git clean/smudge filter** (`.gitattributes` +
  `tools/setup_redaction.ps1`, values in the `REDACT_*` lines of `secrets.env`): org ID (15/18),
  My Domain, agent username + user ID, agent (BotDefinition) ID, AWS account ID. Chosen over
  editing the files because the metadata needs the real values to deploy. Verified by scanning a
  fresh clone of the pushed repo.

## 2026-09-18 — Phase 11 started: stack and AWS authentication

**Decision: Python 3.12 backend** in `bedrock-voice/`. boto3 has no
`InvokeModelWithBidirectionalStream`; the Python route is `aws-sdk-bedrock-runtime[awscrt]`
(experimental, Python ≥ 3.12). Chosen over Node because it reuses `src/agent_client.py` unchanged
and keeps a single language. Python 3.12.10 installed beside 3.8 (`py -3.12`); SDK, `websockets`,
`requests` and `pyyaml` installed with `--user`. The eval harness stays on `py -3.8`.

**Authentication: IAM access keys only.** A Bedrock API key (`ABSK…` bearer token) cannot call
`InvokeModelWithBidirectionalStream` (AWS docs, API-key limitations); the one created for this is
unused and is to be deleted in the Bedrock console. Minimal IAM policy for the local user:
`bedrock-voice/iam-policy.json` (that one action on `amazon.nova-2-sonic-v1:0`, eu-north-1).
IAM keys live in `secrets.env`.

Settled earlier and not re-spiked: the Agent API returns text only (`"result": []`, Phase 9), so
the page shows Agentforce's text. Nova's bidirectional stream closes after **8 minutes**, which
caps a single call unless the session is renewed — sufficient for demo calls.

**Nova smoke test passed** (`bedrock-voice/smoke_test.py`: typed caller turn + a relay tool
returning a stub, no Salesforce yet). eu-north-1 + `amazon.nova-2-sonic-v1:0` work with IAM keys.
Nova called `ask_keyburn_agent` 0.9–1.5 s after the caller's turn, passed the words verbatim, and
spoke the result (~8 s of audio). Findings:

- **SDK 0.11.0 differs from the Nova sample repo:** `AsyncBedrockRuntimeConfig.resolve(region=…,
  transport=AWSCRTHTTPClient())` + `AsyncBedrockRuntimeClient`. The default aiohttp transport
  cannot do HTTP/2 bidirectional streaming. Follow the SDK guide, not `amazon-nova-samples`.
- **Assistant text arrives twice:** `SPECULATIVE` as speech starts, then `FINAL` about 15 s later
  (`contentStart.additionalModelFields.generationStage`).
- **No `completionEnd` while the mic is open**, so turn-end detection cannot depend on it.
- **Relay fidelity:** Nova reworded slightly and placed its filler *after* the tool result. No
  facts were added.

**End-to-end typed call works (Nova → `ask_keyburn_agent` → Agent API → Nova speaks).**
`bedrock-voice/relay.py` (one Agent API session per call, `bypassUser: true`, the same
`Inform`-only extraction as `run_eval.py`, fallback line on empty/non-text replies),
`nova_session.py` (reusable stream; tool relayed in a background task), `call_test.py` (typed
3-turn call: greeting → order 1042 + email → confirm-back → "Yes" → status). The greeting is
Agentforce's own welcome message, spoken by Nova on `[call connected]` without a relay.

| Per turn (3 runs) | Seconds |
| --- | --- |
| caller turn → Nova calls the tool | 0.5–0.6 |
| Agentforce (Agent API round trip) | 3.4–4.1 |
| caller turn → first audio | 4.6–5.3 |

- **Relay fidelity with real replies: verbatim.** The speculative text matched the Agentforce
  reply word for word, confirm-back and answer included. Agentforce accounts for ~75% of the wait.
- **Model filler removed.** "One moment." arrived *after* the tool result, so it did not cover the
  4-second gap and delayed the answer. **Decision: the page plays a local hold sound on
  `tool_start`** — deterministic, independent of the model.
- Turn end = audio `contentEnd` with `stopReason: END_TURN` (earlier segments are `PARTIAL_TURN`).
  Audio is generated faster than real time, so the end signal precedes the end of playback.
- The FINAL transcript only arrives when the *next* input starts, truncated to the first segment.
  **The page transcript uses the SPECULATIVE text**, which matches what is spoken.

**Call page built; a real-audio test found and closed a guardrail gap.**
`bedrock-voice/server.py` (aiohttp, localhost only; one WebSocket = one Nova stream + one Agent
API session; per-call relay log in `call_logs/`, git-ignored), `static/index.html` (mic → 16 kHz
worklet, 24 kHz gapless playback, barge-in flush, local hold chime while Agentforce works,
transcript, "Behind the call" relay panel with per-turn latency), `ws_test.py` (headless: plays
caller WAVs into `/ws` in real time, caller voice from Windows SAPI at 16 kHz). Doubles as the
demo-day preflight.

**The gap (first real-audio run): Nova answered the identity confirm-back itself.** Instead of
speaking "I heard order 1042 with the email …, is that right?", it relayed an invented caller turn
`"yes"` to Agentforce, and the order was disclosed with no caller audio behind it. Root cause: Nova
treated a tool result phrased as a question as a question addressed to it. Statements were spoken
correctly. Fixes, structural first:

1. **Relay grounding (structural):** relayed words come only from Nova's own USER transcript (the
   ASR) or a typed turn, accumulated since the last relay. Nova's tool argument is ignored. With
   nothing new, nothing goes to Agentforce, and the page shows a **blocked relay**. On the next run
   this blocked 48 invented `"yes"` attempts; only the caller's real "yes, that is right" was
   relayed.
2. **Prompt:** the tool result is `say_to_caller`, a message *for the caller*, often a question.
   Say it word for word, never answer it, and wait for the caller. The blocked-relay result tells
   Nova to say the pending message and wait.

After both: **2 of 2 clean runs** — confirm-back spoken verbatim, the real "yes", then the tracking
answer, with 0 blocked relays. Design principle: the voice layer is another model that can put
words in the caller's mouth, so the relay trusts only what was *heard*.

Other findings: `endpointingSensitivity: LOW` (2.0 s) still splits "where is my order 1042? … my
email is …" into two relays at the sentence pause (SAPI voice; a human may differ). Agentforce
handles it well: the first reply is superseded and the second is the combined confirm-back. Caller
stops → first audio: **3.8–6.7 s** (2 s of which is endpointing); Agentforce 2.9–5.5 s per turn.
Next: live-mic test in the browser (headset, to avoid echo) and the 3-call manual script (runbook
step 6).

---

## 2026-09-18 — Phase 10 built: Draft status + agent reads the workflow diagram (agent v38, run 27 26/27)

**Design decisions:** Draft = "saved, not submitted"; no delivery date or tracking. Cancelled is
reachable from Draft or Processing, not after Shipped. The image-only facts are timings on the
diagram. The image lives as a **File on the Knowledge article**, resolved by Apex.

Built:

- `Order__c.Status__c` + `Draft` (first value; the default stays Processing). Sample order
  **ORD-1100** (jane.doe, Draft) is in the CSV and the org. `OCC_GetOrderStatus` gives a Draft its
  own message and blanks `estimatedDelivery`. `OCC_GetOrderDeliveryInfo` already reports "hasn't
  shipped" for anything that isn't Shipped/Delivered/Cancelled.
- Diagram `docfiles/order_workflow_diagram.png`, generated by
  `docfiles/make_order_workflow_diagram.ps1` (Draft → Processing → Shipped → Delivered, Cancelled
  from Draft/Processing). **Only in the image:** drafts kept 30 days then deleted, and no
  cancelling once shipped. The other timings repeat Articles 1–2.
- Knowledge article "How an order moves through Keyburn" (`how-an-order-moves-through-keyburn`),
  created and published by `sfdx-project/scripts/create_order_workflow_article.ps1`. The body text
  does not state the diagram's facts.
- Prompt template `OCC_Order_Workflow_Diagram` (Flex, GPT-4o, File + question). Answers only from
  the image; replies `NOT_IN_DIAGRAM` otherwise.
- `OCC_ExplainOrderWorkflow` (+ test, both permsets): article → linked PNG File → template via
  `ConnectApi`. Returns `answered` + a clean `message`; the sentinel never reaches the caller.
- Agent v38: router description for `go_to_policy_faq` (policies *and* how orders work).
  Policy/FAQ calls `ExplainOrderWorkflow` for workflow questions ("According to our order workflow
  guide, …", only when `answered`), falls back to Knowledge otherwise, and treats "can I cancel?"
  as a question, not a cancellation. Order Status: no date or tracking for a Draft. System rule:
  policy facts come from the FAQ lookup or the diagram action.

**Root cause: the agent user can read a Knowledge article but not the File attached to it.** The
first v37 run returned "I'm having trouble reading our order workflow guide". A trace flag on the
agent user showed both `USER_MODE` queries succeeding (article and `ContentDocumentLink` found),
then `ConnectApiException: Invalid parameter value "[Provide:{LATEST PUBLISHED VERSION ID}]"`: the
template could not resolve the File's version *as that user*. `UserRecordAccess` confirmed it:
article `HasReadAccess=true`, ContentDocument `false`. The article's link is ShareType V, but the
user does not inherit through it. **Fix: one `ContentDocumentLink` sharing that File read-only (V)
with the agent user** — targeted, no OWD change, and included in the create script. (After the
fix `UserRecordAccess` reports `MaxAccessLevel=All` on the document although the link is V; not
material to the fix.) The admin smoke test passed only because the admin owns the File — the same
"admin proves logic, not permissions" principle as `test_actions.apex`.

**Also fixed in v38:** v37 prefixed a failure message with "According to our order workflow
guide," and did not fall back to Knowledge. The prefix is now conditional on `answered`.

**Evals:** 5 new `workflow` cases, two image-only (`workflow_draft_expiry`,
`workflow_no_cancel_after_shipping`). **Run 27 (v38): 26/27**, all 5 new cases passing. The
failure, `edge_topic_switch_midcall`, passed 3/3 on repeat: the agent's return-policy answer
offered an eligibility check, and "check my order" was read as accepting it. Nondeterminism on an
ambiguous turn, not a Phase 10 regression; tracked in Phase 12's double run.

Minor open items: the template occasionally adds a small extrapolation ("you'd need to start a new
draft"). Tightening it requires a new template **version** (published versions are immutable).
Apex tests create their own article under a different UrlName, since UrlName uniqueness is checked
against real org articles even inside a test.

**Pre-existing test defect fixed:** `OCC_PolicyFAQLookupTest` (3 tests) always failed with
"Invalid ID". Its setup published `article.KnowledgeArticleId` straight after `insert`, where it
is still null; it now requeries the Id. Full Apex suite: **73/73**.

**v38 active** (was v33). Rollback = `sf agent activate --version 33`.

**Verified in the deployed chat** (capture `v38_entries.json`, stored outside the repo): workflow,
"next after Processing" and "Cancelled" questions were all answered "According to our order
workflow guide", including the image-only facts. The return-policy question was still answered
from Knowledge. The map card was also verified on v38. Routing note: "questions about the order
return windows" went to Return Eligibility rather than Policy/FAQ, and the caller's next turn
recovered it. **Decision: no router change.**

---

## 2026-09-18 — Phase 10 spike passed: a Flex prompt template reads an image File (GPT-4o)

Spike run before the build, per the runbook. Method: render a test PNG (three boxes Alpha → Bravo
→ Charlie plus a red line "Spike codeword: MARIGOLD-7314"), upload it as a File, deploy a
throwaway Flex template, and ask for the codeword. The codeword exists **only in the pixels**, so
returning it proves the model read the image rather than a text substitute.

- **(a) Template type:** `einstein_gpt__flex`, with an input `definition` of
  `SOBJECT://ContentDocument` (the File) plus a `primitive://String` question ("File inputs in Flex
  templates"). The metadata schema in `sf-skills` predates this.
- **(b) Model:** `sfdc_ai__DefaultGPT4Omni` deploys and reads the image. No model catalogue is
  reachable over the API (`/einstein`, `/einstein/llm` → 404), so other multimodal models were not
  enumerated; only relevant if GPT-4o misbehaves.
- **(c) How the image is passed:** as a **ContentDocument Id**
  (`{"Input:Diagram": {"value": {"id": "069..."}}}`). The text prompt carries an *empty* `Image:`
  merge field and the image travels separately as `fileData`. **A rich-text image embedded in
  `Article_Body__c` is not a ContentDocument**, so the diagram must exist as a File.

Both invocation paths work: `POST /einstein/prompt-templates/{name}/generations` returned
"MARIGOLD-7314", and Apex `ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate` returned the
box order and the red text. An Apex action can therefore resolve the File from the Knowledge
article server-side and call the template, so the agent never chooses which image is read.

Deploy notes: `versionIdentifier` must be platform-generated (`<hash>=_N`; a hand-written value is
rejected). Deploy without it, retrieve, then set `activeVersionIdentifier`, or generation fails
with `No active template version`.

Spike artefacts (template `OCC_Spike_Image_Read`, File "OCC Spike Diagram") were deleted once the
real template existed. The spike ran as admin; the call **as the agent user** surfaced the File
sharing issue documented in the build entry above.

---

## 2026-09-18 — Second-card experiment (v34–v36); decision: one map per conversation; v33 reactivated

A final experiment was run before accepting the limit. A separate display-only action,
`OCC_ShowDeliveryMap` (returns just the card; delegates to `OCC_GetOrderDeliveryInfo`, lock
included), was chained **deterministically** so the card would not depend on the model:

- **v34/v35: a post-action `run` inside `if @outputs.inTransit`** ran on the second tracked order
  but was **skipped on the first**. The trace shows that when post-action `set`s flip an
  instruction condition (`identity_locked` false → true on the first lookup), the runtime
  re-resolves the instructions and drops the remaining post-action directives. Moving the `run`
  before the `set`s made no difference. *Finding: a post-action `run` is not reliable when the same
  action flips instruction state.*
- **v36: a `map_pending` flag + a `run` at the top of the instructions** ran `ShowDeliveryMap` for
  every tracked order (confirmed in the trace), but the chat received **no card at all**. *A
  displayable output from a deterministic `run` is never sent to the chat; only a model-invoked
  action displayed via `show_command` produces the `ExperienceType` card.*

**Decision: one map card per conversation.** The first tracked order shows the card; later orders
get the spoken distance and time. Documented as a platform finding. **v33 reactivated**; the draft
`.agent` was restored byte-for-byte from the retrieved `Keyburn_Customer_Service_33` bundle and
validates. `OCC_ShowDeliveryMap` (+ test, permset entries) stays deployed but unused; delete after
the demo. Evals: run 26 (v36) 22/22 (text scoring does not see cards).

**Verified after republishing:** v33 behaves as designed in the deployed chat — the first tracked
order shows the map card, later ones are spoken only, and the identity lock refuses a second
customer. Baseline for Phase 10.

## 2026-09-18 — v33: identity lock moved into Apex; republish rule; second card per chat

Manual test on v33 (after republishing the Embedded Service deployment): **first card OK, second
tracked order in the same chat had no card, identity switch refused.**

- **Republish the Embedded Service deployment after every agent publish.** On v32 the first card
  was sent with correct data but not drawn. Each publish gives the action output a new type ID
  (`copilotActionOutput/GetOrderDeliveryInfo_<id>`); the card drew again after republishing. Same
  pattern as v30.
- **The lock moved from aliases into Apex (v33).** In v32 the second lookup went through a separate
  `GetOrderDeliveryInfoVerified` alias, and the model skipped the display on it. Now every lookup
  has a `lockedEmail` input bound to `@variables.verified_email`, and
  `OCC_CaseLookupUtil.violatesLock` refuses any other email in Apex — a stronger guarantee
  (enforced below the model) with a single action name. Outputs `verifiedEmail` +
  `identityLocked`; a refused call keeps the lock. Apex 35/35. Run 25 (v33) 22/22.
- **The second card in a chat is not sent** (server-side history: text reply only, no non-text
  entry), even with explicit "every time … including a second order" wording (v31, v33). The
  platform display step (`show_command`, state flag `__show_tool_results_invoked__`) is effectively
  once per conversation. Undocumented, and not observable in the preview
  (`__supports_result_display__` false there).

## 2026-09-18 — Identity lock per conversation (v32); map on every tracked order (v31)

**Manual test:** in one chat, maria.garcia / 1088 got the card, then jane.doe / 1097 got a
text-only answer. Two findings:

1. **No card on the second tracked order.** The v28 wording *"call the show_command tool once"* was
   read as once per conversation. v31: *"Every time … including a second or later order in the same
   conversation"*.
2. **An identity switch within one chat went unchallenged** — a data-access gap: anyone holding two
   customers' email + order number could query both from one session. **Decision: lock the
   conversation to the first verified identity** (chosen over a simulated OTP and over
   authenticated chat, both out of scope for the remaining schedule; authenticated chat is the
   longer-term answer).

**How the lock works (v32), structurally rather than by prompt:**

- The 6 lookup actions return a new `verifiedEmail` output, set only on a successful match (tests
  assert it is null on failure).
- Each lookup has two aliases in the script. The unverified one (`available when identity_locked
  != True`) sets `identity_locked` from `found`/`verified`/`success` and stores `verified_email`.
  The `*Verified` one (`available when identity_locked == True`) binds `with email =
  @variables.verified_email`, so the model **cannot** pass a different email.
- `!= True` rather than `== False`, so a null flag from an exception path never leaves the caller
  with no actions available.
- Per-subagent instructions refuse a different email and suggest a new conversation.
- `verifiedEmail` comes from Apex because `set @variables.x = @inputs.y` fails silently in Agent
  Script.

Preview + eval: the switch is refused (*"For your security, I can only help with the account
verified earlier in this call …"*). New eval case `guardrail_identity_switch_refused`. Run 24 (v32)
21/22; the failure was a test defect (`match_scope` placed outside `expect:`). Run 24b (test fix
only) 22/22.

Minor open item: after the lock, a new order number (1038) was looked up without a read-back.

## 2026-09-18 — Map card working in the deployed chat (agent v30): root causes

**Verified in the deployed chat:** v30 shows the card (headline, W→O→D route map, "Position
reported …") under the spoken answer, with no "Entry 1" / raw-URL text.

**Correction:** the earlier conclusion that only the original v16 publication renders the card was
wrong (see the superseded entries below). Reactivating v16 produced a text-only reply with no card
entry. Four independent causes were identified by reading the payload the chat client receives
(DevTools → Network → the conversation `entries` response) rather than by comparing versions:

1. **The display step was left to the model (fixed in v28).** Displayable outputs reach the chat
   only if the model calls the platform tool `show_command` that turn. Nothing instructed it to, so
   display was a per-turn model decision rather than a guaranteed behaviour. v28's tracking
   instruction names it: *"call the show_command tool once to display its Delivery Map result,
   then say its message"* (pattern from Salesforce's agent-script-recipes CustomLightningTypes
   recipe). The reply then became an `ExperienceType` message carrying the action output.
2. **URL redaction (fixed by a CSP Trusted Site).** URLs whose domain is not a CSP Trusted Site
   arrive as the literal `URL_Redacted`. `www.google.com` (the directions link) was not trusted;
   `maps.googleapis.com` was. New trusted site `Google_Maps_Links`.
3. **Mixed display bundle (v29).** `message`, `itemDetails` and `deliveryMap` were all displayable,
   so the client received one mixed value. Now only `deliveryMap` is displayable; `itemDetails` is
   no longer declared on the action (Apex still returns it).
4. **The type was not Apex-backed and the renderer LWC had no `sourceType` (v30, the decisive
   fix).** The recipe's schema is `"lightning:type": "@apexClassType/c__Class$Inner"`, and its
   renderer LWC has `<targetConfig targets="lightning__AgentforceOutput"><sourceType
   name="c__Type"/>`. Ours was a standalone JSON schema with no sourceType, so the chat never
   requested the component (no request in Network, no console error). An existing type cannot be
   converted ("Schema update contains breaking changes"), so a new type `OrderDeliveryMapCard` →
   `OCC_GetOrderDeliveryInfo$DeliveryMapCard` was created, LWC at API 66.0. The old
   `OrderDeliveryMap` type is unused.

Plus: **republish the Embedded Service deployment** after adding or changing a card type; the card
appeared only after republishing `Agentforce_Service_Agent`.

v27 also had a routing regression, fixed in v28: *"when the caller says yes … call
GetOrderStatus"* made "where is my order" + "yes" return status instead of tracking.

Evals: runs 21 (v28), 22 (v29), 23 (v30) all 21/21.

**Security, open:** the static-map URL in the card payload carries the Google API key to every
chat user's browser. When rotating after the demo, split it into a server-only key (Routes API) and
an HTTP-referrer-restricted key (Maps Static API).

## 2026-09-18 — Voice test on v6: false escalation fixed (v7)

First voice test of Phase 9, on a deliberately messy call (mis-heard email, repeated corrections).

**False escalation — fixed in v7.** Before the caller had finished giving their email, the agent
logged Case 00001075 (`unverifiable_identity`, summary "did not provide an email address") and
announced a follow-up. **A partial answer is not a refusal.** The v4 rule "don't know / don't
remember → escalate immediately", together with the router description, matched a caller who was
mid-sentence.

- Router: `go_to_escalation` now excludes a caller who has not given a detail *yet*, or whose
  answer was partial, mis-heard or cut off — they stay in their current topic.
- The Escalation subagent checks before logging: partial answer → say the detail was not caught
  and ask for it again, log nothing.
- **The `after_reasoning` safety net was removed.** It fired on *every* visit to the escalation
  subagent, so with the new re-ask branch it would create a junk High-priority Case on a routine
  voice retry. False escalations are the worse failure; the eval suite still asserts a spoken case
  number on the real escalation cases. (It had not fired in any run.)
- New eval case `edge_partial_answer_does_not_escalate` reproduces the call. **Run 10 (v7): 19/19,
  with exactly 5 Cases created — the 4 intended escalations plus 1 support case.**

The same call showed the map not rendering in chat; resolved in v30 (above).

## 2026-09-18 — Superseded: card rendering tied to the v16 publication

*Superseded by the v30 entry above: the actual causes were the display instruction, the type not
being Apex-backed, URL redaction and the display bundle.*

At the time, only v16 showed the card; v23–v26 (including byte-identical republishes of the v16
script) did not, and compiled output schemas were identical. v16 was kept active as a precaution,
with the working draft held unpublished. Apex refinements reach an active version without a
republish, since the action calls the current class.

The console messages in the chat page (permissions-policy "unload" violations, LDS "no matches
found", `EvfSdkController.getEventTypes`) come from the Salesforce client and appear whether or not
the card renders.

## 2026-09-18 — Superseded: live stream vs history isolation

*Superseded by the v30 entry above.*

After v17–v20 showed no card, the regression was isolated step by step:

1. v16 and v20 scripts diffed (v16 bundle retrieved as `Keyburn_Customer_Service_16`): output
   declarations identical; only instruction wording differed.
2. Reactivating v16 itself still showed no card, ruling out the agent version.
3. Two environment changes had been made since the card was first seen: the test page's org ID
   (18 → 15 chars) and one CORS origin. Reverting to the 18-char ID with v16 active reproduced the
   original flow (live stream failing, replies visible only on reload), and the card appeared.

Interim conclusion: the Enhanced Chat V2 client rendered the card when loading from history but not
from the live event stream. The v30 investigation later showed card display was a per-turn model
decision at this stage, which accounts for the inconsistent observations.

Method adopted (recorded in `CLAUDE.md`): when something that worked stops working, list
*everything* that changed since — including test-harness and environment fixes — and revert one at
a time before changing the component under suspicion.

## 2026-09-18 — v18: identifiers written normally; display tool instruction

Text-mode test in the deployed chat, two defects:

- **Identifiers spelled out** ("order one zero four two with the email jane dot doe at example dot
  com"). The instructions said *"Speak order and case numbers digit by digit"* with spelled-out
  examples, written for voice before it was established that the platform's voice layer tags and
  pronounces IDs and emails itself (its own prompt: *"Do NOT explain pronunciation… let the tag
  handle it"*). In text mode those words appear verbatim. v18 writes them normally in both modes.
- **The map card was missing in v17**, although the `deliveryMap` output compiled identically in
  v16 and v17 (same `c__OrderDeliveryMap` type, `isDisplayable=True`, checked in the retrieved
  planner schemas). Displayable outputs appear only when the model invokes the platform's display
  tool (`show_command`; state variable `__show_tool_results_invoked__`). v16 invoked it on the
  observed turns, which is also why the rich-link data was dumped as text. v17's *"say the
  distance… and stop"* steered it to a text-only reply. v18 instructs it to show the delivery map
  result when `inTransit`, then give the message. The vendored reference warns against *vague*
  "present the results" wording because this tool can take over text answers; here it is intended,
  and there is only one displayable complex output, so it shows the card.

Run 19 (v18): 21/21; confirmation reads *"I heard order 1042 with the email jane.doe@example.com,
is that right?"*.

## 2026-09-18 — Map renders in the deployed chat (Custom Lightning Type, agent v17)

**Verified:** in the Embedded Messaging client, "Where is my order 1042?" shows the
`OrderDeliveryMap` card — headline, route image (W → O → D) and "Position reported …", with the
image linking to Google Maps directions. It is the Custom Lightning Type's **`enhancedWebChat`**
renderer, which **never renders in the Agent Builder preview**. That explains the four earlier
negative results, all of which were tested only in the preview.

Required to reach the deployed client, each a hard prerequisite:

1. `KeyburnChatTest` Visualforce page hosting the Embedded Messaging bootstrap snippet (org
   `__ORG_ID_18__`, deployment `Agentforce_Service_Agent`, site
   `ESWAgentforceServiceAge1789407438343`, scrt2 `…my.salesforce-scrt.com`).
2. CSP Trusted Sites for the site and scrt domains, and CORS origins for the VF, Lightning and site
   domains, so the site's `frame-ancestors` includes the VF domain and the chat iframe can load
   (before: *"Framing … violates frame-ancestors www.salesforce.com"*).
3. `areGuestUsersAllowed` → `true` on the `EmbeddedServiceConfig` (in source control under
   `embeddedServiceConfigs/`; the suffix must be `.EmbeddedServiceConfig-meta.xml`, capital E).
   **Security-relevant: revert after the demo.**
4. **Routing.** The deployed chat goes channel → Omni-Channel flow → agent; the Builder preview
   skips this. The routing flow template was inactive and the channel had no route to the agent.
   Configured in Setup / Agent Builder.

**v17 cleanup:** the rich link (`itemDetails`) output was still declared, and on Enhanced Chat V2 a
rich link degrades to text ("Entry 1", "image/png", the raw static-map URL, the title again and
`URL_Redacted` under the card). No longer declared on the action; Apex still returns it for a
Phase 11 custom client.

**Resolved — "Reconnecting…" and replies appearing only after refresh:** the live event stream
(`/eventrouter/v1/sse`, then `/eventrouter/v1/poll`) returned 400 with *"OrgId in the header and
token must match, but got '__ORG_ID_18__' in the header and '__ORG_ID_15__' in the token"*.
The test pages passed the **18-character** org ID to `embeddedservice_bootstrap.init()`; the
messaging token carries the **15-character** one and the event router compares them literally.
Both pages now use `__ORG_ID_15__`. The CORS origin added for the site domain is harmless and
stays.

**For Phase 11:** the messaging token endpoint rejects Web deployments — *"The deploymentType 'Web'
… isn't supported for this endpoint. Supported deployment types: API."* A custom client needs its
own **Custom Client (API)** deployment.

## 2026-09-18 — Custom Lightning Type (v16); double confirmation isolated to voice

**Custom Lightning Types are the documented way to render UI in an Agentforce conversation**
(Salesforce video series, *Episode 29: Custom Lightning Types*). Unlike the rich link card, the
bundle supports an **`enhancedWebChat/`** renderer — this org's channel. Built and deployed as
agent v16 (21/21 evals, 15/15 Apex):

- `lightningTypes/OrderDeliveryMap/schema.json` (root needs `type`, `title`,
  `lightning:type: lightning__objectType`, `unevaluatedProperties: false`, and **never** `$schema`)
- renderers for `lightningDesktopGenAi/` and `enhancedWebChat/`, both pointing at `c/occOrderMapCard`
- the LWC needs `<target>lightning__AgentforceOutput</target>` or the deploy is rejected
- **`attributes` on a root `componentOverrides.$` is rejected** ("You can't add the mapImageUrl
  property … `unevaluatedProperties` is false"), so the renderer passes no bindings and the whole
  object arrives as `value`
- action output `deliveryMap: object` with `complex_data_type_name: "c__OrderDeliveryMap"`

Four mechanisms had been tried — HTML string, `lightning__richTextType`, rich link (adaptive
response), and a Custom Lightning Type — all tested **only in the Agent Builder preview**, whereas
the `enhancedWebChat` renderer targets the **deployed** Embedded Messaging client.
`web-chat-test/index.html` loads the real client from the org's own values to test that directly,
and doubles as the seed for the Phase 11 client.

**Double confirmation appears only in voice.** Every API-driven eval and scripted preview trace
passes, including the dedicated regression cases, while manual voice transcripts show the
forbidden sentence ("I have your email as …, is that correct?") after a combined confirmation.
Instruction changes have not affected it, which points to the voice layer confirming recognised
entities itself. **Diagnostic before any further prompt work:** run the same flow in the Builder
preview in *text* mode. If text is clean and voice re-confirms, it is channel configuration, not
the agent script.

## 2026-09-18 — Third voice test: confirmation behaviour measured; channel analysis

*Channel conclusion superseded: the card renders in the built-in chat via an Apex-backed Custom
Lightning Type (v30 entry).*

Channel analysis at the time: the org has one Messaging channel, `MessagingChannel` "Agentforce
Service Agent", type **EmbeddedMessaging**. Rich link cards render on Enhanced Chat V1, Apple
Messages for Business and LINE, and fall back to text elsewhere; the Agent API agrees
(`__supports_result_display__: false`). Salesforce's Enhanced Chat documentation notes that a
custom client using the Enhanced Chat REST API must support the Text, Rich Link and Media
formats — relevant to the Phase 11 page.

**Double confirmation: agent behaviour correct, test defect.** Traces of the reported flow show
correct behaviour — after a corrected email the agent answers straight away, without an email-only
re-confirmation. The v15 instruction makes the rule explicit (after a yes the next message is the
lookup result; a correction earns exactly one new combined question). New case
`edge_correction_then_single_yes` initially failed 3/3 for a scoring reason: its 4th turn "Yes."
means *"yes, there is something else"*, so a closing question is correct — the agent had already
answered on turn 3. Rewritten with `match_scope: conversation`, asserting the **defect signature**
(`"I have your email as"`) rather than questions in general. **Runs 17a/17b: 21/21 twice.**

Lesson: two of the last three reported agent defects were test defects. As the agent improved, a
scripted turn shifted meaning and the suite mis-scored it. Scripted multi-turn evals measure the
*conversation shape* as much as the agent.

## 2026-09-18 — Second voice test: double confirmation fixed (v13); display flag (v14); rich link (v12)

Third manual voice call. Record-page map works, links work.

**1. Double confirmation — fixed in v13, regression-tested.** After one question covering order
number *and* email, a "Yes" was still followed by "I have your email as …, is that correct?".
Cause: the system instruction said to confirm both together, but each subagent still carried the
older order-number-only read-back rule, so the model did both. All three lookup subagents now say:
confirm both in one question, a yes confirms both, act immediately, never ask a second
confirmation. New case `edge_single_yes_confirms_both` asserts the final reply contains no further
"is that correct".

**2. `filter_from_agent: True` was hiding the card (v14).** The rich choice documentation requires
**"Show in conversation"** on the output. The vendored reference defines it: *"`is_displayable:
False` is a compile-valid alias for `filter_from_agent: True`"* — **the same flag**. v12 set
`is_displayable: True` *and* `filter_from_agent: True`, i.e. displayable and hidden at once. v14
keeps only `is_displayable: True` and drops `mapImage`/`mapUrl` from the declared outputs.

**3. A test broke because the agent improved.** `track_delivered_order` started failing: with the
v13 fix the agent answers in the *first* turn when the caller supplies both details, so the
scripted "Yes, that's correct." turn drew only a closing pleasantry, and the harness scores the
last turn. Fixed in the harness: `match_scope: conversation` on cases whose answer may land on
either turn, which applies to `contains_*` **and** `must_not_contain`. Cases without the flag keep
last-reply scoping, which keeps "the final reply must not ask for confirmation again" meaningful.
**Runs 15 and 15b: 20/20 twice.**

**Rich link response (agent v12).** Contract from the Salesforce Help page *"Adaptive Response
Format: Rich Link Response"*:

- An invocable action returns `List<ItemDetail>` with the **fixed** field names `linkURL`,
  `linkTitle`, `linkImageURL`, `linkImageMimeType`, `descriptionText`, mapping to the **Enhanced
  Link** messaging component.
- **Service Agent only.** One image and one URL per response (several need a rich *choice*
  response). PNG/JPEG only.
- Renders on Enhanced Chat V1, Apple Messages for Business and LINE; other channels fall back to
  text, so the spoken answer must stand alone.
- Static-map URLs have no file extension, so `format=png` is added and `linkImageMimeType` is set
  explicitly (otherwise it defaults to `image/jpeg`).
- `complex_data_type_name` for an Apex inner class is **`@apexClassType/c__Class$Inner`** (the
  publish error states the exact form after `@apexClassType/Class.Inner` is rejected).
- **The card rides on `OCC_GetOrderDeliveryInfo`, not a separate action.** A standalone
  `OCC_GetOrderMapLink` was built first and the model did not call it (trace: only
  `GetOrderDeliveryInfo` ran). Merging removes that dependency and costs no extra callout. The
  class stays deployed but unused because agent v11 references it and blocks deletion — same as
  `OCC_PolicyFAQLookup`. Delete both after the demo.
- **Run 12 (v12): 19/19.**

**Map surfaces.** Per an external article
(`infallibletechie.com/2025/02/display-image-in-salesforce-agentforce.html`), an action output
rendered as **Rich Text** displays HTML. In Agent Script that is `object` +
`complex_data_type_name: "lightning__richTextType"`, as the Knowledge action uses; `mapImage` was
switched to it in **v8**.

The Agent API cannot carry the picture: **every message comes back with `"result": []`** — text
only, no structured action output. Each visual surface therefore fetches the map itself:

- `OCC_DeliveryMap` — shared service (Routes call, static-map URL, haversine fallback, age in
  words). The agent action, the record page and the REST endpoint all call it, so they cannot
  drift apart.
- `OCC_OrderMapController` + `occOrderDeliveryMap` LWC — map on the `Order__c` record page. Record
  access governs it (`USER_MODE`), so no email check: the agent action verifies identity because
  the *caller* is unverified; an internal user on the record page is not.
- `OCC_OrderMapRest` — `GET /services/apexrest/keyburn/ordermap?email=&orderNumber=` for the
  Phase 11 page, with the **same email + order verification as the agent action**, so it never
  reveals an order the caller has not identified.
- `CspTrustedSite` for `maps.googleapis.com` with `img-src`, required for Lightning to load the
  image.
- 45/45 Apex tests pass, including "another customer's order returns no map".

---

## 2026-09-18 — Phase 9 built: live order tracking on a map (agent v6, 18/18 twice)

Caller asks "where is my order?" → the agent speaks distance, driving time and position age, and
the action returns a Google static map of **warehouse → parcel → delivery address**. Verified end
to end through the Agent API, including the real Google callout. Reports:
`eval_report_run07_agent_v5_tracking.json` (18/18), `run08` (16/18, stricter tests), `run09` +
`run09b` (18/18 twice on v6).

**Google Maps setup.** Directions (legacy) is superseded by the **Routes API**; Maps Static API was
enabled, and the key's *API restrictions* list both. Working calls:

- Routes: `POST routes.googleapis.com/directions/v2:computeRoutes`, key in `X-Goog-Api-Key`,
  `X-Goog-FieldMask` selecting duration, distance, polyline **and legs**.
- Static map: markers `W`/`O`/`D` plus `path=enc:<polyline>`.

**One call covers the whole picture:** origin = warehouse, `intermediates` = the parcel's current
position, destination = the customer. The full polyline draws the journey, while **`legs[last]`**
gives the distance actually left to drive (the totals would overstate it).

**Data model:** `Order__c.Current_Location__c` (Geolocation, 6 dp) + `Location_Updated__c`
(DateTime, so the agent says "reported 9 minutes ago" rather than implying live GPS). Delivery
address = the Contact's `Mailing*` fields with explicit coordinates. `scripts/set_demo_geodata.apex`
(idempotent, no secrets) gives the five demo contacts Madrid addresses and places each Shipped
order along its route.

**Decisions and platform notes:**

- **Custom metadata records cannot be deployed in this org.** The `Keyburn_Setting__mdt` type
  deploys; a *record* fails with `UNKNOWN_EXCEPTION` and no component error, even a minimal one.
  Type permissions were ruled out: the **Apex Metadata API creates the same record** as the same
  user. The record is therefore created by `scripts/set_keyburn_settings.apex` (git-ignored,
  generated from `secrets.env`), which also keeps the API key out of the repo. Custom metadata was
  chosen over a custom setting; `Keyburn_Config__c` was removed from org and repo.
- **`.forceignore` excludes `**/*.example`** — otherwise the CLI parses the templates as metadata
  and the deploy fails with the same opaque `UNKNOWN_EXCEPTION`.
- **`Contact.Mailing*` fields cannot take `fieldPermissions`** in a permission set ("Invalid field
  permission field name") — every component, including Street/City/PostalCode. Same class as
  constraint 5; object read grants them.
- `Decimal.valueOf()` has no `Decimal` overload — the haversine constant is a `Double`.
- PowerShell `Set-Content -Encoding utf8` writes a BOM, and Apex then fails with "Invalid
  identifier". Write Apex scripts with `[IO.File]::WriteAllText(..., UTF8Encoding($false))`.

**Run 08 caught a fabrication.** With tracking at 18/18, the agent still told callers with
*unshipped* or *delivered* orders "you can see a map in the chat" when no map existed. Adding
`must_not_contain: ["map"]` to those cases turned it into a failure (16/18); v6 gates the mention on
`inTransit` and both pass. An example of an eval suite catching a plausible-sounding invention
that a human reviewer could miss.

---

## 2026-09-17 — Phase 8 closed; three feature phases added; demo moves to Phase 12

**Phase 8 closed** at 14/15 on agent v4, stable across runs 06 and 06b. The remaining failure is
test wording, carried as a test-only fix.

**Decision: add three feature phases before the demo; demo and deck remain the last phase.** Full
plan with steps, spikes and cut-offs in `docfiles/BUILD_RUNBOOK.md`.

| Phase | Feature | Biggest unknown (spike first) |
|---|---|---|
| 9 | Order geolocation: "where is my order?" with location on a map | How the map is rendered, and on which surface |
| 10 | `Draft` order status + order-workflow diagram in a Knowledge article, explained by the agent | Whether an embedded image can be interpreted (Data Library retrieval is text-based) |
| 11 | External "real call" page via Amazon Bedrock Nova 2 Sonic | AWS access/region for Nova 2 Sonic; the bidirectional streaming SDK; whether the Agent API returns structured action output |
| 12 | Demo + deck (was Phase 9) | — |

Decisions recorded with the plan:

- **Agent v4 is frozen as the demo-safe fallback.** Each new phase publishes a new version; an
  unfinished phase is rolled back and presented as design rather than live demo.
- **Phase 11 architecture: Agentforce stays the brain; Nova 2 Sonic handles only speech in and
  out**, with one tool that relays each turn to the existing Agent API session. This keeps the
  guardrails, permission sets, escalation handling and eval evidence valid for the new channel.
  Rejected: Nova as the reasoning agent calling Salesforce actions directly, which would duplicate
  reasoning and bypass everything Phase 8 validated.
- **Schedule:** about 3.5 build days for three features before Phase 12 on Tue 22. Each phase has a
  cut-off in the runbook. Phase 11 carries the most risk and comes last, so a slip affects only
  that feature.

**Requirements:**

1. **Channel: voice chat with a screen**, not a blind phone call.
2. **AWS:** account `__AWS_ACCOUNT_ID__`, region `eu-north-1`, Bedrock access to Nova 2 Sonic granted.
3. **Phase 10:** the agent must genuinely analyse the image; a pre-written text description is not
   acceptable.
4. **Phase 9:** the map is *embedded* in the chat (not a link), orders carry live GPS coordinates,
   and the map shows the route **warehouse → current position → Contact address** with the
   remaining **driving** time. Two spikes gate the build: (A) what renders an embedded map in the
   chat; (B) which routing provider gives a real driving time (Google Maps Platform).
5. **Phase 10 stays on-platform: a multimodal Prompt Template**, not a Bedrock vision call from
   Apex. Spike Prompt Builder first: which template type accepts an image, which models are
   multimodal, and how the image is passed. AWS belongs only to Phase 11.
6. **Phase 11 follows** Phases 9 and 10.

**Google Maps key tested (demo key, usage-limited):**

| API | Result |
|---|---|
| **Routes API** (`routes.googleapis.com/directions/v2:computeRoutes`) | **Works.** Warehouse → customer: 7010 m, 1496 s, encoded polyline returned. Provides the driving time and the route line. |
| Directions API (legacy) | `REQUEST_DENIED` — superseded by Routes API. Not needed. |
| **Maps Static API** | Required to embed the map image; enabled for Phase 9. |

The key is never committed: it lives in an org-side record, with a placeholder in the repo. A
static-map URL embedded in chat exposes the key to the client, so it is restricted (referrer + API
restrictions) and rotated after the demo, like the ECA secret.

---

## 2026-09-17 — Runs 05 (test fixes) and 06/06b (agent v4): 14/15, stable

**Run 05 — tests only, agent v3 unchanged: 13/15.**
`eval_reports/eval_report_run05_test_fixes.json`.

- All four escalation cases now require `"case number is"` and forbid
  `"will receive a case number"`, including `escalation_unverifiable_caller`, whose old expectations
  predated the logged-case decision.
- Widened the "offer to open one" phrases.
- `case_open_new_support_case` now requires a spoken case number.
- The stricter tests turned run 04's false pass (`edge_out_of_scope_request`) into a real failure.

**Root-caused with traces.** The CLI's programmatic preview (`sf agent preview start/send/end` plus
`sf agent trace read --dimension routing|actions`; commands in `CLAUDE.md`):

- *Unverifiable caller:* **the router re-classifies every turn from scratch** ("From Topic:
  null"). Turn 1 → `order_status`; turn 2 ("I don't remember… search by my name") →
  `ambiguous_question`, which had no route to escalation. The Order Status "escalate immediately"
  instruction never ran.
- *Out of scope:* routed correctly to `escalation` every time, but in about 1 of 5 traced runs
  **the model skipped `CreateEscalationCase`** and promised "a team member will follow up / you
  will receive a case number". An instruction alone is not sufficient.

**Agent v4 + Apex (run 06):**

- **Escalation made structural rather than prompt-dependent:**
  - `CreateEscalationCase` output is captured into `@variables.escalation_case_number`; the action
    is `available when` it is empty.
  - The instructions branch on that variable: while empty, the model sees only "your first step
    must be to call the action; promise nothing"; once set, only "read case N to the caller".
  - An **`after_reasoning` safety net** runs `CreateEscalationCase` deterministically
    (`reasonCode = unlogged_escalation`) if the variable is still empty after reasoning, so a caller
    is never promised a follow-up without a Case behind it. (Removed in v7; see that entry.)
  - The Case exists regardless of what the model does; the spoken number still depends on the
    model, and the tests check it.
- Router: `go_to_escalation` explicitly covers "don't remember / don't have my email or number,
  look me up by name". `go_to_ambiguous_question` excludes it. `ambiguous_question` gained a
  `go_to_escalation` action as a second line of defence.
- `CreateSupportCase` output is captured into `support_case_number`, and the instructions require
  stating it.
- The ORD-prefix read-back rule moved into the system instructions, so it applies in every
  subagent.
- The Escalation "apology" wording became "briefly acknowledge how they feel", removing the
  conflict with the platform's "avoid apologies" rule.
- `OCC_GetOrderStatus` returns **ISO `yyyy-MM-dd` dates** instead of locale-dependent
  `Date.format()`, closing the Phase 7 date bug.
- `OCC_ListOpenCases` presents `Agent escalation: <code>` subjects as "a request for a team member
  to follow up".
- 30/30 Apex tests pass (new tests: ISO date format, reason code not spoken).

**Run 06 (v4): 14/15. Run 06b (identical repeat): 14/15, same single failure.**
`eval_report_run06_agent_v4.json`, `eval_report_run06b_agent_v4_repeat.json`.

- Verified in the org: each run created exactly 4 escalation Cases (one per escalation test,
  correct reason codes) and 1 alex.chen support Case, with **zero `unlogged_escalation` Cases** —
  the safety net was not needed.
- Remaining failure is test wording: `case_open_new_support_case` requires "opened", but the agent
  says "Your support case number is 00001054…", which meets the requirement. Fixed in the next
  test-only change.

---

## 2026-09-17 — Agent v3: open-cases feature; eval run 04

**Trigger:** in a voice test, a caller who had just confirmed email + order 1042 asked "Do I have
any case open?". The agent asked for a case number, the caller had none, and the call was escalated
as `unverifiable_identity` (Case 00001034). The same transcript showed the email confirmed twice.

**Requirement:** when a caller asks about open cases, answer from data; if there are none, say so
and offer to open one.

**Decision: listing and creating cases require email plus an order or case number belonging to
that caller**, not email alone. Email alone would let anyone who knows an address hear that
customer's case subjects. This extends the structural-verification pattern and is enforced in Apex
(`OCC_CaseLookupUtil.verifiedContactId`), not in the prompt. In the transcript scenario, the
already-confirmed order number is the proof.

Built:

- `OCC_ListOpenCases`: verified caller → open case count and up to 3 most recent "case number,
  subject". Uses `IsClosed = false`.
- `OCC_CreateSupportCase`: verified caller + issue summary → Medium-priority Case linked to the
  Contact. Writes only Subject/Priority/ContactId, already granted by the agent permset — **no new
  FLS required**. Deliberately separate from escalation (normal priority, caller-requested).
- `OCC_CaseLookupUtil.verifiedContactId(email, identifier)`: shared by both.
- Tests include the boundary cases (another customer's real order number does not verify; nothing
  is disclosed or created when unverified). 28/28 Apex tests pass. Both classes are in both
  permsets.
- Agent v3: Case Status subagent handles specific case / list open / open new; router description
  on `go_to_case_status`. The system instruction asks for **one combined read-back of number +
  email and no re-confirmation later in the call**.

**Eval run 04 (v3), 15 cases: 12/15. Original 11: 10/11, no regression vs run 03.**
`eval_reports/eval_report_run04_agent_v3_open_cases.json`. Harness gained `contains_any_groups`
(AND of ORs). Four `open_cases` cases added.

Verified in the org, beyond the scores:

- `CreateSupportCase` ran as the agent user: Case 00001037, alex.chen, Medium, caller's wording.
- `edge_open_cases_after_order_lookup` (the transcript regression) passes: after the order lookup,
  "Do I have any open cases?" is answered directly with no new identifiers.

Defects found (addressed in v4 / run 05):

1. **False pass:** `edge_out_of_scope_request` passed, but **no Case was created**. The agent said
   "a team member will follow up… you will receive a case number" without calling the action. Run
   03 created one (1033) for the same prompt, so this is nondeterministic. The test's
   `"team member"` phrase cannot distinguish a real escalation from a promise; escalation tests
   should require the spoken case number.
2. `case_open_new_support_case` failed legitimately: the case was created, but the agent
   paraphrased the action message and **omitted the case number**.
3. `case_list_open_none_offers_to_open` failed on test wording only; the reply matched the required
   behaviour.
4. **Internal labels reached the caller:** escalation case subjects are
   `Agent escalation: <reason_code>`, so cases were described as "about unverifiable identity, a
   financial request". `OCC_ListOpenCases` should present these as a team-member follow-up
   request.
5. The Case Status read-back spelled "O R D dash 1 0 3 8". The "leave out the ORD prefix" rule
   lived only in the Order and Return subagents; move it to the system instructions.
6. `escalation_unverifiable_caller` still failed, with a third distinct reply across runs.

---

## 2026-09-17 — Voice verified on agent v2; voice trace findings

Voice preview tested manually on v2: working. The session escalated and created Case `00001034`
(`unverifiable_identity`), **created by the agent user and linked to Jane Doe's Contact** — the
first escalation carrying a verified email end to end.

Findings from the plan trace (`__current_modality__: voice`, `__current_connection__: telephony`)
that the text-only Agent API eval cannot observe:

1. **The platform injects a voice prompt that converts spoken "O" to 0** in "account numbers, and
   other numerical identifiers". On a voice call, "O-1O42" is likely normalised to 01042 before the
   agent instructions apply; `normalize()` then strips the zero, so it matches ORD-1042. The
   scripted misheard-number moment should therefore be rehearsed in voice; a digit mishearing
   (e.g. 1042 heard as 1024) exercises confirm-back more reliably.
2. **The voice prompt requires every date as `<date val="YYYY-MM-DD">`**, so the LLM converts
   whatever the action returns into ISO. Further support for the ISO date fix.
3. **The platform response guidelines say "Avoid apologies"**, which conflicted with the Escalation
   instruction to open with a brief apology. Run 03 showed the conflict.
4. Call closing is handled correctly: "No." at the end received a proper goodbye, even though the
   trace routed it through `case_status`.
5. `customer_email` / `confirmed_identifier` variables are declared but never set (null all
   session). Dead config: wire in or remove.

---

## 2026-09-17 — Eval runs 02 (test fixes, 6/11) and 03 (agent v2, 10/11)

**Run 02 — test and harness fixes only, agent unchanged: 6/11 (55%).**
`eval_reports/eval_report_run02_test_fixes.json`. Changes:

- Added a "Yes, that's correct." turn to the four cases that stopped at confirm-back.
- Added `"working"` to `happy_case_status` expectations (case 1026's real status is Working).
- `run_eval.py` now scores **only the final turn's text**. Previously a silent final turn fell back
  to the previous turn's text and could pass on stale content. It also records non-`Inform`
  messages (e.g. `Escalate`) and a per-turn `transcript` in the report.

The +3 comes entirely from the tests and is recorded as a test improvement, not an agent
improvement.

**Retrieving the agent into source control surfaced two things:**

1. **Root cause of the silent escalations:** the Escalation subagent's only action was
   `@utils.escalate` (platform transfer to a human). `OCC_CreateEscalationCase` was not wired into
   the agent. With no Omni-Channel route, the transfer is a dead end: no text, no Case.
2. **Correction to the 2026-09-15/17 entry below:** the "read back plain digits" confirm-back edit
   was saved in Agent Builder but **not published**. Active v1 was the 09-14 build. Saving,
   publishing and activating are separate steps.

**Run 03 — agent v2, same suite as run 02: 10/11 (91%).**
`eval_reports/eval_report_run03_agent_v2.json`. Edits to the draft `.agent` (on top of the 09-15
draft), validated, published as v2 and activated; v1 remains for rollback.

- Escalation subagent: `@utils.escalate` replaced with `CreateEscalationCase`
  (`apex://OCC_CreateEscalationCase`). The subagent picks the reason code, passes email only if
  already given, and relays the returned message.
  **Decision: escalation = logged case + callback, not live transfer** — there is no routing target
  for either the Agent API or the voice preview, so a transfer can only fail silently.
- Router: descriptions on `go_to_escalation` (refund/money, frustration or repeat contact, cannot
  verify, out of scope incl. account cancellation) and `go_to_return_eligibility` (explicitly not
  refund demands).
- Order, Case and Return subagents: if the caller does not know an identifier, escalate
  immediately instead of asking again. Order and Return subagents drop the standard ORD prefix on
  read-back but read out any other letters.
- Case Status: state the status as returned; if `openRelatedCaseCount > 0`, offer a team-member
  follow-up.

Verified beyond the pass rate: all three escalation Cases from run 03 (00001031–33) were created
**by the agent user** with correct reason codes and coherent summaries — the first execution of
`OCC_CreateEscalationCase` as the agent user. Case 00001030 was an admin smoke test.

Remaining failure: `escalation_unverifiable_caller` (root-caused in run 05: per-turn router
re-classification).

---

## 2026-09-17 — Phase 8 started: baseline eval run 01 = 3/11 (27%)

First end-to-end run of `src/eval_cases.yaml`, suite and agent both **unmodified**, via the Agent
API with `bypassUser: true`. Report saved as `src/eval_reports/eval_report_run01_baseline.json`,
the baseline for comparison.

Passed: `happy_policy_faq`, `happy_policy_faq_shipping`, `edge_ambiguous_order_number`.

Triage of the 8 failures — **not all agent defects**, and the distinction determines how the
pass-rate climb is reported:

**A. Test-design defects (4) — agent behaved correctly.** `happy_order_status`,
`happy_case_status`, `happy_return_eligibility`, `edge_topic_switch_midcall` all end on the agent's
confirm-back ("I heard order … is that correct?"). The scripts predate the confirm-back design and
never send a "yes" turn, so the harness scores a mid-flow reply. Fixed in the YAML and labelled as
a test fix.

**B. Agent routing defect — platform `Escalate` with no target (2).**
`escalation_frustrated_customer` and `edge_out_of_scope_request` returned *no text*. The raw API
response is a single message `{"type": "Escalate", "targets": []}`: the agent invoked the platform's
built-in human handoff instead of transitioning to the custom Escalation subagent. Over the Agent
API (and on a voice line) there is no Omni-Channel route, so the caller gets silence and **no Case
is created**. The harness showed an empty reply because `run_eval.py` reads only `Inform`
messages. The most serious finding: the designated exit path dropped the customer.

**C. Agent instruction-following defects (2).**

- `escalation_refund_request` — the agent refuses the refund (hard limit held) but redirects to a
  return-eligibility lookup instead of escalating as a `financial_request`.
- `escalation_unverifiable_caller` — the caller says they don't remember email or order number;
  the agent asks for the order number again instead of escalating as `unverifiable_identity`.

**Also observed:** `edge_ambiguous_order_number` passed, and the agent read "O-1O42" back as
containing the letter O — correct confirm-back behaviour for the misheard-number path.

---

## 2026-09-17 — Phase 7 complete: Agent API live end to end

External Client App `Keyburn_ECA` issues client-credentials tokens; a two-turn Order Status
conversation (question → confirm-back → answer) succeeds over the Agent API with both values of
`bypassUser`. Consumer key/secret are **not** stored in the repo — env vars only. Rotate the secret
after the demo.

Three configuration errors resolved in sequence, each with a distinct signature:

1. `invalid_grant` / *no client credentials user enabled* — the ECA Policies tab had no **Run As**
   user for the client credentials flow.
2. `invalid_app_access` / *user is not admin approved to access this app* — Permitted Users is
   admin-approved; the Run As user needed a permission set attached in the ECA's App Policies.
   Chosen over "All users may self-authorize" for least privilege.
3. **Empty-body HTTP 404 from `api.salesforce.com` on session start.** The token was an opaque
   `00D...` session token; the Agent API gateway accepts only JWT access tokens (`eyJ...`). Fix: ECA
   Settings → **Issue JWT-based access tokens for named users** (and untick the require-secret /
   PKCE boxes). The 404 gives no hint of this; check the token prefix first.

**`bypassUser` verified empirically, surfacing a real bug.** Same conversation, two answers for
ORD-1042's estimated delivery:

- `bypassUser: true` → "September eleventh" (correct; record says `2026-09-11`)
- `bypassUser: false` → "November ninth" (wrong)

Root cause: `OCC_GetOrderStatus` formatted dates with `Date.format()`, which is **locale-dependent
on the running user**. With `true`, actions run as the agent user (`en_US` → `9/11/2026`). With
`false`, they run as the ECA's Run As user — the admin, locale `es_ES` → `11/09/2026`, which the LLM
reads US-style as November 9. This is direct evidence of *whose* identity executes the actions: with
`false` the admin's CRUD/FLS/sharing apply, not the agent user's least-privilege permset.
**Decision: the eval harness and demo use `bypassUser: true`.** Date fix delivered in v4.

---

## 2026-09-17 — Phase 6 complete: Agent ID and My Domain collected

Pulled from the CLI rather than Setup, so they are reproducible:

| Value | Result | Source |
|-------|--------|--------|
| `SF_AGENT_ID` | `__AGENT_ID__` | `SELECT Id FROM BotDefinition WHERE DeveloperName = 'Keyburn_Customer_Service'` |
| `SF_MY_DOMAIN_URL` | `https://__MY_DOMAIN__.develop.my.salesforce.com` | `sf org display` → `instanceUrl` |

- The Agent API expects the **BotDefinition** Id (`0Xx` prefix), not the BotVersion Id (`0X9`).
- Developer Edition My Domains carry a `.develop.` segment — the URL above is the correct
  `.my.salesforce.com` form.
- The Agent API serves only active agents; check activation first if it returns "not found".

---

## 2026-09-17 — Workspace structure settled; one context file

**Decision: `AgentFDE/` is the workspace root and its `CLAUDE.md` is the single source of project
context.** The editor opens at `AgentFDE/`, not at `sfdx-project/`.

Alternatives considered:

- *Hoist `sfdx-project.json` + `force-app/` + `scripts/` to the repo root* so the workspace root
  and the CLI project root coincide. The more standard Salesforce layout, removing the need to
  `cd sfdx-project`. Deferred: before the demo it buys only that convenience, at the cost of file
  moves, `.sf` source-tracking churn, and a rewrite of every documented command plus
  `src/SFCLI_Script.txt`. Revisit after 2026-09-23.
- *Use `sfdx-project/` as the workspace root.* Rejected: the planning docs, eval harness and
  sample data live above it.

Consequence: the workspace root and the CLI project root are different directories. `sf` searches
*upward* for `sfdx-project.json`, so `sf` commands run from inside `sfdx-project/`.

**Consolidated context files.** `sfdx-project/CLAUDE.md` and `docfiles/HANDOFF_CONTEXT.md` were
~20 KB near-duplicates of the root `CLAUDE.md`. Their unique content (the `WITH USER_MODE`
throw-vs-silent distinction, the `UserRecordAccess` diagnostic, the empty-Debug-Log workaround,
Phase 7/8 notes) was folded into the root `CLAUDE.md` and this log, and both were removed.

**Fixed a drifted script.** `scripts/link_contacts_to_account.apex` on disk was still v1 — it
created a single shared Account ("Keyburn Retail Customers") and linked every unlinked Contact to
it, contradicting the chosen data model and the org state (one dedicated Account per Contact,
matched by `"FirstName LastName"`, loaded from `sample-data/accounts_sample.csv`). Restored to the
name-matching version and corrected the note in `CLAUDE.md`.

---

## 2026-09-17 — Spoken order numbers no longer need the "ORD-" prefix

`OCC_GetOrderStatus` and `OCC_CheckReturnEligibility` moved from a direct
`WHERE Order_Number__c = :orderNumber AND Contact__r.Email = :email` filter to the shape
`OCC_GetCaseStatus` already used: resolve the Contact by email, query that Contact's orders, then
match in Apex on `OCC_CaseLookupUtil.normalize()` of both sides. Spoken "1042" now matches stored
`ORD-1042`, as "1026" already matched `00001026`.

The confirm-back lines in the Order Status and Return Eligibility instructions were updated to read
back plain digits rather than spelling out `O-R-D-`. Requiring the caller to say a fixed
alphabetic prefix is precisely the alphanumeric-voice failure mode the design avoids.

---

## 2026-09-15 — Phases 1–5 complete; all five topics verified live

All five subagents confirmed answering correctly from real org data via Agent Builder transcripts
(not only unit tests). Return Eligibility also returned `GROUNDED` from the groundedness evaluator
and `HIGH` / `FULLY_RESOLVED` from guardrails.

**Root cause of the "not found" failures**, layer by layer:

1. Missing `<classAccesses>` in the permission sets — Agentforce blocks Apex invocation at the
   platform level *before* the method body or any `try/catch` runs, so exception surfacing
   produced nothing.
2. Three "cannot deploy to a required field" errors (`Knowledge__kav.Title`, `Case.CaseNumber`,
   `Case.Status`) — the fix is to delete the `<fieldPermissions>` entry, not to satisfy it.
3. With those fixed, queries returned empty *without throwing*. `UserRecordAccess` showed
   `HasReadAccess=false, MaxAccessLevel=None` on Contact — a sharing gap, not FLS.
4. **A Contact with no AccountId is always private, regardless of OWD.** Only the owner and admins
   can see it; sharing rules do not apply. The Einstein Agent User license was checked against
   official docs and **ruled out** — standard OWD applies to it normally.

**Decision: fix by record linkage, not sharing configuration.** OWD was reverted to its original
values and is off-limits (constraint 1 in `CLAUDE.md`). Each Contact has its own Account. A
targeted Sharing Rule scoped by Public Group was designed as a fallback and not needed.

**Decision: Policy/FAQ uses the native "Answer Question with Knowledge" action** over the
Agentforce Data Library rather than custom Apex. `OCC_PolicyFAQLookup` stays deployed but unwired
as a fallback.

**Voice works** via the native in-Builder preview (Enhanced Chat v2), configured following an
external setup guide. Production telephony requires a paid Voice add-on and is out of scope.

---

## Open items

- **Voice re-test on v3/v4 and later.** Last verified end to end on v2.
- **Voice configuration:** the specific setting that enabled voice preview was not isolated; a
  voice regression starts diagnosis from the setup guide.
- **Misheard-number moment:** rehearse in voice; the platform's O→0 conversion may pre-empt it
  (see the 2026-09-17 voice-trace entry).
- **Contact visibility after the OWD revert** has not been re-checked with a fresh
  `UserRecordAccess` query. Most likely Account-level access via ownership is sufficient under the
  org's Contact sharing model; live transcripts confirm it works.
- **`OCC_CaseLookupUtil` naming:** it now serves order lookups too. Renaming requires a destructive
  delete of the old class; scheduled after the demo.
- **Claudeforce availability** in this org (Claude as the Atlas Reasoning Engine model) is
  unconfirmed.

## Key design principles

- **The email-match filter combined with `WITH USER_MODE` / `as user` / `with sharing`** is the
  core guardrail: "the agent can only see the verified caller's records" is a structural fact
  enforced by the platform, not a prompt-level request.
- **The two permission sets are deliberately asymmetric**: least privilege for the agent user,
  full access for data administration.
- **`bypassUser`** in the Agent API determines whose identity executes actions; the harness and
  demo use `true` so the least-privilege permset applies.
- **Voice alphanumeric handling** is a documented trade-off, mitigated by confirm-back and
  normalisation.
- **The eval pass-rate history**, with test fixes and agent fixes labelled separately, is the
  reliability evidence.
