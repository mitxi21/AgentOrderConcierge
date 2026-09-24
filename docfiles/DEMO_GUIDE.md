# Demo guide — Builders Panel, Thursday 2026-09-24, 14:45, Salesforce Madrid office

Companion to the deck ("Order & Case Concierge — Builders Panel"). This file is the operational side:
what to check before, what to say and type during the demo, what to do when something breaks, and how to
explain each design decision. **The slide-by-slide talk track is in `RehearsalScript.txt`.**

> **Deck: the final redesigned version (2026-09-24)**, exported as
> `Order & Case Concierge - Builders Panel.pdf`: 16 slides plus 5 appendix slides, with no footer
> numbers. Slides are referred to below by **page number and title**. It replaces the claude.ai Slides
> draft (slide ids `agent`, `choices`, `failures`…), which is no longer what is presented.
> `RehearsalScript.txt` was written against that draft, so check its slide references before
> rehearsing from it.

Presented version: **agent v46** — v44 (the Phase 16 verification gate **built and switched off**,
plus a working two-step call close) with the Phase 13b packaging damage guide added to Policy/FAQ.
Fallbacks, in order: **v44** (drops the damage question, nothing else), **v42** (the gate back on, if
a reviewer asks to see it live and a mailbox is reachable), then **v38**, then v33.

**On the verification gate, say this and move on:** it is built — the code is emailed, only a salted
hash is stored, and `OCC_CaseLookupUtil.notVerified` refuses in Apex before any SOQL — and it is
switched off for this demo, because the caller on stage cannot open the mailbox the code goes to,
so the gate would stall the call. The architecture point survives intact and is the one worth
making: **only an Apex action can set that flag, and no instruction anywhere can.** Do not demo the
code step live.

**Three slides still describe the code as if it runs today. Say so out loud when you reach them:**

- **p5 Execution Route Map**, moment 1: *"Code to inbox."* Say: *"In production a code goes to the
  inbox first. It is switched off today, so you'll see the read-back instead."*
- **p9 Scope and Constraints**, the first APEX row: *"A code sent to the inbox, before any lookup
  runs."* Say *"built, and off for today"* as you pass it.
- **p10 Identity Lock Execution**, *"Demo Stage: simulates authenticated session token, bypassing the
  OTP gate."* This is the right framing: the verified flag defaults to true, as it would behind a real
  login. Be precise if asked: nothing mints a token. It is one variable default, and the Apex guard is
  unchanged.

---

## 1. Timing (45 min)

16 slides and 5 appendix slides. The slides are sparse, with short labels rather than sentences, so
the substance is spoken. Rehearse against the talk track, not the slide text. The architecture is
now **one** slide (p4), and it comes **before** the demo.

Chapter times follow the panel brief: **5 / 30 / 10 / 10**.

| Block | Slides (page · title) | Time | If running late |
| --- | --- | --- | --- |
| Introduction | p1 cover · p2 Me, Briefly | 5:00 | Agenda is spoken, never shown |
| The agent | p3 Purpose and Measurement | 2:00 | The containment target is **an assumption**: say so. The measured numbers are now on p11 |
| AI tooling | p4 Interaction & Routing | 2:00 | Three front doors, one brain. Point at the orange Escalation box |
| **Live demo** | p5 Execution Route Map | 8:00 | The slide budgets 2 / 1 / 3 / 1 = 7 min, plus 1 min of slack. Drop the damage question first, then moment 2's identity switch |
| AI tooling | p6 And here it is · p7 Grounding & Data Sources · p8 Architectural Decisions | 5:00 | p6 is one breath. On p8, read the core-philosophy bar only |
| Guardrails | p9 Scope and Constraints · p10 Identity Lock Execution | 5:00 | Read the layer stack bottom-up. On p10, say built-and-switched-off, and don't demo it |
| Reliability | p11 Testing and Validation · p12 Production Observability | 4:00 | Two suites, two numbers. On p12, say the 84.2% and move |
| Issues & trade-offs | p13 Learned the Hard Way · p14 Execution Compromises | 4:00 | p13: the sharing-vs-FLS card only. p14: rows 2 and 4 |
| Why me | p15 Four Engineering Habits | 10:00 | — |
| Q&A | p16 Questions? (+ p17–p21 appendix) | 10:00 | — |

