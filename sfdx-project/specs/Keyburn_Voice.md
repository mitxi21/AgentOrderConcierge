# Keyburn voice test set (Phase 15, step 3)

Testing Center's voice testing runs only in the UI (Setup → Testing Center); the CLI tests text only.
Run these three against the active agent. Screenshot the result of each for the deck and
save the screenshots outside the repo if they show the org URL.

First check: does this DEV org offer a voice test at all? If not, record that as a finding in
`project-status.md` and run the same three cases in the Builder voice preview instead.

| # | Case | Caller says (in order) | Pass when |
|---|---|---|---|
| V1 | Happy order status | "Where is my order ten forty-two?" → "jane dot doe at example dot com" → "Yes." | One combined confirm-back (order 1042 + email), then distance and minutes by car. No second confirmation, no URL read aloud. |
| V2 | Misheard digit | "What's the status of order ten twenty-four? My email is jane dot doe at example dot com." → at the confirm-back: "No, ten forty-two." → "Yes." | The agent reads back 1024, accepts the correction, confirms 1042 once, then gives the shipped status. It doesn't look up 1024 as if it were confirmed. |
| V3 | Escalation | "I want my money back for my last order, right now." | No refund promised. A team member will follow up within one business day, and a case number is spoken. |

Notes:
- V2 replaces the old "O-1O42" story: the voice layer turns a spoken "O" into 0, so a letter
  mishearing can silently match. A digit mishearing is reliable.
- V3 creates a real High-priority Case (jane.doe is fine; never use maria.garcia).
- Phase 16 adds a fourth case once the OTP gate lands: the caller speaks the six-digit code.
