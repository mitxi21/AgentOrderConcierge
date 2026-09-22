# Keyburn voice test set (Phase 15, step 3)

**Automated voice testing lives in Agentforce Studio → Tests**, not in the CLI (which is text only)
and not in the Builder preview. In the New Test Suite wizard, the **Data** step has
*Select Conversation Output*: choose **Text and voice**. The simulated callers then speak, and each
conversation is scored like any other suite.

Keep this suite to **3 cases**. Each voice conversation is stored as a WAV of roughly 10 MB, and this
Developer Edition org has only **20 MB of file storage** in total, so a larger voice run fills the org
and blocks every upload afterwards (see `docfiles/testing_center_run01.md`). Run
`sf apex run --file scripts/purge_voice_recordings.apex -o devorg` immediately after, and check
`sf org list limits` shows FileStorageMB back at 20.

**Scorer selection is fixed when the suite is created.** On the wizard's **Scorers** step, leave the
two **Assertions** (Subagent Evaluation, Actions Evaluation) **unticked** and tick only **Task
Resolution**: a conversation suite never captures subagent or action data, so an enabled assertion is
guaranteed red. The "Select Scorers..." button on an existing suite only edits the custom scorers
(Quality / Deflection / Abandonment), so a suite created with assertions on cannot be fixed - make a
new one. `Keyburn_Voice_upload_noassert.csv` is the same three cases with the expectation columns
left empty, and with each conversation's resolved ending described so Task Resolution judges the
escalation fairly.

Settings: Text and voice, **Default persona** (Accent persona is the interesting one for a second
run, but it doubles the recordings), live actions, and the same scorers as the other suites —
Response, Subagent, Action, Coherence, Latency; Completeness and Conciseness **off**.

| # | Case | Conversation description | Pass when |
|---|---|---|---|
| V1 | Happy tracking | User asks where order 1042 is, gives the email jane.doe@example.com when asked, and confirms when the agent reads both back | One combined confirm-back, then distance and minutes by car. No URL read aloud, no second confirmation. |
| V2 | Misheard digit | User asks for the status of order 1024 with the email jane.doe@example.com, then corrects the number to 1042 when the agent reads it back, and confirms | The agent reads 1024 back, accepts the correction, confirms 1042 once, then gives the shipped status. It never looks up 1024 as if confirmed. |
| V3 | Escalation | User demands a refund for their last order right now | No refund promised; a team member will follow up within one business day and a case number is spoken. |

Notes:

- V2 replaces the old "O-1O42" story: the voice layer turns a spoken "O" into 0, so a letter
  mishearing can silently match. A digit mishearing is the reliable version.
- V3 creates a real High-priority Case (jane.doe is fine; never maria.garcia).
- Screenshot the results for the deck — this is the evidence for the panel's "voice testing" ask.
- **Separate from this:** the manual voice rehearsal through the Builder voice preview or the chat's
  mic button, which is demo prep (Phase 18), and the Nova call page (Phase 11).
- Phase 16 adds a fourth case once the OTP gate lands: the caller speaks the six-digit code.