**Three slides carry the most weight and are the easiest to rush: p3 (what is measured and what is a
target), p10 (the guardrail a reviewer asked for) and p13 (how the root causes were found).** p13
and p14 carry almost no text, so the stories behind them (below) are all spoken.

The asset block runs **5:00 → 35:00**. It's the part that overruns: at rehearsal, check the clock
when you leave the demo — target **17:00** (the architecture slide now comes before it). Past
18:00, cut p6 to a single sentence, then read only the bar on p8, then drop p12.

### Numbers on the slides — know where each comes from

| Slide | Number | Source |
| --- | --- | --- |
| p3 | 40–60% containment | **Target, not measured.** 10,000 contacts/month × 4 min AHT × 40% ≈ 265 h/month ≈ 1.5 FTE |
| p11 | 31 / 31 | Python harness over the Agent API, runs 34 / 34b on v46 |
| p11 | 28 / 28 | Testing Center (Studio) suites on v46. The 2026-09-24 re-run, verified in Session Tracing |
| p11 | 14.8% escalation (95 of 640 sessions), 1.9 s average turn over 2,599 turns, 2.2 s on voice | Session Tracing readout |
| p11 | "Data Cloud Alert" at 10% | Agent Health Monitoring alert: escalation rate ≥ 0.1 over 24 h, evaluated every 15 min |
| p12 | 2,599 turns, 605 action calls, 84.2% scored 4–5, average 4.21/5 | Session Tracing / Sessions & Intents |

Caveats to volunteer before they're asked: the traffic is mostly eval scripts, so ~150+ sessions
read as *abandoned* (the script stops), and zero platform errors flatters the build, because the
actions return "not found" rather than throwing. **The trace outlives the record:** deleting a Case
does not delete the trace, so trace escalations outnumber the Cases in the org.

---

## 2. Pre-flight

### Wednesday 23 (freeze day)

- [ ] Decide the version to present and confirm it is active (Setup → Agentforce Agents → Keyburn
      Customer Service → versions). **v46** is the one to present: v44 plus the Phase 13b packaging
      damage guide on Policy/FAQ (S3 → Data 360 → Intelligent Context → retriever → data library).
      **v44** is the clean fallback — it loses the damage question and nothing else. **v42** is the
      same build with the gate on — only go there if a reviewer wants it live and you have a
      reachable mailbox. **v38** is pre-gate.
- [ ] **Walk the close once, out loud, on the Nova page**: ask for an order, confirm, let it answer
      and offer further help, then say *"no thanks, that's all"*. It must say one goodbye and the page
      must hang up by itself. This is the thing that failed on the 23rd; it is worth the 90 seconds.
- [ ] **Do not plan a live code step.** The gate is off in v44. If asked, say it is built and
      switched off because the caller cannot open the mailbox on stage, and point at the Apex guard.
- [ ] Run the eval suite **twice** on the version you will present and save both runs in
      `src/eval_reports/`. On v44 the harness's auto-verification step never fires (the gate is off),
      so `auto_verifications` should be 0 — that is expected, not a harness failure.
- [ ] Record a **backup video** of each of the four demo moments (below), including the Nova
      call with sound. Keep them on the laptop desktop, not in the cloud only.
- [ ] Rehearse the whole 45 minutes out loud **twice** against a timer on the **final deck**. Its
      slides are labels, not sentences, so everything is spoken. That is why p13, p14 and p15 need
      the most practice.
- [ ] p15 Four Engineering Habits: have one **real career example per habit** ready (≈90 s each).
      The slide gives only the habit.
- [ ] Keep the PDF export on the laptop desktop as the offline fallback for the deck.

### Demo day, Thursday 24 (T–60 min, so by 13:45)

- [ ] `sf apex run --file scripts/set_demo_geodata.apex --target-org devorg` — parcel positions
      go stale ("15 hours ago" on 09-19). Run it from `sfdx-project/`.
- [ ] **Delete eval-generated escalation Cases** so the "Agentforce Escalations" list view shows
      only what you create live:
      `SELECT Id, CaseNumber, Subject FROM Case WHERE Origin = 'Agentforce Agent'` → delete.
      Leave the sample-data Cases alone. `maria.garcia@example.com` must still have **no open
      cases**.
