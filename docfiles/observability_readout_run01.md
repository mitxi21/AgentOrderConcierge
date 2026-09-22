# Phase 17 — observability readout, run 01 (pre-freeze)

Read from the Session Tracing Data Model in Data 360 with
`sfdx-project/scripts/observability_readout.apex` on **2026-09-22 ~21:00 UTC**, plus the
Sessions & Intents UI (`docfiles/SessionAndIntents.png`).

This is the **pre-freeze** run: it is mostly v38 traffic. Re-run after the Wed 23 18:00 freeze
(`run02`) so the readout describes the version actually demoed.

## Window and volume

| | |
|---|---|
| First traced session | 2026-09-22 12:26:49 UTC |
| Last traced session | 2026-09-22 19:50:30 UTC |
| Sessions (agent `Keyburn_Customer_Service`) | **403** |
| Turns (interactions) | 1,431 |
| Steps | 5,829 |
| Scored moments (Sessions & Intents) | 179 processed |

Tracing does not backfill: everything before today's Phase 12 switch-on is invisible. Two more
sessions belong to "Authoring agent" (the Builder's own) and are filtered out everywhere below.

**Sessions by agent version:** v38 352 · v39 48 · v40 3.
The version is on the session *participant* row, so a readout can always say which version produced
a number — worth keeping in the deck, because the pass-rate story spans four versions.

**Sessions by channel:** Unknown (Internal) 219 · API 150 · Builder: Voice Preview 34.
"Unknown (Internal)" is Testing Center / preview traffic; "API" is the Python eval harness. Session
end type is `NOT_SET` on every session — nothing here ends through a real client disconnect.

## Volume per subagent

The trace stores the subagent name with the planner id of the version that ran it
(`order_status_16jak000003GChp`); the script strips that suffix, or the same subagent appears once
per version.

| Subagent | Turns | Sessions |
|---|---|---|
| (router / session-level, `NOT_SET`) | 734 | 404 |
| order_status | 270 | 140 |
| policy_faq | 137 | 137 |
| case_status | 98 | 63 |
| escalation | 88 | 65 |
| Chit_Chat | 76 | 23 |
| return_eligibility | 24 | 14 |
| customer_verification | 3 | 2 |
| off_topic | 1 | 1 |

`customer_verification` is the Phase 16 gate: 3 turns, because v40 has only just been activated.

## Actions: 297 calls, zero errors

| Action | Calls | Errors |
|---|---|---|
| CreateEscalationCase | 61 | 0 |
| ExplainOrderWorkflow | 55 | 0 |
| GetOrderDeliveryInfo | 55 | 0 |
| GetOrderStatus | 52 | 0 |
| ListOpenCases | 28 | 0 |
| GetCaseStatus | 12 | 0 |
| CreateSupportCase | 11 | 0 |
| CheckReturnEligibility | 10 | 0 |
| AnswerQuestionsWithKnowledge | 8 | 0 |
| SendVerificationCode | 3 | 0 |
| VerifyCode | 2 | 0 |

`ssot__ErrorMessageText__c` is non-null on **no step at all** across the whole window. Every Apex
action returns a clean `found`/`success` flag instead of throwing, so platform-level action errors
are genuinely zero — but it also means a business-level "not found" is invisible to this metric.
Don't quote "0 errors" as if it measured answer quality; that is what the quality scores below are for.

## Escalation and containment

- Sessions that ran `CreateEscalationCase`: **61 of 403 = 15.1%**.
- Guardrail steps: `pre_orchestration.guardrail` 697, `InstructionAdherence` 619 — one of each per
  reasoning turn, so the Trust layer is running on every turn, not sampled.

**Reconciliation with the org:** 31 agent-created Cases exist today (27 High, 4 Medium), not 61.
The difference is the Phase 15 eval-Case purge earlier the same afternoon, not a lost write —
deleting Cases does not delete traces. **The trace is the durable record of what the agent did.**
That is a genuinely good panel line, but it means the two numbers must never be shown side by side
without the explanation.

## Latency

| | |
|---|---|
| Average turn | 1,780 ms |
| Slowest turn | 11,717 ms |

By channel: Unknown (Internal) 1,592 ms · API 1,769 ms · **Builder: Voice Preview 2,181 ms**.
Voice is the slowest channel, which matches the Phase 11 finding that a cold first Agentforce turn
took 13.8 s — hence the warm-up call in the demo pre-flight.

## Quality, deflection and abandonment (Agentforce Optimization)

Each moment carries several tag types, so they have to be grouped by tag definition or the values
come out mixed (1–5 scores together with TRUE/FALSE/Unsure).

| Quality Score | Moments |
|---|---|
| 5 | 121 |
| 4 | 23 |
| 3 | 22 |
| 2 | 22 |
| 1 | 0 |

**77% of scored moments are 4 or 5, and nothing scored 1.**

| Deflection Score | Moments | | Abandonment | Moments |
|---|---|---|---|---|
| 5 | 138 | | TRUE | 150 |
| 4 | 10 | | FALSE | 86 |
| 3 | 11 | | Unsure | 31 |
| 2 | 13 | | | |
| 1 | 95 | | | |

**Read these two with the channel mix in mind.** An eval-harness session sends its scripted turns
and stops; nobody says goodbye. The scorer sees a conversation that just stops and calls it
abandoned and not deflected. 150 "abandoned" sessions is mostly a property of how the traffic was
generated, not of the agent. The honest version: *these scores need real user traffic to mean
anything, and that is exactly why the readout is repeated after the freeze.*

## Findings worth acting on

1. **Chit-chat tail in voice.** Up to **7 consecutive `Chit_Chat` turns** at the end of voice
   sessions: the caller says "take care", the agent answers, the caller answers back, and neither
   side ends the call. The Nova page has auto hang-up (`relay.is_goodbye`); the Builder voice
   preview does not, so the loop is visible there. Low risk for the demo, but rehearse ending the
   call rather than being polite back.
2. **Two malformed agent outputs** in ~700: `"0 -"` and `"Hello - "`. Both are voice-preview turns
   that reached the caller as text. 4 outputs in total are under 12 characters. Not worth chasing
   before the demo; worth a note in the deck's honest-trade-offs slide.
3. **Low-quality moments cluster on the same intent:** 15 moments scored 2, and most of them are
   "I want to know the status of my order" with no identifier — i.e. the confirm-back turn, which is
   correct behaviour scored as a poor answer. Same lesson as Phase 8: *a scored failure is not
   automatically an agent defect.*

## Drill-down kept for the demo

`sfdx-project/scripts/observability_session_detail.apex`, session
`01a0ca6f-a0d0-743d-b8e4-1537a25cce15` (Builder: Voice Preview, v39, 18:45 UTC) — a refund request
escalated end to end:

```
18:45:27  Input   "I'd like to request a refund for my last order, please."
18:45:31  TOPIC_STEP           agent_router
18:45:31  LLM_STEP             escalation
18:45:32  ACTION_STEP          CreateEscalationCase
              input  {"reasonCode":"financial_request","summary":"Caller requested a refund ..."}
              output {"caseNumber":"00001278","message":"A team member will follow up within 1 business day ..."}
18:45:33  LLM_STEP             Atlas__GroundednessValidationPrompt
18:45:33  TRUST_GUARDRAILS_STEP InstructionAdherence
18:45:33  Output  "... your case number is 0 0 0 0 1 2 7 8."
```

Router → subagent → action (with its real input and output) → groundedness check → instruction
adherence, in one screen. This is the strongest observability artefact in the build: it shows
reasoning, tool call and Trust layer for a single real conversation.

## Agent Health Monitoring

One alert, created through `POST /services/data/v66.0/tableau/dataAlerts`:

| | |
|---|---|
| Alert id | `3VRak00000007BBGAY` |
| Name | Keyburn escalation rate above 10 percent (last 24h) |
| Metric | `Escalation_Rate_mtc` on *Service Agent Analytics Base* |
| Filter | agent API name = `Keyburn_Customer_Service` (auto-created sub-metric `1HUak000005cT4XGAU`) |
| Condition | ≥ `0.1` (raw ratio = 10%) over the last 24 h |
| Checked | every 15 minutes |
| Delivered to | admin, in-app notification + email |

The threshold is deliberately below today's 15.1%, so the alert fires and there is an Incidents
entry to show. For a real deployment it would sit above the normal band with a minimum-volume guard.

## Still to capture (UI, before the demo)

- [ ] Agent Analytics → Service Agent Analytics dashboard: containment / escalation / volume,
      reconciled against the numbers above.
- [ ] Sessions & Intents: intent clusters (have: `SessionAndIntents.png`) **and** one session
      drilled to its reasoning chain.
- [ ] Alerts: the alert definition and, once it has run, its Incidents tab.

## How to repeat this

```powershell
cd sfdx-project
sf apex run --file scripts/observability_readout.apex --target-org devorg | Select-String "READOUT\|"
sf apex run --file scripts/observability_session_detail.apex --target-org devorg | Select-String "DETAIL\|"
```

Both run as the admin through `ConnectApi.CdpQuery.queryAnsiSqlV2`; no Apex class is deployed to the
org for observability, and no permission set changed.
