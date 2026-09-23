# Flex Credits — consumption overview and live-environment estimate

**Agent:** `Keyburn_Customer_Service` v42 · **Rate card:** Flex Credits Rate Card, updated
2026-08-31 · **Written:** 2026-09-23

What this document answers: if the Keyburn Order & Case Concierge ran in a **production** org
instead of this DEV org, what would it consume in Flex Credits, and which design decisions drive
that number.

The short version: **≈ 57 credits per conversation**, and **half of that is the Phase 16
verification gate**. Actions are the only per-conversation meter on the rate card — turns, routing,
Trust-layer checks and subagent transitions carry no line — so the cost profile is set by how many
actions a conversation invokes, not by how long it is.

---

## 1. Scope and assumptions

| | |
|---|---|
| Environment modelled | **Production** (multiplier 20 for Agentforce Actions). Sandbox/pre-production is 16 — a 20% discount |
| Agent version | v42 (Phase 16 gate enforced in Apex) |
| Channels modelled | Embedded Messaging (text) and the Phase 11 Bedrock Nova page. Both relay to Agentforce as text turns, so both bill actions at 20 |
| Calibration source | `docfiles/observability_readout_run01.md` — 403 traced sessions, 1,431 turns, 5,829 steps, 297 action calls (2026-09-22) |
| Credit price | **Assumed $0.005 per credit**, i.e. ~$0.10 per action. **Not from the rate card** — the card carries multipliers only. Confirm against the Order Form before quoting any dollar figure |

Three things the rate card makes explicit and that shape everything below:

1. Flex Credits **expire at the Order End Date and do not roll over**. Under-consuming is a real
   loss, not a saving — the estimate is as much a sizing tool for the entitlement as a cost forecast.
2. The **sandbox multiplier covers sandboxes and scratch orgs**. It does not name Developer Edition
   orgs, so whether this build's own eval history was billed at 16 or 20 is an open question (§9).
3. Multipliers and tiers "may be updated from time to time", and a tier change is treated as a
   multiplier change. This estimate is a snapshot of the 2026-08-31 card.

---

## 2. What in this build consumes Flex Credits

| Component | Rate-card usage type | Multiplier (prod) | Notes |
|---|---|---|---|
| 10 custom Apex actions (`OCC_GetOrderStatus`, `OCC_GetOrderDeliveryInfo`, `OCC_GetCaseStatus`, `OCC_ListOpenCases`, `OCC_CreateSupportCase`, `OCC_CheckReturnEligibility`, `OCC_ExplainOrderWorkflow`, `OCC_CreateEscalationCase`, `OCC_SendVerificationCode`, `OCC_VerifyCode`) | Agentforce Actions → **Custom Action** | 20 | The primary meter. Per invocation, not per conversation |
| `AnswerQuestionsWithKnowledge` (`standardInvocableAction://streamKnowledgeSearch`) | Agentforce Actions → **Standard Action** | 20 | Same multiplier as custom — there is no saving in preferring standard actions |
| `OCC_Order_Workflow_Diagram` (Flex prompt template, `sfdc_ai__DefaultGPT4Omni`, reads the PNG) | Salesforce-enabled foundational LLMs → **Standard Prompts** (assumed) | 4 | Invoked from inside `OCC_ExplainOrderWorkflow`, so that answer pays twice. Tier unconfirmed — Advanced would be 16 |
| Data Library index over the 5 Knowledge articles | Data 360 → **Unstructured Processing** | 150 / MB | Per indexing pass, not per query |
| Phase 13 S3 → Data 360 corpus (3 HTML + PDF + PNG) | Data 360 → **Unstructured** or **Intelligent Processing** | 150 or 600 / MB | Intelligent Processing is the 4× line; it is what reads the visual documents |
| Session Tracing rows landing in Data 360 | Data 360 → **Prep** (assumed) | 40 / 1M rows | ~19 rows per session |
| `observability_readout.apex` / `_session_detail.apex` | Data 360 → **Queries** | 3 / 1M rows | Rounding error |
| Eval harness + Testing Center runs | Agentforce Actions | 20 (16 in a sandbox) | Regression suites invoke **real** actions and are billed like live traffic |

### What does not consume Flex Credits — and who bills it instead