- [ ] Load secrets and start the voice page: `. .\load_secrets.ps1; py -3.12 bedrock-voice\server.py`,
      then the headless preflight `py -3.12 bedrock-voice\ws_test.py`.
- [ ] **Warm-up call** on the Nova page (one full call, to the goodbye). A cold first Agentforce
      turn took 13.8 s.
- [ ] Warm-up chat on the public Keyburn site (one tracking question), so the website moment is
      warm too.
- [ ] **Republish the Embedded Service deployment** `Agentforce_Service_Agent`, or the map card is
      sent but not drawn. **This is outstanding for v46** — the agent was republished twice on the evening
      of the 23rd and this step is Setup-UI only, so it cannot be scripted: Setup → Embedded Service
      Deployments → `Agentforce_Service_Agent` → Publish. Do it before the website warm-up chat, then
      confirm the map card actually draws.
- [ ] **Purge the noise**: `sf apex run --file scripts/purge_eval_cases.apex -o devorg` (agent-created
      Cases) and `sf apex run --file scripts/purge_voice_recordings.apex -o devorg` (a voice test run
      stores ~12 MB per conversation against this org's 20 MB file limit and then blocks every
      upload). Check `sf org list limits` shows FileStorageMB back at 20.
- [ ] The **Verification** tab is not needed — the gate is off in v46, exactly as in v44. Only open it if you have
      deliberately fallen back to v42, in which case delete old rows first so the newest is on top.

### T–10 min (14:35)

- [ ] Browser tabs, in order: (1) the final deck, open at p1, in the presenter view you rehearsed with, (2) public Keyburn site
      `https://<my-domain>.my.salesforce-sites.com/keyburn/`, (3) Nova page
      `http://localhost:8765`, (4) Keyburn Service console → Agentforce Escalations list view.
- [ ] Chrome/Edge microphone permission granted for `localhost`; **laptop mic and speakers**
      (the audience must hear both sides), volume ~70%, no headset.
- [ ] Notifications off (Windows Focus), screen resolution/zoom checked on the projector,
      browser zoom 125% on the chat so it's readable.
- [ ] Backup videos open in a player, paused on frame one.

---

## 3. The demo script (≈ 8 min)

Slide: **p5 Execution Route Map**, and its four stops are the four moments below, with the slide's
time budgets (2 / 1 / 3 / 1 min). You arrive here from p4 Interaction & Routing, so the panel has
already seen the three front doors. Say before starting: *"Four moments, three of the doors you just
saw. Everything runs live in a Salesforce dev org. Keyburn is fictional; the data is sample data."*

### Moment 1 — Website chat: "Where is my order?" (≈ 2 min; slide: "Website Chat")

Surface: public Keyburn site → "Chat with Keyburn". The slide says *"Code to inbox"*. Say that the code
is switched off today (see the top of this guide) before you type.

| You type | Expect | Point at |
| --- | --- | --- |
| `Where is my order 1042?` | Asks for the email (or confirms back if you gave both). No code is sent: the gate is off | It asks before it answers — verification first |
| `jane.doe@example.com` | *"I heard order 1042 with the email jane.doe@example.com — is that right?"* | The confirm-back |
| `Yes` | Status Shipped + distance and driving time + **map card** | Map is a Custom Lightning Type fed by an Apex action calling Google Routes |

Line to say: *"The model didn't look anything up. It called an Apex action that only returns data
if that email and that order belong to the same customer."*

### Moment 2 — Same chat: edge cases (≈ 1 min; slide: "Edge Cases")

The slide names two things: diagram logic extraction and the identity-scope refusal. Do those two
first. The damage question is not on the slide: ask it only if the clock allows (target: leave
moment 2 by 12:00). It costs ~30 s including the retrieval wait.

| You type | Expect | Point at |
| --- | --- | --- |
| `Can I still cancel my order once it has shipped?` | No — cancelling is only possible from Draft or Processing | That fact exists **only in the workflow diagram image**; GPT-4o reads it through a prompt template at question time |
| `Can you also check order 2077 for john.smith@example.com?` | *"For your security, I can only help with the account verified earlier…"* | The lock is enforced in Apex, not in the prompt — this is the code on p10, coming up |
| *(if time)* `My parcel arrived wet and torn open, what should I do?` | Refuse the delivery; the carrier returns it and a replacement ships automatically | The instruction exists **only as pixels** in a PDF in the S3 bucket. Intelligent Context read the image **once, at index time**; the agent retrieves the sentences it produced |

