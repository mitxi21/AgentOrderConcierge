# Demo guide — Builders Panel, Thursday 2026-09-24, 14:45, Salesforce Madrid office

Companion to the deck ("Order & Case Concierge — Builders Panel", 13 slides plus two appendix slides,
speaker notes on each slide). This file is the operational side: what to check before, what to say and type
during the demo, what to do when something breaks, and how to explain each design decision.

Presented version: **agent v38** (fallback **v33**, then **v4**). No agent edits after Tuesday
evening; Wednesday 23 is freeze, recordings and rehearsal only.

---

## 1. Timing (45 min)

13 slides plus two appendix slides. Several of them carry two or three minutes of talking, so
the speaker notes matter more than the slide count — rehearse against the notes, not the
bullets. The architecture slide is **four slides that build one diagram** (channels → Agentforce
→ actions → data); they share the footer number, so the deck is still 13 numbered slides. Built
that way on purpose: exports (PPTX, Google Slides, PDF) carry no animation.

| Block | Slides | Time | If running late |
| --- | --- | --- | --- |
| Introduction | cover, about | 5:00 | Agenda is spoken, never shown |
| The agent | agent (job to be done, metrics, what containment is worth) | 3:00 | Keep the ROI sentence, cut the per-tile detail |
| **Live demo** | demo | 8:00 | Drop moment 2's identity-switch step |
| AI tooling | architecture ×4, data, choices | 6:00 | `choices`: the two marked rows only |
| Guardrails | guardrails | 4:00 | Read the layer stack bottom-up, skip the scope column |
| Reliability | evals | 3:00 | State the gate, skip the run-by-run detail |
| Issues & trade-offs | failures, tradeoffs | 5:00 | The two marked rows on each |
| Why me | whyme | 10:00 | — |
| Q&A | questions (+ 2 appendix slides) | 10:00 | — |