- **Apex execution, SOQL and DML** — platform limits, not credits. The whole
  `with sharing` / `WITH USER_MODE` least-privilege layer is free.
- **Google Routes API + Maps Static API** (`OCC_GetOrderDeliveryInfo`, `OCC_DeliveryMap`) — billed
  by Google on the API key, unrelated to Flex Credits.
- **Amazon Bedrock Nova 2 Sonic** speech, and the WebSocket transport — billed by AWS. This is the
  cost lever in §7.
- **Embedded Messaging, Omni-Channel routing, the VF/Sites pages, the `occOrderDeliveryMap` LWC,
  the Custom Lightning Type** — licensing and platform, no metered usage type.
- **Turns, router re-classification, the 21 `@utils.transition` hops, and the Trust layer.** The
  traced window shows 697 `pre_orchestration.guardrail` and 619 `InstructionAdherence` steps — one
  of each per reasoning turn, so the Trust layer runs on every turn and appears nowhere on the rate
  card.
- **Agent Analytics / Tableau Next dashboards and Agent Health alerts** — a licence question
  (Tableau Next Limited Consumer), not credits.
- **Deployed-but-unwired Apex** (`OCC_UpdateCase`, `OCC_GetOrderMapLink`, `OCC_ShowDeliveryMap`,
  `OCC_PolicyFAQLookup`) — zero, because the model cannot invoke them in v42.