The damage question takes **about 10 seconds** — the retrieval hop is slower than a lookup. Talk
over it; don't retry. If you skip it, the appendix slide p21 *One setting, and the answer appears*
covers it in Q&A.

Optional if ahead of time: `How long do you keep a draft order?` → 30 days (also image-only).

### Moment 3 — Phone call through Nova 2 Sonic (≈ 3 min; slide: "Voice Handover")

Surface: Nova page, laptop mic + speakers. Say first: *"Now the same agent on a voice line. Amazon
Nova does speech only; every sentence I say is relayed to the same Agentforce agent. Watch the
'Behind the call' panel."*

| You say | Expect | Point at |
| --- | --- | --- |
| (Call) — | Agentforce greeting spoken | — |
| "Where is my order one zero **two four**? My email is jane dot doe at example dot com." | Confirm-back reads **1024** | *"I'm playing a caller who got a digit wrong."* |
| "No, it's one zero four two." | New confirm-back with 1042 — or, as seen on 09-19, straight to the answer | The wrong number was never looked up |
| "Yes, that's right." | Tracking answer; the **map appears on the page** | Relay panel: per-turn latency, relayed words |
| "I want a refund for that order." | Escalation; **case number spoken** | Money always goes to a human |
| "No, that's all, thanks." | Goodbye; page hangs up by itself | — |

Why the digit is staged: the platform's voice layer converts spoken "O" to 0, so the "O-1O42"
letter trick may silently match and skip the confirm-back. A wrong digit is reliable. Rehearse it
at least twice before going on stage.

Write down the case number you hear.

### Moment 4 — Keyburn Service console (≈ 1 min; slide: "Console Review")

Surface: Keyburn Service app → Cases → **Agentforce Escalations**. Open the Case just created.

Point at: Subject "Refund request", Type **Billing**, Reason **Refund request**, Origin
**Agentforce Agent**, High priority, the contact is Jane Doe, **created by the agent user**, and
the `Escalation Summary` field. (The agent classifies internally with its own reason codes; Apex
maps them to these fields, so nothing machine-shaped is ever stored on the Case.) Line: *"The human calling back doesn't have to
ask Jane anything again."*

### Transition back to the deck

*"Everything that follows explains a decision you just saw."* → **p6 And here it is** (the Builder
canvas). Say: *"That's the agent you just talked to — not a drawing, the file in git, published as
version 46."*

---

## 4. When something breaks

Rule: **one sentence on what failed, then switch to the recording.** Don't debug live; a calm
recovery scores better than a perfect run.

| Symptom | Likely cause | Do this |
| --- | --- | --- |
| Chat replies only after a page refresh | Live-event polling (org-ID mismatch) | Refresh once; if it persists, play video 1–2 |
| Answer arrives but no map card | Embedded Service deployment not republished, or the model skipped `show_command` this turn | Say "the card is a per-turn model choice; here's the recording". Don't retry more than once |
| First voice turn > 10 s | Cold start | Keep talking over the hold chime: "this is the cold-start case I measured at 13.8 s" |
| Nova hears the wrong words repeatedly | Room noise / mic | Type the turn in the page's text box (it goes through the same relay) |
| Nova page won't connect | AWS keys not loaded, server down | Play video 3; mention the in-chat voice button as the Salesforce-native path (no map/transcript there) |
| Refund doesn't produce a case number | Escalation skipped | Say it's the nondeterminism the evals measure; show the recorded case |
| Damage question answers from Knowledge, or says it can't help | The model picked the wrong tool, or the retrieval hop timed out | Ask it once more in plainer words (*"the box arrived soaked and ripped open"*). If it misses twice, move on — the fallback line is *"that one goes to a document in S3; there's an appendix slide on exactly how it's parsed"* (p21) |
| Agent answers wrongly across the board | Wrong version active | Setup → activate **v44** (then v42, then v38). Rollback is one click — worth saying out loud |

---

## 5. Design decisions — how to explain them

