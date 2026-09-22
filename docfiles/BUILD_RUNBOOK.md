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
> **Phase 18 (demo + deck; numbered 12 until 2026-09-22), which always stays last**.

---

## Rules for every phase from 9 onwards

- **The demo-safe fallback is v38** (Phases 9–10 complete; older fallbacks v33,
  then v4). Every phase publishes a new version. If a phase is incomplete by its
  cut-off, reactivate the last good version, and the feature appears in the deck
  as design or next steps, not in the live demo.
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

## Phases 12–17 — panel feedback (added 2026-09-22)

A Salesforce reviewer looked at the build on 2026-09-22 and asked for more of
the platform's own enterprise tooling:

1. verify the caller with **Send Email with Verification Code** before any
   order is shown;
2. a **data pipeline from S3** into Data 360 (an Agentforce Data Library alone
   is "too basic");
3. a **Knowledge evaluation** with `salesforce/agentforce-knowledge-readiness`;
4. **Testing Center**, including voice testing (GA for Service Agent);
5. **observability**;
6. **Sessions & Intents** and **Agent Analytics**.

The builder's decision: build all six, and use Wednesday 23 (planned as freeze
day) for build work. The phases are ordered by **lead time**. Things that need
data or indexing time to accumulate start first. The one change to the agent's
core flow (Phase 16) runs when there's a full day to test it. The "Rules for
every phase from 9 onwards" above apply unchanged.

## Phase 12 — Observability foundation (Tue 22, ~1 h) — start first

**Goal:** from this point on, every conversation is traced into Data 360, so
Phase 17 has real sessions to analyse. Dashboards need data and time; turning
them on the evening before the demo would show empty screens.

1. **Spike (15 min):** check that the org has the `PlatformObservability`
   permission and Session Tracing. Run one `sf agent preview` session and check
   that its trace lands. If this DEV org lacks the feature, record that as a
   finding in `project-status.md`, and Phase 17 uses its fallback.
2. **Enable Session Tracing.** It writes every turn, LLM call, action and
   guardrail check into the Session Tracing Data Model (STDM) in Data 360. There
   are two routes:
   - Setup (Einstein Audit & Feedback / Agentforce Session Tracing);
   - the `AgentforcePlatformTracingSettings` metadata (API 68,
     `enableAgentforcePlatformTracing`). Reference:
     `sf-skills-1.55.0/skills/platform-tracing-agentforce-configure`.
3. **Setup → Agent Analytics → install Service Agent Analytics.** Enable
   **Agentforce Optimization** (Sessions & Intents).
4. **Seed traffic:** run the Python eval suite once tonight. From here on,
   every eval run, Testing Center run and voice call is also observability data.
5. Retrieve the settings into `sfdx-project/` (a `package.xml` at API 67+,
   because the project's API 61 skips these types silently).

## Phase 13 — S3 → Data 360 unstructured data pipeline (start Tue 22, wire in Wed 23)

**Goal:** policy documents that live in the customer's own data lake (an S3
bucket) are grounded into the agent through Data 360. They are referenced in
place: an unstructured data lake object (UDLO) points at the files and a search
index is built over them, instead of copying the text into Knowledge.

