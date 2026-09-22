# Order & Case Concierge

A voice-enabled **Agentforce Service Cloud** agent for a fictional retailer, Keyburn. Customers can
track orders, check or update support cases, ask about returns and policies, and reach a human, by
chat or by voice. Built for a Salesforce Forward Deployed Engineer Builders Panel.

## What it does

| Subagent | Handles |
|----------|---------|
| Order Status | Order status, plus live delivery tracking: remaining distance, drive time and a route map card (Google Routes + Static Maps) |
| Case Status | Case lookup, adding comments, listing open cases, opening a new support case |
| Return Eligibility | Whether an order can be returned, and why |
| Policy / FAQ | Answers grounded in Knowledge articles (Data Cloud + Agentforce Data Library); a multimodal prompt template reads the order-workflow diagram |
| Escalation | Creates a High-priority Case with a summary for a human agent |

**Design choices**

- **Identity is enforced in Apex, not the prompt.** Every lookup needs the customer's email plus
  an order or case number that belongs to them. Once verified, the session is locked to that
  email, and the Apex refuses any other.
- **Least privilege by construction.** All Apex runs `with sharing` and `WITH USER_MODE`, as a
  dedicated agent user with a read-mostly permission set.
- **Escalation can't be silently skipped.** It's driven by script variables, not left to the
  model's discretion.
- **Measured, not eyeballed.** A Python eval harness replays scripted multi-turn conversations over
  the Agent API. The pass rate went from 3/11 on the first run to 26/27 on the current agent.
  Every run is saved in `src/eval_reports/`.

## Repository layout

| Path | Contents |
|------|----------|
| `sfdx-project/` | Salesforce metadata: agent script (`aiAuthoringBundles/`), Apex actions and tests, objects, permission sets, Custom Lightning Type, LWC |
| `src/` | Eval harness (`run_eval.py`, `eval_cases.yaml`) and saved reports |
| `bedrock-voice/` | Experimental external voice page: Amazon Nova 2 Sonic handles speech, Agentforce stays the brain via the Agent API |
| `sample-data/` | CSVs for Accounts, Contacts, Orders, Cases, Knowledge |
| `docfiles/` | Build runbook, design notes, Knowledge article text |
| `CLAUDE.md`, `project-status.md` | Working context and the decision log |

## Setup

Requires the Salesforce CLI and an org with Agentforce, Data Cloud and Knowledge enabled.

1. Copy `secrets.env.example` to `secrets.env` and fill it in. It is git-ignored.
2. Replace the double-underscore placeholder tokens (org ID, My Domain, agent user) with your
   org's values,
   or fill in the `REDACT_*` lines and run `tools\setup_redaction.ps1` (see below).
3. Deploy in the order given in `src/SFCLI_Script.txt`. Every `sf` command runs from
   `sfdx-project/`.
4. Run the evals: `. .\load_secrets.ps1`, then `cd src; py run_eval.py eval_cases.yaml`.

**Why the placeholders:** org identifiers are kept out of this repo by a git clean/smudge filter
(`.gitattributes` + `tools/setup_redaction.ps1`). Committed files contain one token per value —
the `REDACT_*` key name wrapped in double underscores — while a configured working copy has the
real values and deploys as-is.

## Status

Built in a Salesforce developer org as a demo; not production software. Keyburn, its customers and
all sample data are fictional.