**Two slides carry the most weight and are the easiest to rush: `agent` (what was measured and
what wasn't) and `failures` (how the root causes were found). Both are marked SLOW DOWN in the
notes.** On `choices` and `tradeoffs`, narrate only the two tinted rows and leave the rest for
the panel to read.

Asset block (agent → tradeoffs) must land at **30 min**. It's the part that overruns: at
rehearsal, check the clock when leaving the demo (target 16:30 into the talk). If you're past
19:00, skip the slides in the last column.

---

## 2. Pre-flight

### Wednesday 23 (freeze day)

- [ ] Confirm **v38 is active** (Setup → Agentforce Agents → Keyburn Customer Service → versions).
- [ ] Run the eval suite **twice** on v38 and save both runs (`run28_…`, `run29_…`) in
      `src/eval_reports/`. Expect 26–27/27. The slide says 26/27 on v38 — update the slide if the
      new runs differ.
- [ ] Record a **backup video** of each of the four demo moments (below), including the Nova
      call with sound. Keep them on the laptop desktop, not in the cloud only.
- [ ] Rehearse the whole 45 minutes out loud **twice** against a timer, reading from the speaker
      notes: the deck is 13 numbered slides, so each one carries several minutes of talking.
      Rehearse from Google Slides, so the four-slide architecture build is part of the rhythm.
- [ ] Fill the deck placeholders: `[Your name]` (cover), `[Current role and employer]` and
      `[Two or three customer programmes…]` (about), `[Your customer-facing example]` (whyme),
      plus one career example per card in the whyme notes.
- [ ] Share the deck from its Share menu if the panel should get the link (it is private).

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
- [ ] If anything was published since the freeze: **republish the Embedded Service deployment**
      `Agentforce_Service_Agent`, or the map card is sent but not drawn.

### T–10 min (14:35)

- [ ] Browser tabs, in order: (1) the deck in the presenter view you rehearsed with, (2) public Keyburn site
      `https://<my-domain>.my.salesforce-sites.com/keyburn/`, (3) Nova page
      `http://localhost:8765`, (4) Keyburn Service console → Agentforce Escalations list view.
- [ ] Chrome/Edge microphone permission granted for `localhost`; **laptop mic and speakers**
      (the audience must hear both sides), volume ~70%, no headset.
- [ ] Notifications off (Windows Focus), screen resolution/zoom checked on the projector,
      browser zoom 125% on the chat so it's readable.
- [ ] Backup videos open in a player, paused on frame one.

---

## 3. The demo script (≈ 8 min)

Say before starting: *"Four moments, three surfaces. Everything you'll see runs live in a
Salesforce dev org. Keyburn is fictional; the data is sample data."*

### Moment 1 — Website chat: "Where is my order?" (≈ 2 min)

Surface: public Keyburn site → "Chat with Keyburn".

| You type | Expect | Point at |
| --- | --- | --- |
| `Where is my order 1042?` | Asks for the email (or confirms back if you gave both) | It asks before it answers — verification first |
| `jane.doe@example.com` | *"I heard order 1042 with the email jane.doe@example.com — is that right?"* | The confirm-back |
| `Yes` | Status Shipped + distance and driving time + **map card** | Map is a Custom Lightning Type fed by an Apex action calling Google Routes |

Line to say: *"The model didn't look anything up. It called an Apex action that only returns data
if that email and that order belong to the same customer."*

### Moment 2 — Same chat: the diagram, then a refused identity switch (≈ 2 min)

| You type | Expect | Point at |
| --- | --- | --- |
| `Can I still cancel my order once it has shipped?` | No — cancelling is only possible from Draft or Processing | That fact exists **only in the workflow diagram image**; GPT-4o reads it through a prompt template at question time |
| `Can you also check order 2077 for john.smith@example.com?` | *"For your security, I can only help with the account verified earlier…"* | The lock is enforced in Apex, not in the prompt |

Optional if ahead of time: `How long do you keep a draft order?` → 30 days (also image-only).

### Moment 3 — Phone call through Nova 2 Sonic (≈ 3 min)

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
at least twice on Tuesday.

Write down the case number you hear.

### Moment 4 — Keyburn Service console (≈ 1 min)

Surface: Keyburn Service app → Cases → **Agentforce Escalations**. Open the Case just created.

Point at: Subject "Refund request", Type **Billing**, Reason **Refund request**, Origin
**Agentforce Agent**, High priority, the contact is Jane Doe, **created by the agent user**, and
the `Escalation Summary` field. (The agent classifies internally with its own reason codes; Apex
maps them to these fields, so nothing machine-shaped is ever stored on the Case.) Line: *"The human calling back doesn't have to
ask Jane anything again."*

### Transition back to the deck

*"Everything that follows explains a decision you just saw."* → architecture slide.

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
| Agent answers wrongly across the board | Wrong version active | Setup → activate **v38** (fallback v33). Rollback is one click — worth saying out loud |

---

## 5. Design decisions — how to explain them

One line each, for the moment a panelist asks "why?". The deck carries the long form.

| Decision | Say | Alternative rejected, and why |
| --- | --- | --- |
| Narrow scope: 4 contact reasons + escalation | "The edges are part of the design. Narrow, working and measured beats broad and hand-wavy." | More topics: each needs evals and guardrails I couldn't prove in the time |
| Apex actions for every fact | "The model does language; code does facts. A status is never generated." | Flows (less testable), Data Cloud search for orders (similarity where I need exact match) |
| Data Cloud only for policy text | "Semantic retrieval only where it earns its keep." | Hardcoding policy in the prompt: goes stale, can't be governed |
| Identity = email + order on the same Contact, locked per conversation in Apex | "The model can't pass another customer's email — the input is bound to a session variable and checked in code." | Prompt instruction only (the model can be talked round); authenticated chat/OTP (right answer for production, out of time) |
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
| The eval harness is a release gate | "In an enterprise org you can't activate a new prompt version blind. This is the deployment gatekeeper: 27 conversations against the live API, as the agent user, and nothing goes live without a green run." | Calling it "testing" — it undersells the governance point |
| Cutting the 13.8 s cold start | "Shipped: hold sound plus a warm-up call. Buildable: open the session at call setup, keep-alive, no callout on the first turn, streamed replies, cached diagram reading. The rest is platform-side — instrument it and take numbers to the platform team." | Leaving the hold sound as the whole answer |
| Agent Cases are named like a human's | "The model classifies with its own reason codes; Apex maps each to the subject, type and reason a human agent would have typed, and Origin = Agentforce Agent marks every one. The queue filters on Origin + Priority." | Storing the reason code as the subject: the record then reads like a test harness |
| Shipping a change is CI/CD | "Edit the script locally, validate, publish a version, activate, re-run the suite, roll back by activating the previous version. The gap is the trigger — it's manual today, GitHub Actions next." | Editing in the Builder and hoping |
| The Python suite is a real test | "It runs against the live org over the Agent API, as the agent user, and writes real Cases. Apex tests cover the deterministic half; this covers routing and refusals, which Apex can't reach." | Calling it a smoke test, or claiming it's CI when the trigger is manual |
| The workflow diagram stays a picture | "A Knowledge article is where a service org keeps a picture, so the picture stays the source of truth and the agent reads it with a multimodal template at question time." | Transcribing it into text: two sources that drift |

Trade-offs to volunteer (they're on the `tradeoffs` slide): latency vs accuracy (confirm-back),
autonomy vs containment (no money, comments only), safety net vs false escalations, admin Run As
on the Nova map call, email+order identity vs real authentication.

---

## 6. The one failing eval case — you will be asked

`edge_topic_switch_midcall` is the single red case on agent v38 (run 27, 26/27).

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