1. **Content:** new `s3-docs/` folder with 3–4 policy documents (PDF or HTML)
   that are **not** in Knowledge, e.g. carrier & delivery SLA, warranty terms,
   damaged-parcel procedure. **At least one fact exists only in S3**, so an eval
   can prove the S3 path is used (the same trick as Phase 10's image-only facts).
2. **AWS** (the existing account, `eu-north-1`):
   - bucket `keyburn-policy-docs-<suffix>`;
   - a dedicated IAM user with read-only access to that bucket only;
   - its keys go in `secrets.env` as `AWS_S3_*` lines (template lines in
     `secrets.env.example`), never in the repo.
3. **Spike (≤ 1 h):** does the S3 UDLO need the file-notification setup (an AWS
   Lambda/SNS pipeline) for the first ingest, or only for incremental sync?
   Follow the Data 360 guide "Set Up Unstructured Data from Amazon S3".
4. **Data 360:** Amazon S3 connector → UDLO (its UDMO is created with it) →
   search index (hybrid, default chunking) → retriever. **Start this on Tuesday
   night** so indexing runs overnight.
5. **Agent (Wednesday):**
   - new Flex prompt template `OCC_Policy_Docs_Answer`, grounded on the S3
     retriever;
   - add it as a Policy/FAQ action next to `streamKnowledgeSearch`;
   - the instructions send contractual / SLA questions to it. Knowledge stays
     the source for articles (Phase 14 grades those).
   - Deploy with `--api-version 67.0`, then retrieve for the platform-generated
     `versionIdentifier` (Phase 10 lesson).
6. **Evals:** 2–3 `s3_*` cases, one of them asserting the S3-only fact.
7. **Panel-facing point:** enterprise content stays in the customer's lake,
   referenced without copying it, indexed and retrieved in Data 360. The Data
   Library is the managed shortcut for Knowledge; this is the route for
   everything else.

## Phase 13b — Visual documents: an image read at index time (added 2026-09-22)

**Goal:** the agent answers from a document whose key facts exist **only in an image**. The image is
read **once, when the document is indexed**, by Intelligent Context's LLM-based parsing. It's the
counterpart of Phase 10:

| | Phase 10 | Phase 13b |
|---|---|---|
| When the image is read | At question time: GPT-4o looks at the diagram on every question | At index time: an LLM parses the image once into searchable chunks |
| Good for | One image that must be interpreted exactly | Many visual documents that need to be found by search |
| Trade-off | Model cost and latency on every question | One-off parsing cost; the answer is only as good as the parse |

Pattern: Salesforce's *Power Agentforce with Complex Visual Data* guide, step 2 ("Configure Data 360
and Intelligent Context").

1. **Content:** `s3-docs/visual/keyburn-packaging-damage-guide.pdf`, generated by
   `make_damage_guide.py`. The text layer only says the pictures show "the grade and what to do".
   What to do for each grade is pixels only. The key fact: grade C (wet or torn open) → refuse the
   delivery, and a replacement ships automatically. A `pypdf` extraction proves nothing leaks into
   the text layer.
2. **S3:** the PDF goes in the bucket's `visual/` folder, so the HTML object doesn't pick it up.
3. **Data 360:** a second unstructured data lake object, `Keyburn_Visual_Docs` (directory
   `visual`, file type PDF), **without** the wizard's semantic search. Intelligent Context creates
   its index.
4. **Intelligent Context** (Data Cloud app → Process Content):
   - New Configuration `Keyburn_Visual_Docs_IC`, with the PDF as the test file.
   - Smart defaults, then Modify: **LLM-based Parsing**, **No preprocessing**, Image Processing
     **off**.
   - Check the chunks contain the grade C instruction. **Publish** onto `Keyburn_Visual_Docs`.
   - Done 2026-09-22.
5. **Retrievers** (new Agent Builder → Data → Retrievers): one individual retriever per index. Both
   return the chunk text and the source file name.
6. **Agent (Wed 23, with Phase 13 step 5):**
   - Policy/FAQ gets the S3 answer action, grounded on **both** retrievers: text policies and
     visual docs.
   - One eval, `s3_visual_damage_grade_c`: "my parcel arrived wet and torn, what should I do?"
     must answer *refuse the delivery* and *replacement ships automatically*.
7. **Cut-off:** if Intelligent Context doesn't produce the grade C text by Wed 12:00, 13b goes into
   the deck as design, and Phase 10 remains the working proof that the agent reads images.

## Phase 14 — Knowledge readiness evaluation (Tue 22 night / Wed 23 morning, ~2–3 h)

**Goal:** measure the quality of the Knowledge the agent answers from, not only
the agent itself. Then improve it and measure again.

1. Clone `salesforce/agentforce-knowledge-readiness` into
   `tools/knowledge-readiness/` (git-ignored, vendored like `sf-skills`). It is
   a separate sfdx project, so its API version doesn't collide with ours.
2. **Prerequisites:**
   - Salesforce CLI v66+, Einstein Generative AI, Lightning Knowledge;
   - a Data 360 **semantic search index over Knowledge**. Check whether the
     Data Library's index qualifies before creating another one.
3. Deploy it, `sf org assign permset --name KB_Assessment_Admin`, open the
   `KB_Readiness_Assessment` app. Run it over the six `Policy_FAQ` articles.
4. It scores each article 0–100 on Completeness, Structure, Clarity, Freshness,
   Duplication and Conflict. Save the per-article scores to
   `docfiles/knowledge_readiness_run01.md`.
5. **Fix the lowest scorers.**
   - Review its AI draft rewrites; don't publish them unread.
   - Update `docfiles/knowledge_articles.md` and republish.
   - Re-run the tool → `run02`.
   - Re-run the Python suite to prove the Policy/FAQ answers didn't regress.
6. **Panel-facing point:** the before/after readiness score is the Knowledge
   counterpart of the eval pass-rate climb.

## Phase 15 — Testing Center (Tue 22 night baseline on v38; updated after Phase 16)

**Goal:** the regression suite runs on the platform's own test tooling, with
routing and action assertions, and voice is tested there too.

1. **Convert** `src/eval_cases.yaml` into an `AiEvaluationDefinition` test spec,
   `sfdx-project/specs/Keyburn_Regression.yaml`:
   - multi-turn cases use `conversationHistory` (setup turns), and the final
     caller turn is the `utterance`;
   - `expectedTopic` / `expectedActions` assert routing and action calls, which
     the Python harness can't do;
   - `expectedOutcome` is scored by an LLM judge.
   Validate the spec locally first. One malformed case rejects the whole spec,
   and the error doesn't say which case. Reference:
   `sf-skills-1.55.0/skills/agentforce-test`.
2. `sf agent test create --spec specs/Keyburn_Regression.yaml --api-name
   Keyburn_Regression`, then `sf agent test run --api-name Keyburn_Regression
   --wait 10 --result-format junit`. Retrieve the definition into `force-app`.
   The first run on v38 is the baseline.
3. **Voice testing (Testing Center UI only; the CLI tests text only):** a small
   voice test set with these cases:
   - happy-path order status;
   - a **misheard digit** (the long-carried "rehearse the misheard number" item);
   - an escalation.
   Screenshot the results.
4. **Keep the Python harness.** It is the only path that scores the full OTP
   loop (Phase 16) and the Nova relay. Deck line: Testing Center = the
   platform's regression gate; the harness = end-to-end and channel-specific.
5. The eval data rules still apply: `maria.garcia` gets no cases, and
   escalation Cases are cleaned up before the demo.

## Phase 16 — Email verification gate (Wed 23, ~5–6 h)

**Goal:** before any order or case data is read out, the caller proves they own
the email address. They read back a code sent to it by the standard **Send
Email with Verification Code** action. This is the only phase that changes the
agent's core flow, so it gets a full day and a hard cut-off.

1. **Spike (≤ 1.5 h):**
   - add the standard **Send Email with Verification Code** and **Verify
     Customer** actions in Agent Builder;
   - retrieve the bundle (manifest at API 67) to learn their exact Agent Script
     targets, inputs and outputs (`verificationCode`, `isVerified`, customer Id);
   - Setup → Deliverability = **All email**, and check that the agent user may
     send email.
2. **Design: defence in depth, not a replacement.** The code proves ownership of
   the email. The existing Apex lock (`OCC_CaseLookupUtil.violatesLock` +
   `@variables.verified_email`) keeps the session bound to it.
   - New `customer_verification` subagent.
   - Order Status, tracking, Return Eligibility and Case Status are gated on
     `@variables.email_verified == True`. The router sends unverified callers
     to verification first.
   - `verified_email` is set **only** after Verify Customer succeeds.
   - Policy/FAQ, the workflow diagram, the S3 documents and Escalation stay
     ungated; `unverifiable_identity` escalation keeps working.
   - The code must be a structural gate (a variable the instructions branch on),
     like the escalation case number, not a prompt request.
3. **Demo inbox:**
   - The demo Contact (the `jane.doe` record) gets a real mailbox.
   - Its address is stored as `REDACT_DEMO_INBOX` in `secrets.env`. Add the
     redaction line and re-run `tools/setup_redaction.ps1`, so the address never
     reaches the public repo.
   - Other eval Contacts get plus-addressed aliases of the same mailbox, so one
     inbox receives every code.
   - `sample-data/contacts_sample.csv` and `eval_cases.yaml` use placeholders
     that are filled at run time.
4. **Harness:**
   - `run_eval.py` gets an `otp` turn type: it polls the inbox over IMAP (app
     password in `secrets.env`) and sends the code as the caller's turn.
   - Testing Center cases assert the gate itself:
     - the agent asks for the code;
     - it refuses order data without the code;
     - it rejects a wrong code.
5. **Voice:** the caller speaks a six-digit code. Test it in the Builder voice
   preview and on the Nova page.
   - The relay's "only what the caller was heard saying" rule already covers it.
   - Update the confirm-back regexes in `bedrock-voice/relay.py` if the agent's
     wording changes.
6. **Evals:** OTP happy path (order status after the code); wrong code; no code
   → no order data; verified caller asks about a second order → no second code;
   Policy/FAQ question → no code asked.
7. **Cut-off Wed 18:00:** if the suite isn't green twice, reactivate v38. The
   Apex and data from the other phases stay. The gate goes into the deck as
   design plus its Testing Center evidence.
8. **Panel-facing point:** identity is now proven, not asserted. It's layered:
   the OTP proves the email, the Apex lock pins the session, `USER_MODE` +
   least-privilege permset limit what the agent can read at all.

## Phase 17 — Observability readout: Agent Analytics, Sessions & Intents, health (Wed 23 evening, ~1.5 h)

**Goal:** show how the agent is monitored and improved in production, using the
traffic generated by Phases 12–16.

1. **Agent Analytics:** containment, escalation rate, volume per subagent.
2. **Sessions & Intents** (Agentforce Optimization):
   - the intent clusters;
   - one session drilled down to its reasoning chain, ideally an escalation.
3. **Agent Health Monitoring:** one alert on escalation rate.
4. **Screenshot everything.** Dashboards can lag or be empty on the day; the
   screenshots are the backup.
5. **Fallback if the dashboards stay empty:** STDM `findSessions` queries
   (`sf-skills-1.55.0/skills/agentforce-observe`) plus `sf agent trace read`,
   shown as the observability story.
6. **Panel-facing point:** the loop is now closed. Tests before release (Testing
   Center + harness); traces and analytics after release; findings go back into
   evals.

## Phase 18 — Prepare the demo and the deck — always last

1. **Freeze** the agent version to present (Phase 16's version, or v38), and
   re-run both suites on it twice: Python harness and Testing Center. Delete
   eval-generated escalation cases from the org if the case list will be on
   screen.
2. **Demo moments** (choose 3–4; 8 minutes):
   - "where is my order?": the verification email arrives on screen, the code is
     spoken, then status + map;
   - an escalation;
   - an S3-grounded answer;
   - a call from the external Nova page.
   Rehearse the misheard-digit moment in voice.
3. **Record a backup video** of each chosen moment, including the email arriving
   and the Nova call with sound.
4. **Rebuild the deck.** Read the existing claude.ai Slides artifact and update
   it in place (same URL). Changes:
   - **Data:** S3 → UDLO → search index → retriever, next to Knowledge / Data
     Library.
   - **Guardrails:** the OTP gate as the first layer of the stack.
   - **Reliability:** Python harness climb + Testing Center (text and voice) +
     Knowledge readiness before/after.
   - **New observability slide:** tracing → Agent Analytics → Sessions &
     Intents → health alert.
   - **Trade-offs:**
     - the OTP adds a turn and friction;
     - S3 pipeline vs Data Library;
     - Testing Center vs our own harness.
5. **Architecture diagram:** add the S3 / Data 360 path, the verification step
   and the observability layer (traces into Data 360).
6. **Update `docfiles/DEMO_GUIDE.md`:**
   - pre-flight: demo inbox open, S3 index healthy, active version;
   - failure recovery: email slow or missing → fallback v38 or the recording;
   - a crib-sheet entry for each new decision.
7. **Rehearse against the clock**, out loud (Thursday morning at the latest).
   Time the 30-minute Asset block; it's the one that overruns.
8. **After the demo:** rotate the ECA client secret, the Google key, and the
   new S3 IAM keys and IMAP app password.

---

## Calendar from 2026-09-22 (demo Thursday 2026-09-24, 14:45)

| When | Phase | Cut-off / fallback |
|---|---|---|
| Tue 22 afternoon | Commit; Phase 12 (tracing on, analytics installed); Phase 13 AWS + connector + index started | Tracing unavailable → record it; Phase 17 uses the STDM / trace fallback |
| Tue 22 night | Phase 14 deploy + run01; Phase 15 spec + baseline on v38 | — |
| Wed 23 morning | Phase 16 spike + build | Spike not passing by 11:00 → gate designed, not built |
| Wed 23 afternoon | Phase 16 evals; Phase 13 S3 answer wired into Policy/FAQ; Phase 14 fixes + run02 | **18:00: agent version frozen** (new version or v38) |
| Wed 23 evening | Phase 15 re-run incl. voice; Phase 17 readout + screenshots | — |
| Wed 23 night | Phase 18: deck, demo guide, backup recordings | — |
| Thu 24 morning | Phase 18: one timed rehearsal, pre-flight | Demo 14:45, Salesforce Madrid office |

There is no freeze day anymore, so the cut-offs carry the risk: Phase 16 is the
only change to the agent's core flow and has a hard 18:00 stop. Every other
phase adds something beside the working agent, so a slip costs that feature,
not the demo.

## Calendar from 2026-09-17 (superseded 2026-09-22)

| When | Phase | Result |
|---|---|---|
| Thu 17 – Fri 18 | Phase 9 | Done (v16, map in the deployed chat from v30) |
| Sat 19 | Phase 10 | Done (v38) |
| Sun 20 – Mon 21 | Phase 11 | Done (2026-09-20) |
| Tue 22 | Demo + deck (then Phase 12) | Reopened by panel feedback → Phases 12–17 |

---

## Original calendar (Phases 0–8, completed)

| When | Phase |
|---|---|
| Day 1 | Phase 0, 1, and **start Phase 2** (kick off Data Cloud provisioning) |
| Day 2 | Finish Phase 2, Phase 3 (actions) |
| Day 3 | Phase 4 (agent), Phase 5 (voice), Phase 6 |
| Day 4 | Phase 7 (ECA), start Phase 8 (evals) |
| Day 5 | Finish Phase 8 — this is where the iteration happens |
| Day 6 | Demo, deck, recording (now Phase 18) |
| Day 7 | Rehearse, buffer for whatever broke |

If you have fewer days than that, cut Phase 2 (drop to 3 topics, no Data
Cloud) before you cut Phase 8. A narrow agent with real eval data beats a
broader agent you can't speak about rigorously — that's the trade the rubric
actually rewards.