Rate-card usage types this build **never touches**, worth stating so nobody assumes Data Cloud is
inherently expensive: Data 360 **Unification** (75,000 per 1M rows — the card's costliest line),
Segmentation, Activation, Zero-Copy Sharing-Out, Streaming Pipeline, Real-Time Pipeline, Code
Extension; Slackbot Actions; Sales *Leads Worked*; Personalization Decisioning; Service *Help Agent
Resolutions*; Speech Foundations **Translation**; and **Bring Your Own LLM** Starter Prompts (the
build uses Salesforce-enabled foundational models only).

---

## 3. Actions per conversation

Built bottom-up from the v42 agent script, with the conversation mix informed by the traced subagent
distribution (`order_status` 270 turns · `policy_faq` 137 · `case_status` 98 · `escalation` 88 ·
`return_eligibility` 24).

| Conversation type | Mix | Actions | Composition |
|---|---|---|---|
| Order status / tracking | 45% | 3.2 | `SendVerificationCode` + `VerifyCode` + status or tracking lookup; some conversations do both |
| Case status / list / new case | 20% | 3.4 | gate (2) + 1.4 of `GetCaseStatus` / `ListOpenCases` / `CreateSupportCase` |
| Return eligibility | 8% | 3.0 | gate (2) + `CheckReturnEligibility` |
| Policy / FAQ / workflow | 20% | 1.3 | mostly **zero** actions (see below); `ExplainOrderWorkflow` in about half |
| Escalation-only / off-topic / chit-chat | 7% | 0.8 | `CreateEscalationCase`, or nothing at all |

Weighted average **2.68**, plus an escalation overlay (the traced escalation rate is 15.1%, applied
to the 93% of conversations that are not escalation-only) of **+0.14**:

> **2.8 actions per conversation → 56.3 credits, + 0.4 credits of workflow prompt ≈ 57 credits.**

**Why the FAQ path is nearly free.** The agent-level `knowledge:` block injects the articles into the
`policy_faq` prompt, so the model usually answers without calling anything. The trace proves it:
**137 `policy_faq` turns produced 8 `AnswerQuestionsWithKnowledge` calls.** Grounded answers at zero
action cost is the cheapest path in the build — and it is also why the Testing Center suite must not
assert that action (documented in `CLAUDE.md`).

**Calibration check.** The traced window shows 297 actions across 403 sessions = 0.74 per session,
far below 2.8. That is expected and not a contradiction: those sessions are eval-harness and
Testing Center traffic, mostly single-turn cases, and 352 of 403 ran on **v38 — before the gate
existed**. The 2.8 figure is the v42 architecture applied to human-shaped conversations; 0.74 is what
scripted tests cost.

---

## 4. Live scenarios (production, text or Nova-relayed)

| Conversations / month | Action credits | Prompt credits | Data 360 | Total | ≈ $ at $0.005 |
|---|---|---|---|---|---|
| 1,000 | **56,300** | 400 | ~2 | **~56,700** | ~$284 |
| 10,000 | **563,000** | 4,000 | ~8 | **~567,000** | ~$2,836 |
| 100,000 | **5,630,000** | 40,000 | ~82 | **~5,673,000** | ~$28,364 |

*(action credits = conversations × 2.8 × 20; Data 360 assumes one monthly re-index of the current
corpus plus Session Tracing ingestion.)*

- **≈ $0.28 per conversation**, ≈ $0.10 per action.
- The relationship is **linear in conversations**. There is no volume tiering on Agentforce Actions
  — the tiers on the card apply only to Data 360 usage types, which here are a rounding error. So
  100k conversations cost exactly 100× what 1k cost; no economy of scale arrives with growth.
- If GPT-4o turns out to be an **Advanced** prompt (16, not 4), the per-conversation figure moves
  from 56.7 to 57.9 — a 2% sensitivity. Not worth chasing.

---

## 5. Data 360 — corpus-driven, not conversation-driven

| Item | Size | Unstructured (150/MB) | Intelligent (600/MB) |
|---|---|---|---|
| 5 Knowledge articles | 0.0075 MB | 1.1 credits | 4.5 |
| Phase 13 S3 corpus (all) | 0.1345 MB | 20.2 credits | 80.7 |
| — of which PDF + PNG | 0.1299 MB | 19.5 | 78.0 |
| Session Tracing @ 10k conv/mo | 190,149 rows | 7.6 credits (Prep) | — |

At this corpus size Data 360 is **immaterial** — under 100 credits per indexing pass against 567,000
credits of actions at 10k conversations. The sensitivity is corpus size and re-index frequency:

> **1 GB of policy documents = 153,600 credits (~$768) through Unstructured Processing, or 614,400
> (~$3,072) through Intelligent Processing — per indexing pass.**

That 4× is the real Phase 13 architecture decision, and it lands on exactly the content this build
chose for the visual pipeline (the damage-grade PDF and PNG). Two operational notes with a cost
edge: a published Knowledge change re-chunks the index (so edit in batches, not one article at a
time), and **deleting Cases does not delete traces** — tracing rows accumulate and are billed on
ingestion regardless of later cleanup.

---

## 6. Build-to-date consumption (this DEV org)

| | |
|---|---|
| Hard number: actions in the traced window (7.5 h, 2026-09-22) | **297** → 4,752 credits at 16, 5,940 at 20 |
| Estimate for the whole build (32 harness runs + Testing Center + Builder previews + voice) | **2,000–4,000 actions ≈ 32,000–64,000 credits** (~$160–320 at 16) |

The estimate is unavoidably soft: Session Tracing was switched on in Phase 12 and **does not
backfill**, so everything before 2026-09-22 is unmeasurable. The lesson for a real programme is that
**evaluation is a billed workload** — a 29-case suite costs roughly 70 actions per run, and the
pass-rate climb that makes the Reliability evidence was paid for in credits.

---

## 7. Voice: what the Phase 11 architecture saves

Native Agentforce Voice bills actions at **30** instead of 20, and Salesforce's own speech stack adds
Speech Foundations credits (Speech to Text 150 per hour; Text to Speech 6,000 per 1M characters).

| Path | Per 4-minute call |
|---|---|
| Native Agentforce Voice | 2.8 × 30 = 84 action credits + ~10 STT + ~9 TTS ≈ **103 credits** |
| Phase 11 (Bedrock Nova relays text through the Agent API) | **≈ 57 credits** + an AWS bill |

**~45% cheaper per voice conversation in Flex Credits** — because Agentforce never sees a voice
session, only Agent API text turns. This was not a cost decision when it was built (the Voice add-on
was simply out of scope), but it is a real and defensible one: speech cost moves to AWS, where it is
priced per second of audio rather than per action, and the action multiplier stays at 20. The
trade-off is an unsupported integration, a second vendor, and the latency shown in the trace (the
Voice Preview channel averaged 2,181 ms against 1,769 ms for API).

---

## 8. Cost levers, ranked

1. **The Phase 16 verification gate is the single largest cost item in the build.**
   `SendVerificationCode` + `VerifyCode` add 2 actions to 73% of conversations = **29.2 credits per
   conversation, 51% of the total** — about **$1,460 per month at 10k conversations**. Without it the
   figure is 27.5 credits (~$0.14 per conversation).
   It is still the right decision: it is the only structural defence against a caller reading out
   someone else's email, and `CLAUDE.md`'s "an instruction is not a control surface" finding is that
   the advisory version (v40) demonstrably got skipped. But it should be **priced, not assumed free**,
   and it has an obvious optimisation: verify **once per authenticated session** (or cache a
   verification for N days) and skip the gate when the channel already carries an authenticated
   identity. For a signed-in web customer that removes nearly all of the 29 credits. Anonymous phone
   callers keep paying it, which is the correct place for the cost to sit.
2. **Actions are the only meter, so optimise action calls — not prose, turns or subagents.** Rewriting
   instructions, adding subagents, adding confirm-back turns and re-routing every turn are all free.
   This inverts the usual instinct to "reduce the number of turns": a chattier agent that calls one
   action costs less than a terse one that calls three.
3. **`ExplainOrderWorkflow` double-charges, and can triple-charge.** Custom action (20) + GPT-4o
   prompt (4) = 24 credits; when it returns `answered=false` the script falls through to
   `AnswerQuestionsWithKnowledge` for 20 more. One workflow question can cost **44+ credits** against
   0–20 for the knowledge path. Reading a diagram at question time is a strong capability and a
   strong demo, but if those four facts stabilise, moving them into Knowledge text would make them
   free.
4. **Knowledge injection is the cheapest grounded-answer mechanism available** — 137 turns, 8 billed
   actions. Prefer it over a lookup action wherever the answer is textual and static.
5. **Keep evaluation off production orgs**: 16 vs 20 is a 20% saving on a workload that runs
   repeatedly by design.
6. **Data 360 scales with the corpus, not the conversation count** — and the
   Unstructured-vs-Intelligent Processing choice is a 4× decision per megabyte.
7. **Entitlement sizing matters as much as cost**, because credits do not roll over. At the
   assumptions above, a 1M-credit annual entitlement covers roughly **17,600 conversations** — the
   arithmetic worth doing before signing, in either direction.

---

## 9. Open questions — confirm before quoting these numbers externally

- **Credit price.** $0.005/credit (~$0.10 per action) is an assumption; the rate card gives
  multipliers only. The Order Form's Usage Details table is the authority.
- **Prompt tier of `sfdc_ai__DefaultGPT4Omni`** — Basic (2), Standard (4) or Advanced (16). Modelled
  as Standard; 2% sensitivity either way.
- **Does a Developer Edition org get the 16× multiplier?** The card names sandboxes and scratch orgs
  as pre-production. This affects only §6.
- **Does Agentforce Optimization scoring bill as prompts?** 179 moments were scored for Quality,
  Deflection and Abandonment in one afternoon. If each is an LLM call, observability has a
  per-conversation cost that this model omits. Not in the rate card either way.
- **Does messaging voice mode bill at 30?** `isVoiceModeEnabled` on the `Agentforce_Service_Agent`
  channel puts a mic in the deployed chat without the telephony add-on. Whether that counts as an
  Agentforce Voice Action, or whether **Agentforce Voice Minutes** applies instead (card footnote 1),
  changes §7 materially.
- **Are transitions and zero-action turns genuinely free?** Modelled as free, since neither appears on
  the card. Worth confirming against a real consumption report rather than the card's silence.
- **Customer 360 Platform "Headless Platform Interaction" is TBA** on the card — an unpriced line for
  any headless client built on `OCC_OrderMapRest` or the Agent API.

## 10. How to re-derive this

The action inventory:

```powershell
# from sfdx-project/
Select-String -Path force-app\main\default\aiAuthoringBundles\Keyburn_Customer_Service\Keyburn_Customer_Service.agent `
  -Pattern 'apex://|standardInvocableAction://'
```

Actual action volume, per action, from the Session Tracing tables:

```powershell
sf apex run --file scripts/observability_readout.apex --target-org devorg | Select-String "READOUT\|"
```

Everything in §3 and §4 is that action table divided by the session count and re-weighted; the
working is in this document rather than in a script, so a reader can disagree with the mix without
re-running anything. Replace the mix with a real production channel report as soon as one exists —
the conversation mix is the largest source of error in the estimate, well ahead of the prompt tier.
