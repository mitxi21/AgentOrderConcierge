# Build Runbook — Order & Case Concierge

End-to-end sequence. Ordered by dependency, not by importance — each phase
unblocks the next. Rough time estimates assume you're familiar with Salesforce
Setup (you are), so they're mostly clicking and waiting, not learning.

**Critical path warning:** Phase 2 (Data Cloud) and Phase 7 (External Client
App) are the two things that can stall on provisioning or OAuth propagation
and eat a day you didn't budget. Start both earlier than feels necessary.

---

## Phase 0 — Decide your fallback first (15 min, do this before anything)

Before you build, write down your answer to: *what do I demo if Data Cloud
provisioning isn't finished, or the Agent API won't authenticate, on the
morning of the panel?*

Suggested fallbacks:
- **Data Cloud not ready** → drop Topic 4 (Policy/FAQ) to 3 topics, or ground
  it on a static set of Knowledge articles without semantic retrieval. Say
  explicitly in the panel that you scoped it out and why.
- **Agent API not ready** → run your eval cases manually through the Agent
  Builder testing console and screenshot the results. Less impressive, still
  honest.
- **Live demo fails entirely** → have a recorded screen capture of a working
  run. Record this the day before regardless. Every experienced panelist has
  watched a live demo die; having the recording ready is a signal of
  competence, not weakness.

---

## Phase 1 — Org prep and data model (1–2 hours)

1. **Confirm Agentforce is on.** Setup → Einstein Setup / Agentforce. Verify
   you can open Agent Builder and see the default agents.
2. **Create the `Order__c` custom object** with fields:
   - `Order_Number__c` (Text, External ID, Unique) — e.g. `ORD-1042`
   - `Status__c` (Picklist: Processing, Shipped, Delivered, Cancelled)
   - `Item__c` (Text)
   - `Order_Date__c` (Date)
   - `Estimated_Delivery__c` (Date)
   - `Return_Eligible__c` (Checkbox)
   - `Contact__c` (Lookup → Contact)
3. **Add an escalation field to Case:** `Escalation_Summary__c` (Long Text
   Area, 32k) — this is where your structured handoff context lands.
4. **Create sample data:**
   - 3–4 Contacts, with emails matching your eval cases exactly
     (`jane.doe@example.com`, `john.smith@example.com`)
   - 10–15 Orders across all statuses, including `ORD-1042` (Jane, Shipped)
     and `ORD-2077` (John, return-eligible)
   - 2–3 Cases, including `CASE-2291` for Jane

   Your eval file references these exact values — if they don't exist,
   every happy-path case fails for the wrong reason.

---

## Phase 2 — Enable Data Cloud and index Knowledge (2–4 hours, plus waiting)

**Do this early.** Provisioning can take anywhere from minutes to overnight.

1. **Enable Data Cloud.** Setup → Data Cloud Setup → run the setup flow.
   Wait for provisioning to complete before continuing — the later steps
   silently fail against a half-provisioned org.
2. **Enable Salesforce Knowledge** (Setup → Knowledge Settings) if it isn't
   already on, and create a Knowledge record type / article type.
3. **Write 4–6 Knowledge articles.** Real content, short, one topic each:
   - Return policy (state a specific window, e.g. 30 days)
   - Standard shipping timelines (state specific business-day ranges)
   - Warranty terms
   - Exchange process
   - Damaged/wrong item process

   Your eval expects strings like "day", "return", "business day" — write
   articles that actually contain concrete numbers, not vague prose.
4. **Publish the articles.** Drafts won't be retrieved.
5. **Set up retrieval.** In current Agentforce, the cleanest path is an
   **Agentforce Data Library** pointed at your Knowledge articles — it
   handles the Data Cloud ingestion, chunking, and vector indexing for you
   rather than you wiring a data stream and search index by hand. Verify the
   current setup path in Salesforce Help before you start, since this area
   has changed shape more than once.
6. **Test retrieval standalone** before wiring it to the agent — most Data
   Library UIs let you run a test query. Confirm "what's your return policy"
   returns the right article. Debugging retrieval through the agent is
   miserable; debugging it directly is quick.

---

## Phase 3 — Build the actions (3–5 hours)

Build and unit-test each action *before* the agent exists. An action that
works standalone but fails in the agent is a wiring problem; an action that
was never tested is a guessing game.

1. **`Get Order Status`** — Flow (or Apex invocable) taking `email` and
   `orderNumber`, querying `Order__c` where the order number matches AND the
   related Contact's email matches. Returns status, item, estimated delivery.
   Returns a clear "not found" signal when there's no match — don't let it
   return null and force the agent to interpret.