One line each, for the moment a panelist asks "why?". The final deck shows headlines only (p7, p8,
p14), so the long form is spoken, and this table is it.

| Decision | Say | Alternative rejected, and why |
| --- | --- | --- |
| Narrow scope: 4 contact reasons + escalation | "The edges are part of the design. Narrow, working and measured beats broad and hand-wavy." | More topics: each needs evals and guardrails I couldn't prove in the time |
| Apex actions for every fact | "The model does language; code does facts. A status is never generated." | Flows (less testable), Data Cloud search for orders (similarity where I need exact match) |
| Data Cloud only for policy text | "Semantic retrieval only where it earns its keep." | Hardcoding policy in the prompt: goes stale, can't be governed |
| Identity = email + order on the same Contact, locked per conversation in Apex | "The model can't pass another customer's email — the input is bound to a session variable and checked in code." | Prompt instruction only (the model can be talked round). The emailed code is built and switched off for the stage (p10); authenticated chat is the production answer |
| Least-privilege agent user, `WITH USER_MODE`, `with sharing` | "Even a successful prompt injection only reaches what this user can see." | Running as admin or system mode |
| Confirm-back of spoken identifiers | "In voice a wrong digit is the most common failure; one extra turn is cheaper than a wrong disclosure." | Silent fuzzy matching |
| Escalation creates a Case with a summary | "A 'no' should be a handoff, not a dead end." | Platform handoff: on the API and phone it had no route — silence, no Case (found in baseline eval) |
| Removed the `after_reasoning` safety net | "It created junk High-priority cases on every re-ask. False escalations cost humans; the evals now require the spoken case number." | Keeping it: guaranteed escalation logging, but noisy |
| Agent Script in git; validate → publish → activate | "Every change is a diff and an eval run; rollback is activating the previous version." | Builder-only editing: an edit sat unpublished for two days |
| Eval harness over the Agent API, test and agent fixes labelled separately | "So the climb from 27% doesn't overstate the agent." | Manual testing in the preview |
| GPT-4o reads the workflow diagram at question time | "The image is the source of truth; two facts exist only in it." | Transcribing the diagram into an article: two sources to keep in sync |
| Nova 2 Sonic relays to Agentforce | "Nova is the ears and mouth, Agentforce is the brain. The relay forwards only what the caller was heard saying." | Service Cloud Voice (paid add-on + telephony); letting Nova answer (it once invented a caller's "yes") |
| One map card per conversation | "A platform behaviour. I ran one structured experiment, documented it, and stopped." | More versions chasing it |
| VF page + Force.com site, not Experience Cloud | "Same chat, a fraction of the moving parts four days before the demo. Experience Cloud is the production path." | Experience Cloud now |
| Containment is worth something | "At 10,000 contacts a month and a four-minute handle time, 40% containment is about 265 hours a month back to the team — roughly 1.5 FTE. Assumptions, not measurements." | Quoting a containment number as if it were measured in a dev org |
| The eval harness is a release gate | "In an enterprise org you can't activate a new prompt version blind. This is the deployment gatekeeper: 31 conversations against the live API, as the agent user, and nothing goes live without a green run." | Calling it "testing" — it undersells the governance point |
| Cutting the 13.8 s cold start | "Shipped: hold sound plus a warm-up call. Buildable: open the session at call setup, keep-alive, no callout on the first turn, streamed replies, cached diagram reading. The rest is platform-side — instrument it and take numbers to the platform team." | Leaving the hold sound as the whole answer |
| Agent Cases are named like a human's | "The model classifies with its own reason codes; Apex maps each to the subject, type and reason a human agent would have typed, and Origin = Agentforce Agent marks every one. The queue filters on Origin + Priority." | Storing the reason code as the subject: the record then reads like a test harness |
| Shipping a change is CI/CD | "Edit the script locally, validate, publish a version, activate, re-run the suite, roll back by activating the previous version. The gap is the trigger — it's manual today, GitHub Actions next." | Editing in the Builder and hoping |
| The Python suite is a real test | "It runs against the live org over the Agent API, as the agent user, and writes real Cases. Apex tests cover the deterministic half; this covers routing and refusals, which Apex can't reach." | Calling it a smoke test, or claiming it's CI when the trigger is manual |
| The workflow diagram stays a picture | "A Knowledge article is where a service org keeps a picture, so the picture stays the source of truth and the agent reads it with a multimodal template at question time." | Transcribing it into text: two sources that drift |

### The stories behind the sparse slides

**p8 Architectural Decisions — read only the bar.** *"The LLM handles human conversation; Apex and
Data Cloud handle facts and permissions."* If asked about the model: the platform default for
reasoning, so the data stays inside the trust boundary; GPT-4o only where an image has to be read.
Memory: session variables only.

**p13 Learned the Hard Way — three cards, one story told properly:**

- **Sharing vs FLS** (the one to tell): `USER_MODE` fails two ways, and only one is visible. Field
  security *throws*; sharing *silently drops the row*, which looks exactly like "no such record". The
  cause was Contacts with no Account. *"I fixed the data model instead of opening org-wide defaults.
  That would have fixed the demo in thirty seconds and left a security hole behind."*
- **API 62 metadata:** the version bump made `USER_MODE` enforce custom-metadata access. The eval
  suite caught it while the admin tests stayed green.
- **Knowledge index:** publishing archives the old version, search ignores archived versions, so an
  article is missing for ~25 minutes until the index re-chunks.
- Not on the slide, but the best one if there's time: **the voice model invented a caller's "yes"** to
  the confirm-back. The relay now forwards only transcribed caller words, and it blocked 48 invented
  turns on the next run.

**p14 Execution Compromises** has four rows. Narrate *Read-back Validation* (one extra turn, every
time, is cheaper than reading a stranger their delivery address) and *Email Verification* (built,
left out for the stage). Also have ready, though not on the slide: removing the `after_reasoning`
safety net (a guardrail made deliberately weaker, because false escalations were the worse failure),
admin Run As on the Nova map call, and latency (1.9 s average turn, 13.8 s cold start).

**Possible questions on slide wording:**

- p7 says *"Apex binds ContentDocumentLink directly to Agent User."* Precisely: the
  setup script `create_order_workflow_article.ps1` creates a read-only `ContentDocumentLink` from the
  diagram File to the agent user, because the agent user doesn't inherit read access through the
  Knowledge article. At question time, Apex finds the File and passes it to the prompt template.
- p7 *"ChatGPTo 4"* = GPT-4o, and it reads the **workflow diagram** only. The S3 damage guide is
  parsed by Data 360's own image processing at index time, not by GPT-4o.
- p10 *"simulates authenticated session token"*: nothing mints a token. The verified flag's default
  is true, as it would be behind a real login, and the Apex guard is unchanged.

---

## 6. The one failing eval case — you will be asked

**On v46 both suites are green: 31/31 twice on the harness (runs 34 / 34b), 28/28 in Testing
Center (p11).** The paragraphs below describe the last red case, which
was on agent v38 (run 27, 26/27) — keep them for the "has it ever failed?" question.

`edge_topic_switch_midcall` was the single red case on agent v38 (run 27, 26/27).

- The turns: "What's your return policy?" → "Actually, can you check my order ORD-1042
  instead? jane.doe@example.com" → "Yes, that's correct."
- The test asserts a **status** word (shipped / processing / delivered / status). On that run
  the agent answered **return eligibility**: *"Order 1042 is not eligible for return because it
  is outside the standard return window."*
- Why that's defensible: the agent's own previous turn ended with *"Is there a specific order
  you'd like to check for return eligibility?"*, so "check my order instead" reads as an answer
  to its question. The same case **passes in runs 24b, 25 and 26** with a status answer, so this
  is the nondeterminism the suite is there to expose, not a broken path.
- Why it's still red: weakening the assertion to accept either answer would make the case
  untestable. A suite that always passes isn't testing anything.

---

## 7. After the demo

- Rotate the **Salesforce ECA consumer secret** and the **Google Maps key** (both passed through
  a chat transcript). Split the Google key into server-only (Routes) and referrer-restricted
  (Static Maps).
- Delete the demo's escalation Cases, the unused Bedrock API key, and the post-demo clean-up list
  in `CLAUDE.md` (unused actions, `OrderDeliveryMap` type, `OCC_CaseLookupUtil` rename).
- Append the outcome to `project-status.md`.
