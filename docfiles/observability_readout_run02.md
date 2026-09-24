# Phase 17 — observability readout, run 02 (post-freeze, demo day)

Read from the Session Tracing Data Model in Data 360 with
`sfdx-project/scripts/observability_readout.apex` on **2026-09-24 ~11:47 UTC**, a few hours before
the demo. Run 01 (`observability_readout_run01.md`) was taken on 09-22 and is mostly v38 traffic;
this run covers the whole build week including **v46, the version being demoed**.

**Read the output with the decode pipeline, not the old grep.** The CLI now HTML-escapes the pipe
in debug output, so the `Select-String "READOUT\|"` documented in run 01 returns **four lines, all
of them the script's own source echo, and no data**:

```powershell
cd sfdx-project
sf apex run --file scripts/observability_readout.apex --target-org devorg |
  Select-String "USER_DEBUG.*READOUT" |
  ForEach-Object { ($_ -replace '.*DEBUG\|READOUT&#124;','') -replace '&#124;',' | ' }
```

## Window and volume

| | | run 01 |
|---|---|---|
| First traced session | 2026-09-22 12:26:49 UTC | same |
| Last traced session | 2026-09-24 07:58:27 UTC | 2026-09-22 19:50:30 UTC |
| Sessions (agent `Keyburn_Customer_Service`) | **681** | 403 |
| Turns (interactions) | 2,600 | 1,431 |
| Steps | 11,452 | 5,829 |
| Scored moments (Quality) | 691 | 188 |

**Sessions by agent version:** v38 352 · **v46 95** · v44 64 · v39 61 · v42 60 · v40 37 · v41 7 ·
v43 4 · v45 1. The version sits on the session *participant* row, so every number below can be
attributed to a version — still the most useful property of this dataset for the deck.

**Sessions by channel:** API 373 · Unknown (Internal) 252 · Builder: Voice Preview 53 ·
**SCRT2 - EmbeddedMessaging 2** · Builder 1. "API" is the Python eval harness, "Unknown (Internal)"
is Testing Center / preview. The two EmbeddedMessaging sessions are the only deployed-chat traffic
in the whole window.

## Escalation rate: 15.4%, and why the dashboard says 0%

- Sessions that ran `CreateEscalationCase`: **105 of 681 = 15.4%** (run 01: 61 of 403 = 15.1%).
  Stable across nine agent versions, which is worth saying out loud — the number did not move when
  the verification gate went in and came back out.
- **Agent Analytics shows Escalation Rate 0%, and that is correct, not a data fault.** The platform
  metric means *the conversation was handed to a human*. This agent never does that:
  `OCC_CreateEscalationCase` writes a High-priority Case, says a specialist will follow up, and the
  conversation stays with the agent. `ssot__AiAgentSessionEndType__c` is **`NOT_SET` on all five
  channel rows**, so there is no handoff signal for the metric to count.
- It is **not** an artefact of purging eval Cases. Traces outlive Cases — run 01 already proved this
  by reading 61 escalations out of the trace on an afternoon when the purge had left 31 Cases in the
  org.
- **Consequence for the Phase 17 alert:** `3VRak00000007BBGAY` watches `Escalation_Rate_mtc`, the
  platform metric, at ≥ 0.1. While escalation stays case-based that metric is pinned at 0, so the
  alert cannot fire. The alert demonstrates the *mechanism*; the containment story has to be told
  with the trace number.

The honest framing for the panel: *the dashboard measures handoff-to-human; my escalation is a
case-logging handoff, so I measure containment from the trace instead.* That is a design decision
with a measurement consequence, which is a better answer than a green dashboard.

## Actions: 622 calls, zero errors

| Action | Calls | Errors |
|---|---|---|
| GetOrderDeliveryInfo | 111 | 0 |
| CreateEscalationCase | 105 | 0 |
| ExplainOrderWorkflow | 92 | 0 |
| GetOrderStatus | 90 | 0 |
| SendVerificationCode | 58 | 0 |
| VerifyCode | 52 | 0 |
| ListOpenCases | 42 | 0 |
| GetCaseStatus | 19 | 0 |
| CreateSupportCase | 18 | 0 |
| CheckReturnEligibility | 18 | 0 |
| AnswerQuestionsWithKnowledge | 17 | 0 |

`action_errors` came back **EMPTY** again: no step in 11,452 has a non-null
`ssot__ErrorMessageText__c`. Same caveat as run 01 — every Apex action returns a clean
`found`/`success` flag instead of throwing, so a business-level "not found" is invisible here. Do
not quote "zero errors" as an answer-quality claim.

`SendVerificationCode` 58 / `VerifyCode` 52 are the v40–v42 OTP window; the gate is switched off on
v44/v46, so those counters are now frozen.

