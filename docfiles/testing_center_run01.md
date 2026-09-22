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
`Utterance,Expected Subagent,Expected Actions,Expected Response`. Multi-turn cases stay in
`Keyburn_Regression.yaml`, because the CSV has no conversation history. Two files, because a blank
Expected Actions cell fails rather than skipping the assertion:

- `specs/Keyburn_Regression_upload.csv` — **10 rows that really fire an action** in one turn:
  4 workflow (`ExplainOrderWorkflow`), 4 escalation (`CreateEscalationCase`), open cases
  (`ListOpenCases`) and case status (`GetCaseStatus`). Upload with Action Evaluation **on**,
  and with **live** actions.
- `specs/Keyburn_Regression_noaction.csv` — **13 rows that can't**: the 4 Knowledge answers (the
  articles are injected into the prompt) and 9 lookups, where the caller's first turn only earns a
  confirm-back. Upload as a separate suite with Action Evaluation **off**; it asserts the subagent
  and the reply.

Scorers for both: Response (`bot_response_rating`), Subagent, Coherence, Latency. **Off**:
Completeness (fails a correct confirm-back) and Conciseness (returns 0 regardless).

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

## Agentforce Studio → Tests is a separate store, with different scorers (2026-09-22)

The Studio suites built from the two CSVs are **not** `AiEvaluationDefinition` metadata: `sf agent
test list` and a metadata listing show only the CLI's `Keyburn_Regression`, and `AiEvaluationTestSet`
is empty. The two paths run independently and capture different things.

**v2, conversation suite (20 simulated conversations): subagent and action assertions don't work.**

- Every row failed with `Missing expected topics: [order_status]. Actual topics: []`, and the grid's
  `Actual Subagent` cell is `{"content":[],...}` on all 20 rows.
- Session Tracing shows the agent did route and act (`TOPIC_STEP agent_router` → `LLM_STEP
  order_status` → `ACTION_STEP GetOrderStatus`), so this is capture, not behaviour.
- Consistent with the documented fact that **the Agent API returns text only** (`result: []`): the
  simulated-conversation runner appears to use that path, so no structured data reaches the scorers.
  The CLI path does capture both (`generatedData.topic`, `actionsSequence`).
- **So: assertions live in the CLI suite; the Studio conversation suite keeps the conversation-level
  scorers** (Task Resolution, Quality, Deflection, Abandonment), which are judged from the transcript.
  Still unconfirmed: whether "Text and voice" or the personas cause the drop — a Text-only,
  Default-persona run of one row would settle it.

**Correction:** subagent assertions work fine in the **single-turn** suite — `planner_topic_assertion`
passed on every row with `Actual Subagent` populated. Only the **conversation** suite returns empty
topics. So the limitation is the conversation runner, not Studio as a whole.

**v1, single-turn suite: three separate causes, only one of them the agent.**

1. **A blank `Expected Actions` cell is not "don't assert".** Studio runs
   `planner_actions_assertion` anyway and fails an empty expected list. Proof: the `case 1026` row
   had `Actual Actions = [GetCaseStatus]`, the agent was right, and the row still failed because the
   cell was empty. Hence the split into two CSVs: `Keyburn_Regression_upload.csv` (10 rows that
   really fire an action) and `Keyburn_Regression_noaction.csv` (13 rows that can't, to upload as a
   separate suite **with Action Evaluation off**).
2. **Completeness is the wrong scorer for single-turn cases.** A confirm-back ("I heard order 1042
   … is that right?") is correct *and* incomplete by definition, so it scores 1–2/5. Turn it off
   here; Response Evaluation (`bot_response_rating`) is the one that passes on those rows.
3. **Action mode: that run used simulated actions.** It created no Cases at all — the last Case in
   the org was still 00001242 from the conversation run — yet `Actual Actions` listed
   `CreateEscalationCase`. That is why the replies said "your case number is **None**" and "I wasn't
   able to open a case right now": the action was selected but never executed, so its outputs were
   null. An earlier v1 run *did* create Cases 00001234–00001237, so this is a per-suite setting (the
   wizard's **Conditions** step). **Run the action suite live** — asserting that an escalation really
   logs a Case is a core claim — and expect ~5 Cases per run.

**The Conciseness scorer is broken (unchanged).**

- Failing rows return `evaluator.text_quality`, `"Evaluation completed with score: 0.0"`, no reason.
- `Response Evaluation` passes 5/5 on every row, including the failing ones, and Conciseness fails
  the *shortest* replies (the one-line confirm-backs) while passing longer ones. It also splits
  near-identical escalation rows.
- Matches the known bug in `sf-skills.../agentforce-test`: conciseness returns 0; use coherence.
- **So: deselect Conciseness.** With Response Evaluation only, v1 is green.

## A voice run fills a Developer Edition org's file storage (2026-09-22)

Running the conversation suite with **"Text and voice"** made Studio store a WAV per conversation:
19 files, **199 MB**, against this org's **20 MB** file limit. Everything then failed with "Your
organization is using all its file storage, so you can't add new files" - including uploading a new
test-case CSV.

- Fix: `sfdx-project/scripts/purge_voice_recordings.apex` deletes `voice_conversation_%` files and
  empties the recycle bin (deleted files keep counting until it is). It leaves the two files the
  agent needs: the Phase 10 workflow diagram PNG and the Phase 13b damage-guide PDF.
- The storage figure is recalculated asynchronously, so `sf org list limits` can still show the old
  number for a minute after the purge.
- **Budget roughly 10 MB per voice conversation.** Use Text only for routine runs; keep voice for a
  small deliberate set (the 3 cases in `specs/Keyburn_Voice.md`) and purge straight afterwards.
  A 20-row suite over two personas would be ~400 MB and cannot complete.

## Candidate agent fixes (not applied; they would need a new version before the Wed 18:00 freeze)

- Finding 2: in `policy_faq`, state that questions about order stages, drafts or cancelling
  **always** call `ExplainOrderWorkflow`, because the article text doesn't hold the diagram's facts.
  **Reproduced a third time** in the Studio v1 run ("Can I still cancel an order after it has
  shipped?" and "What does it mean when an order is in Draft?" both returned empty Actual Actions),
  after CLI runs 01 and 01b. The two rows that did call it answered with the image-only facts.
- Finding 3: tighten the router's `go_to_escalation` description, or accept it and keep the
  assertion as a known wobble. It is harmless today only because the escalation subagent re-asks.