2. **`Check Return Eligibility`** — same inputs, returns eligible/not plus a
   one-line reason (within window / outside window / not eligible item type).
3. **`Get Case Status`** — can use the standard Case lookup action, or write
   your own for consistent output shape.
4. **`Update Case`** — appends a customer comment to an existing case.
5. **`Create Escalation Case`** — Flow taking a summary string and a reason
   code, creating a Case with `Escalation_Summary__c` populated and Priority
   set to High for the frustration path.

**The email-match filter in every lookup is your data-access guardrail** —
it's what makes "the agent can only see the verified caller's records" a
structural fact rather than a prompt-level request. Be ready to say that in
the panel; it's exactly the kind of distinction they're probing for.

---

## Phase 4 — Build the agent (2–3 hours)

1. **Agent Builder → New Agent.** Choose an agent type that supports the
   Agent API — **not** "Agentforce (Default)", which the API doesn't support.
   A Service-type / custom agent is what you want.
2. **Paste the General Instructions** from `agent_builder_topics.md`.
3. **Create the 5 topics**, pasting each Classification Description and
   Instructions block, and attaching the corresponding action(s).
4. **Assign the agent user** and its permission set. Give it access to
   `Order__c`, Case, Contact, and Knowledge — and nothing else. Least
   privilege here is a talking point later.
5. **Test in the console (text mode)** as you go, one topic at a time. Don't
   build all five then test — you'll have no idea which change broke what.
6. **Activate the agent.** The Agent API requires at least one activated
   agent.

---

## Phase 5 — Voice testing (1 hour)

Switch the testing console to voice preview and run each topic once by
speaking. Expect the alphanumeric problem immediately — "ORD-1042" spoken
aloud will get mangled. That's not a bug to hide; it's your best
Issues & Trade-offs material. Note exactly how it fails and what your
confirm-back instruction does about it.

---

## Phase 6 — Get the Agent ID and My Domain (10 min)

- Agent ID: your agent's detail page in Setup.
- My Domain URL: Setup → My Domain → **Current My Domain URL**. Use the
  `.my.salesforce.com` value, not the `.lightning.force.com` one you see in
  the browser — this trips people up constantly.

---

## Phase 7 — External Client App for the API (1 hour, plus propagation)

Follow the README in the eval harness. Two known snags:
- After creating the ECA, credentials can take up to ~15 minutes to
  propagate. An "invalid client ID" error immediately after setup usually
  isn't your mistake — wait and retry.
- The `bypassUser` flag determines whose permissions the agent runs under.
  Test both values and understand the difference; it's directly relevant to
  your data-access guardrail story and is a very likely panel question.

Verify with a single manual `curl` (start a session, get the greeting back)
before running the eval suite. Isolate auth problems from harness problems.

---

## Phase 8 — Run the evals and iterate (3–6 hours, this is the real work)

1. `pip install requests pyyaml`, export the four env vars, run
   `python run_eval.py eval_cases.yaml`.
2. **Expect a bad first run.** 50–70% pass is normal and is *good material* —
   save that first `eval_report.json`. A before/after comparison is far more
   compelling to a panel than a suite that passed on the first try (which
   mostly signals the tests were too easy).
3. Read the failures, edit the relevant topic's Instructions in
   `agent_builder_topics.md`, re-paste into Agent Builder, re-run.
4. Keep every report. Two or three saved runs showing the pass rate climbing
   *is* your Reliability & Evaluation slide.
5. Use Claude Code for the loop: point it at `eval_report.json` and have it
   propose instruction edits, then re-run and diff.

---

> **Phase 8 closed 2026-09-17** at 14/15, stable across two runs on agent v4.
> Phases 9–11 below were added on 2026-09-17. The demo and deck moved to
> **Phase 12, which always stays last**.

---

## Rules for every phase from 9 onwards

- **Agent v4 is the frozen, demo-safe fallback.** Every phase publishes a new
  version. If a phase is incomplete by its cut-off, reactivate the last good
  version, and the feature appears in the deck as design or next steps, not in
  the live demo.
- **A phase is done only when:**
  1. new eval cases exist for the feature;
  2. the full suite has been re-run twice with no regression;
  3. anything that writes data has been checked in the org;
  4. voice has been spot-checked in the Builder preview;
  5. the org UI changes have been retrieved into `sfdx-project/`.
- New Apex follows the existing action pattern and the standing constraints:
  `with sharing`, `USER_MODE`, email + identifier verification, `classAccesses` and
  FLS in both permission sets, clean customer-facing messages.