## Steps and latency

| Step type | Steps | | | |
|---|---|---|---|---|
| LLM_STEP | 3,481 | | Avg turn | **1,911 ms** |
| VARIABLE_UPDATE_STEP | 3,033 | | Slowest turn | 14,406 ms |
| CLASSIFIER_STEP | 1,334 | | Turns measured | 2,600 |
| TOPIC_STEP | 1,232 | | | |
| TRUST_GUARDRAILS_STEP | 1,227 | | | |
| ACTION_STEP | 622 | | | |
| SESSION_END | 522 | | | |
| INTERRUPT_STEP | 1 | | | |

1,227 Trust guardrail steps against 1,232 topic steps — the Trust layer runs on essentially every
turn, not sampled. Average latency is unchanged from run 01 (1.9 s); the 14.4 s maximum is the cold
first turn that the demo pre-flight warm-up call exists to avoid.

## Volume per subagent

| Subagent | Turns | Sessions |
|---|---|---|
| (router / session-level, `NOT_SET`) | 1,264 | 700 |
| order_status | 546 | 256 |
| policy_faq | 225 | 223 |
| case_status | 179 | 107 |
| escalation | 151 | 119 |
| Chit_Chat | 104 | 30 |
| customer_verification | 58 | 54 |
| return_eligibility | 53 | 27 |
| call_closing | 12 | 11 |
| off_topic | 4 | 2 |
| ambiguous_question | 4 | 4 |

**`call_closing` is visible for the first time** — 12 turns across 11 sessions, the v44 two-step
call close running in real traffic. `customer_verification` grew from 3 turns to 58 across the gate
window and stops there.

## Quality, deflection and abandonment

| Quality Score | Moments | | Deflection | Moments | | Abandonment | Moments |
|---|---|---|---|---|---|---|---|
| 5 | 427 | | 5 | 285 | | TRUE | 252 |
| 4 | 83 | | 4 | 25 | | FALSE | 198 |
| 3 | 81 | | 3 | 17 | | Unsure | 41 |
| 2 | 99 | | 2 | 37 | | | |
| 1 | 1 | | 1 | 127 | | | |

**74% of scored moments are 4 or 5** (run 01: 77%), and exactly one moment scored 1 — *"I am
expressing gratitude for the assistance provided"*, a closing pleasantry.

The 3-point dip is concentrated in the gate window: score-2 moments went 22 → 99, and the
`low_quality_moments` list is dominated by order-status turns where the agent correctly asked for an
identifier or correctly refused an unverified lookup. Same lesson as run 01 and as Phase 8: **a
scored failure is not automatically an agent defect.**

**Don't reconcile these against the dashboard 1:1 on stage.** The dashboard aggregates per session
over 30 days; these are per moment. Abandonment TRUE is 252 of 491 moments (51%) against the
dashboard's 42.88%, and the gap is definitional, not a data fault. The deeper caveat from run 01
still holds: eval-harness sessions send their scripted turns and stop, so the scorer sees a
conversation that just ends and calls it abandoned. These scores need real user traffic to mean
anything.

## Intent clusters (Optimization Request Category)

| Category | Moments | | Category | Moments |
|---|---|---|---|---|
| Order Status and Tracking | 211 | | Request Refund | 20 |
| Return Eligibility and Policies | 63 | | Check Shipping Duration | 19 |
| Checking and Managing Case Status | 62 | | Check Warranty Coverage | 19 |
| Understand Order Stages | 60 | | Escalate Unresolved Case | 17 |
| Cancel Shipped Order | 20 | | Request to Cancel Account and Delete Data | 17 |
| Request General Order Assistance | 10 | | Open New Support Case | 11 |

The platform clustered the traffic into categories that map cleanly onto the five subagents without
being told about them — a reasonable thing to show next to the agent's own topic design.

## How to repeat this

```powershell
cd sfdx-project
sf apex run --file scripts/observability_readout.apex --target-org devorg |
  Select-String "USER_DEBUG.*READOUT" |
  ForEach-Object { ($_ -replace '.*DEBUG\|READOUT&#124;','') -replace '&#124;',' | ' }
sf apex run --file scripts/observability_session_detail.apex --target-org devorg |
  Select-String "USER_DEBUG.*DETAIL" |
  ForEach-Object { ($_ -replace '.*DEBUG\|DETAIL&#124;','') -replace '&#124;',' | ' }
```

Both run as the admin through `ConnectApi.CdpQuery.queryAnsiSqlV2`; no Apex class is deployed to the
org for observability, and no permission set changed.

Newest escalated session, for `observability_session_detail.apex` (edit `SESSION_ID`):
`01a0d248-b5d8-7565-9399-548662c46891` (2026-09-24 07:19:57 UTC).
