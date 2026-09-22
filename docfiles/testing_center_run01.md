# Testing Center — run 01 baseline on agent v38 (2026-09-22)

Suite `Keyburn_Regression` (`sfdx-project/specs/Keyburn_Regression.yaml`): 28 cases converted from
the Python harness's `src/eval_cases.yaml`. Each case asserts three things:

- **topic**: the subagent the router picked;
- **actions**: the business actions called (superset match);
- **outcome**: an LLM judge scores the reply against a sentence describing the right behaviour.

The Python harness scores only the reply text. The topic and action checks are new.

| Run | Label | Topic | Actions | Outcome | All three green |
|---|---|---|---|---|---|
| 01 | baseline, v38 | 27/28 | 22/28 | 27/28 | 21/28 |
| 01b | **test fix** (spec only, agent unchanged) | 27/28 | 27/28 | 28/28 | 26/28 |

Results: `src/eval_reports/testing_center/tc_run01*_v38_*.json` (and `.junit.xml`). Summary:
`py -3.12 src/summarize_tc_run.py <file>`.

## What run 01 found, root-caused from Session Tracing

**1. Knowledge answers call no action (test defect, fixed in 01b).**

- Symptom: the four Policy/FAQ cases answered correctly but reported no `AnswerQuestionsWithKnowledge`.
- Evidence: the traced steps (`ssot__AiAgentInteractionStep__dlm`) have no `ACTION_STEP` at all.
- Cause: the `policy_faq` LLM step's prompt already contains a `# KNOWLEDGE ARTICLES` section, which
  the agent-level `knowledge:` block (Data Library) injects. The model answers from that grounded
  text without calling the action.
- Fix: the spec no longer asserts the action on these cases; the outcome asserts the fact instead.

**2. The workflow diagram is sometimes skipped (agent finding, open).**

- Also cause 1: the injected text includes the workflow article's text, so the model sometimes
  answers from it instead of reading the image with `ExplainOrderWorkflow`.
- `workflow_what_draft_means` skipped it on both runs. The answer was still acceptable.
- `workflow_draft_expiry` skipped it on one of the two runs. In that run it said a draft "will
  eventually expire" and credited "our order workflow guide", without the 30-day fact that exists
  only in the image. That's an ungrounded answer presented as a sourced one.
- The Python harness passed this case in run 28, so only an action assertion can see this.

**3. "Jane." is routed to escalation (agent finding, open).**

- Case: `edge_partial_answer_does_not_escalate`, wrong on both runs.
- The router sends the partial answer to `escalation`, despite its "NOT for a caller whose answer
  was partial" description. The escalation subagent then correctly re-asks for the email and
  creates no Case, so the reply is right while the routing is wrong. The text harness can't see this.

**4. Judge wording (test defect, fixed in 01b).**

- Case: `edge_correction_then_single_yes`.
- The judge failed a correct reply, which went straight to distance and ETA after the correction,
  because the outcome sentence read as though the reply had to acknowledge the correction.

## Other facts established

- **Testing Center runs real actions as the agent running user.** Run 01 created 5 Cases, all
  created by the agent user: 1 Medium support case on alex.chen and 4 High escalations. So the
  least-privilege permission set applies, the same as the harness with `bypassUser: true`. Nothing
  was created on maria.garcia.
- `conversationHistory` is replayed as text only; no actions run for it. That's why
  `guardrail_identity_switch_refused` stays harness-only: the identity lock is a variable that only
  an action output sets.
- Topic names are the `.agent` subagent names as they are (`order_status`, …); no hash suffixes.
  Action names are the reasoning-action names (identical to the definitions in this agent).
- A 28-case run takes about 4 minutes.

## CSV upload (single-turn cases)

Testing Center also takes a CSV of test cases, with the columns
`Utterance,Expected Subagent,Expected Actions,Expected Response`.
`sfdx-project/specs/Keyburn_Regression_upload.csv` holds the **single-turn** cases, 23 rows; the
multi-turn ones stay in `Keyburn_Regression.yaml`, because the CSV has no conversation history.

- 9 rows assert an action: 4 workflow (`ExplainOrderWorkflow`), 4 escalation
  (`CreateEscalationCase`), 1 open cases (`ListOpenCases`).
- The 4 Knowledge rows leave Expected Actions blank, for the reason in finding 1.
- The 10 lookup rows assert the subagent and the confirm-back only: on the caller's first turn the
  agent reads the order number and email back, so no action has run yet.

## CSV upload (conversation cases)

`sfdx-project/specs/Keyburn_Conversation_upload.csv`, columns
`Conversation,Expected Actions,Expected Subagents`, 20 rows. Here the Conversation column is a
**description the platform simulates a caller from**, not scripted turns, so every row states what
the caller supplies when asked (email, order or case number, and the confirmation). Without that,
the simulated caller never gets past the confirm-back and no action fires.

- Because a simulated conversation really runs the actions, this file can carry the case the YAML
  spec can't: the **identity switch** (verify as maria.garcia, then ask for jane.doe's order). The
  lock lives in `@variables.verified_email`, which only an action output sets.
- Two rows expect two subagents (topic switch, and open cases after an order lookup). They use the
  same list style as Expected Actions; if the upload rejects a list there, split them into
  single-subagent rows.
- The `escalation` rows create real High-priority Cases on every run, as in every other suite.

## Candidate agent fixes (not applied; they would need a new version before the Wed 18:00 freeze)

- Finding 2: in `policy_faq`, state that questions about order stages, drafts or cancelling
  **always** call `ExplainOrderWorkflow`, because the article text doesn't hold the diagram's facts.
- Finding 3: tighten the router's `go_to_escalation` description, or accept it and keep the
  assertion as a known wobble. It is harmless today only because the escalation subagent re-asks.