---

## Phase 9 — Live order tracking on an embedded map (target: 1–1.5 days)

**Goal:** the caller asks "where is my order?". The chat shows a **map embedded
in the conversation** with the route **warehouse → current position → delivery
address** and a marker on where the order is right now, while the agent
**speaks** the remaining driving time ("your order is 20 km away, about
35 minutes by car"). Channel: voice chat with a screen.

**This is the most technically uncertain phase, because two things have to be
true at once:** the chat surface must render an embedded map, and something must
compute a real driving route. Both spikes come before any build.

1. **Spike A (≤ 2 h): how a map renders inside the chat.** The reference script
   (`src/mapscriptexample.txt`) only emits a plain-text URL, so it does *not*
   answer this. Options, most likely first:
   - **Rich-text action output with a static map image.** Our Knowledge action
     already returns `complex_data_type_name: "lightning__richTextType"`, so
     Agentforce can render HTML from an action. An `<img>` whose `src` is a
     static-map endpoint (route polyline + markers baked into the URL) shows a
     real map inside the chat with no LWC. Needs the image host allowed by CSP /
     Trusted URLs, and a map provider key.
   - **Custom Lightning type + LWC renderer** (`lightning-map`). Native and
     key-free, but `lightning-map` shows markers, not routed polylines, so the
     route line may not be drawable.
   - **Link fallback** (the reference script's behaviour) if neither renders.
   Test each in the actual demo surface — Builder preview *and* Enhanced Chat —
   because rendering differs per channel.
2. **Spike B (≤ 1 h): the driving route and ETA.** A real "remaining time by
   car" needs a routing engine:
   - Google Directions API (+ Static Maps for the image) — needs a
     billing-enabled Google Maps Platform key, a Named Credential and Trusted
     URLs. Most faithful to the requirement.
   - OSRM / OpenRouteService — free tier, no billing, but public demo endpoints
     are rate-limited and unsuitable for anything but a demo.
   - Great-circle distance + average speed — no dependency, but it is an
     estimate, not a driving time. Acceptable only as the degraded fallback.
   **Blocked on the builder:** which provider/key (see Open questions).
3. **Data model** (per-order live position, as requested):
   - `Order__c.Current_Location__c` — Geolocation (decimal, 6 dp): where the
     order is *right now*.
   - `Order__c.Location_Updated__c` — DateTime, so the agent can say "as of
     10 minutes ago" and never imply real-time GPS it doesn't have.
   - Delivery destination: the **Contact's mailing address** + coordinates
     (each Contact already has its own Account, constraint 2). Add addresses and
     lat/long to `sample-data/contacts_sample.csv` — explicit values, because
     org geocoding rules are asynchronous and unreliable in a dev org.
   - Warehouse origin: custom metadata (`Keyburn_Setting__mdt`: label, address,
     latitude, longitude), deployable and not hard-coded.
   - FLS: read on all new fields in the agent permset, full access in DataAdmin.
   - Sample data: coordinates for the Shipped orders, positioned between the
     warehouse and each customer. Optionally a small anonymous-Apex script that
     nudges `Current_Location__c` along the route, so the position visibly moves
     between demo runs.
4. **Action:** new `OCC_GetOrderDeliveryInfo` — email + order number verified as
   usual. Returns: current position, distance remaining, driving time, the map
   payload (rich text or coordinates, per Spike A), `locationUpdated`, and a
   spoken-safe `message`. Only Shipped orders have a position; Draft/Processing/
   Delivered/Cancelled return a clean explanation instead of an invented one.
   Keep it separate from `OCC_GetOrderStatus` so existing status evals are
   unaffected.
5. **Agent:** add the action to Order Status; instructions must speak the
   distance and driving time and never read out a URL or raw coordinates.
   Extend the router description with "where is my order / how far away is it /
   track my package".
6. **Evals:** Shipped order (distance and driving time spoken, map payload
   present, no `http` in the spoken text); Processing order (no position
   invented); Cancelled order; email mismatch (nothing leaked).

## Phase 10 — Draft order status + order-workflow diagram in Knowledge (target: 1 day)

**Goal:** orders can be in Draft, and the agent can explain the order workflow
from a diagram stored in a Knowledge article.

**Status 2026-09-18: done (agent v38, eval run 27 26/27).** The spike passed (Flex template + File
input + GPT-4o). The "option (a) text description" fallback in the calendar was never needed. See
`project-status.md`.

1. **Draft status:** add `Draft` to the restricted `Status__c` picklist, before
   Processing. The workflow becomes
   Draft → Processing → Shipped → Delivered, with Cancelled possible before
   shipping (to confirm). Decide what the agent tells a caller about a Draft
   order (e.g. "not submitted yet"). Update the status descriptions in
   `OCC_GetOrderStatus` and the agent script, and add one Draft order to the
   sample data. Return eligibility is unaffected (it reads
   `Return_Eligible__c`).
2. **The agent must actually read the image** (builder's requirement: a
   pre-written text description of the diagram is **not** acceptable). Text
   retrieval over the Data Library won't do this, so the image goes to a
   vision-capable model at question time.

   **Approach (builder's decision): stay inside Salesforce — a multimodal
   Prompt Template**, invoked by the agent as a prompt-template action, with a
   model that accepts an image. No AWS in this phase; Bedrock stays a Phase 11
   concern.
   - **Spike first (≤ 2 h), before any build:** in Prompt Builder, confirm
     (a) which template type accepts an image input in this org, (b) which
     models available in Einstein/Models API are multimodal, and (c) how the
     image is passed — a file/`ContentVersion` reference, a related record
     field, or a URL. Get one successful "describe this diagram" response in
     Prompt Builder's own preview before wiring anything to the agent.
   - Then expose it as an agent action (prompt template action) on the Policy/
     FAQ subagent, with the diagram as the input and the caller's question as
     the free-text input.
   - Keep the diagram small and legible: a voice answer needs 2–3 sentences, so
     the template's instructions must ask for a spoken-style summary, not a
     full transcription of every box in the flowchart.
   - If Prompt Builder in this org turns out not to accept images, that is a
     finding worth recording, and the options become: Salesforce Models API
     called from Apex, or (deferring to the Phase 11 account) a Bedrock vision
     model via a SigV4 Named Credential. Do not substitute a pre-written
     description.
3. **Knowledge:** create the workflow diagram image and a "How an order moves
   through Keyburn" article (record type `Policy_FAQ`) that embeds it.
   `Article_Body__c` is already rich text (`Html`), so no schema change is
   needed. Add it to `docfiles/knowledge_articles.md`, publish it
   (`scripts/publish_knowledge_articles.apex`), and wait for Data Library
   re-indexing before testing. The diagram must show `Draft` so the image and
   the picklist agree.
4. **Agent:** the Policy/FAQ subagent keeps using Knowledge for text questions,
   and routes "explain the order workflow / what does this diagram show" to the
   new action. Make it explicit that the answer comes from reading the diagram.
5. **Evals:** "what happens after I place an order?" (steps in order, including
   Draft); "what does Draft mean?"; "can I cancel after it ships?". At least one
   case must be answerable *only* from the image, so a regression back to text
   retrieval fails the suite.
6. **Panel-facing point:** this is the multimodal step of the build — a
   customer-service agent reading an internal process diagram on demand, with the
   image, not a transcription, as the source of truth, and it stays on the
   Salesforce platform (Prompt Builder + a multimodal model).

## Phase 11 — External voice channel: Amazon Bedrock Nova 2 Sonic (target: 1.5 days)

**Goal:** a web page outside Salesforce simulates a real phone call. The caller
speaks, Nova 2 Sonic handles speech in and out, Agentforce answers, and the
page shows the transcript and results.

**Deferred by the builder on 2026-09-17 — do Phases 9 and 10 first.** Kept here
so the plan is complete; re-scope it when Phase 10 closes.

1. **Prerequisites — confirmed:** AWS account (`REDACT_AWS_ACCOUNT_ID` in
   `secrets.env`), region `eu-north-1` (Stockholm), Bedrock access to Nova 2 Sonic already granted.
   Still to confirm: IAM credentials for local use, and which SDK supports
   Bedrock's bidirectional streaming API
   (`InvokeModelWithBidirectionalStream`) in the chosen language. Phase 10 no
   longer uses AWS, so this phase owns the AWS work outright.
2. **Architecture decision (recommended): Agentforce stays the brain, Nova is
   the ears and mouth.** Nova 2 Sonic gets a system prompt restricting it to
   relaying, and one tool, `ask_keyburn_agent(utterance)`. That tool forwards
   each caller turn to the existing Agent API session (`src/agent_client.py`,
   `bypassUser: true`) and returns the agent's reply for Nova to speak. This
   keeps the guardrails, permission sets, escalation safety net, and the eval
   evidence valid for the external channel. The rejected alternative (Nova as
   the reasoning agent, calling Salesforce actions as tools) would duplicate
   the reasoning and bypass everything Phase 8 proved.
3. **Build** in a new top-level folder, `bedrock-voice/`:
   - backend: WebSocket audio streaming to Bedrock, the tool handler, one
     Agentforce session per call;
   - frontend: mic button, live transcript, results panel (case numbers, order
     status, and the Phase 9 map if coordinates come back).
   Secrets only in env vars.
4. **Latency:** an Agentforce turn takes several seconds. Use Nova's
   asynchronous tool handling / a spoken filler ("let me check that") so the
   call doesn't go silent.
5. **Spike inside this phase: what comes back through the Agent API besides
   text.** The map and structured results on the external page need action
   output data (coordinates, case number) in the API response. If it only
   returns text, the page shows the text. Do not fetch data around the agent
   directly from Salesforce; that bypasses the guardrail story.
6. **Evals:** reuse `eval_cases.yaml` through the same Agent API (unchanged
   brain). Add a manual script of 3 spoken calls through the external page, and
   log latency per turn.

## Phase 12 — Prepare the demo and the deck (4–6 hours) — always last

1. **Freeze** the agent version to present, and re-run the full eval suite on
   it twice. Delete eval-generated escalation cases from the org if the case
   list will be on screen.
2. **Pick the demo moments.** Candidates: a happy path; an escalation (case
   number spoken, Case visible in the org); a misheard order number
   (**rehearse in voice**, because the platform's O→0 conversion may pre-empt
   it; a misheard digit is more reliable); "where is my order" on the map
   (Phase 9); the order workflow explained from the diagram (Phase 10); a call
   placed from the external Bedrock page (Phase 11). Choose 3–4; don't try to
   show everything.
3. **Record a backup video** of each chosen moment running correctly,
   including the Bedrock call.
4. **Build the deck** against the four required chapters. Keep slides sparse:
   the demo is the asset, slides are scaffolding. The eval run history
   (3/11 → 14/15, with test fixes and agent fixes labelled separately) is the
   Reliability & Evaluation slide.
5. **Architecture diagram**, one slide: caller (Builder voice / Bedrock Nova 2
   Sonic page) → Agent API / channel → router → subagents → Apex actions →
   Salesforce data + Data Library, with the guardrail points marked
   (identity verification in Apex, `USER_MODE`, least-privilege permset,
   escalation safety net).
6. **Rehearse against the clock twice**, out loud. Time the 30-minute Asset
   block; it's the one that overruns.
7. **After the demo:** rotate the ECA client secret.

---

## Calendar from 2026-09-17 (demo Thursday 2026-09-24, 14:45; moved from Wednesday 23)

| When | Phase | Cut-off / fallback |
|---|---|---|
| Thu 17 (rest of day) | Phase 9 spike (map rendering) + data model | — |
| Fri 18 | Phase 9 build, evals | Not demoable by Fri night → voice speaks location only, map drops |
| Sat 19 | Phase 10 (image spike first, then build) | Image not readable → option (a) text description |
| Sun 20 – Mon 21 | Phase 11 | No end-to-end call by Mon night → deck shows architecture only, live demo stays on Builder voice |
| Tue 22 | Phase 12 (deck, demo guide, Case naming fixes) | No new features from Tuesday |
| Wed 23 | Phase 12 freeze: backup recordings, two eval runs, rehearse twice | — |
| Thu 24 | Demo, 14:45, Salesforce Madrid office | — |

This leaves about 3.5 build days for three features plus a day for Phase 12,
which is tight. The cut-offs are there so an overrunning feature can't eat
Phase 12. Phase 11 is the riskiest (new cloud account, streaming audio,
latency) and comes last, so a slip only costs that feature.

---

## Original calendar (Phases 0–8, completed)

| When | Phase |
|---|---|
| Day 1 | Phase 0, 1, and **start Phase 2** (kick off Data Cloud provisioning) |
| Day 2 | Finish Phase 2, Phase 3 (actions) |
| Day 3 | Phase 4 (agent), Phase 5 (voice), Phase 6 |
| Day 4 | Phase 7 (ECA), start Phase 8 (evals) |
| Day 5 | Finish Phase 8 — this is where the iteration happens |
| Day 6 | Demo, deck, recording (now Phase 12) |
| Day 7 | Rehearse, buffer for whatever broke |

If you have fewer days than that, cut Phase 2 (drop to 3 topics, no Data
Cloud) before you cut Phase 8. A narrow agent with real eval data beats a
broader agent you can't speak about rigorously — that's the trade the rubric
actually rewards.
