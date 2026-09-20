# AgentFDE — Order & Case Concierge

Voice-enabled Agentforce Service Cloud agent built in a Salesforce **DEV org**, for a Forward
Deployed Engineer Builders Panel at Salesforce. **Demo: 2026-09-23.**

Salesforce agent name: "Keyburn Customer Service" (dev name `Keyburn_Customer_Service`),
presented as "Order & Case Concierge". Fictional company: Keyburn.

**Git repo, published publicly on GitHub** (since 2026-09-19; moved out of OneDrive). Commit
before risky edits so there is history to fall back on.

**Org identifiers are redacted by a git filter.** `.gitattributes` routes text files through a
`redact` clean/smudge filter: the working copy keeps the real org ID, My Domain, agent username,
agent user ID and AWS account ID (deployable), and commits contain `__ORG_ID_15__`,
`__MY_DOMAIN__` etc. instead. Values come from the `REDACT_*` lines in `secrets.env`, and
`tools/setup_redaction.ps1` writes the filter into `.git/config` (re-run it after a fresh clone or a
new value). Before any push, check nothing leaked: `git grep -n -e <value>` on the committed tree
must be empty. A new identifier that must stay private needs a new `REDACT_*` line, not a
hand-edited placeholder.

**Secrets never go in the repo.** All keys and consumer secrets live in `secrets.env` at the
repo root, which `.gitignore` excludes; `secrets.env.example` is the committed template, and
`. .\load_secrets.ps1` loads them into a PowerShell session. Never inline a key in a script, a
doc, or a command; read it from `$env:`. Keys used inside the org (the Google Maps key for the
Apex callout) live in an External Credential / custom metadata record created in the org, with
only a placeholder in the repo. Rotate the Salesforce consumer secret and the Google key after
the demo — both passed through a chat transcript.

**This file is the single source of context.** Open Claude Code / VSCode at this folder
(`AgentFDE/`), not at `sfdx-project/`. There is deliberately no second `CLAUDE.md` anywhere in
the tree — if one appears under `sfdx-project/`, delete it rather than maintaining two.

## Repository layout

| Path | What it holds |
|------|---------------|
| `BUILDERS_PANEL_BRIEF.md` | Panel format (45 min) + evaluation criteria |
| `project-status.md` | Decision + status log. Append to it when a decision is made or a phase completes |
| `docfiles/Agentforce_FDE_Panel_Prep.md` | Agent design + deck narrative / talk track. Git-ignored (local only) |
| `docfiles/DEMO_GUIDE.md` | Phase 12: demo script, pre-flight checklists, failure recovery, design-decision crib sheet (the deck itself is a claude.ai Slides artifact) |
| `docfiles/BUILD_RUNBOOK.md` | Phased build plan (phases 0–12; 9–11 features added 2026-09-17, 12 = demo + deck, always last) |
| `docfiles/agent_builder_topics.md` | Paste-ready instructions per topic/subagent + eval→topic mapping |
| `docfiles/README_eval_harness.md` | Agent API / External Client App setup for the eval harness |
| `docfiles/knowledge_articles.md` | Source text of the 5 Policy/FAQ Knowledge articles |
| `docfiles/Builders Panel .pdf` | Original panel invitation / brief from Salesforce |
| `secrets.env` (git-ignored) / `secrets.env.example` / `load_secrets.ps1` | All API keys and secrets, the committed template, and the session loader |
| `bedrock-voice/` | Phase 11 external call page: Nova 2 Sonic = speech only, every caller turn relayed to Agentforce over the Agent API (`server.py`, `nova_session.py`, `relay.py`, `static/index.html`; `ws_test.py` = headless preflight). **Python 3.12** (`py -3.12`), not 3.8 |
| `web-chat-test/index.html` | Loads the **deployed** Embedded Messaging client (not the Builder preview) to test whether the map card renders; seed for the Phase 11 page |
| `src/eval_cases.yaml` | Scripted multi-turn eval conversations |
| `src/run_eval.py`, `src/agent_client.py` | Python eval harness over the Agent API |
| `src/SFCLI_Script.txt` | Ordered CLI steps to stand the project up in a fresh org |
| `sample-data/*.csv` | Accounts, Contacts, Orders, Cases, Knowledge articles for Data Loader import |
| `sfdx-project/` | Deployable metadata (Apex, objects, permission sets) + anonymous-Apex scripts |
| `sf-skills-1.55.0/` | Vendored third-party Salesforce skills library — not project code; exclude from searches. Git-ignored (local only) |
| `tools/setup_redaction.ps1`, `.gitattributes` | Git filter that keeps org identifiers out of the public repo (see top of this file) |

`sfdx-project/` stays a nested subfolder rather than being hoisted to the repo root: the only
thing that buys is dropping a `cd`, and it would cost manual file moves, `.sf` source-tracking
churn, and a rewrite of every command in this file plus `src/SFCLI_Script.txt`. Revisit after
the demo if it still seems worth it. Consequence to remember: **this folder is the workspace
root, but `sfdx-project/` is the CLI's project root** — `sf` walks *up* from the current
directory looking for `sfdx-project.json`, so every `sf` command must run from inside
`sfdx-project/`.

### Stale / reference-only (don't edit or deploy from these)

- `src/Order_Case_Concierge_skeleton.agent` — early hand-written Agent Script draft
  (`topic_selector`, `[Company]`, dev name `Order_Case_Concierge`). Its guessed syntax is wrong;
  the real agent script is now in source control (see Architecture below).
- `docfiles/BUILD_RUNBOOK.md` references `CASE-2291` and Flow-based actions; the build uses Apex
  actions, and cases are auto-numbered (see eval data notes). The runbook is still the
  authority on *phase sequencing*, just not on those details.

## Architecture (built)

- Agentforce Agent Builder, originally built via the Builder's assistant/wizard, with a dedicated
  running user. **Since 2026-09-17 the agent script is in source control and edited locally**:
  `sfdx-project/force-app/main/default/aiAuthoringBundles/Keyburn_Customer_Service/Keyburn_Customer_Service.agent`
  is the working draft and the file to edit. **Active version: v38** = v33 (the Phase 9 demo
  candidate) + Phase 10 (Draft status, workflow diagram read by a multimodal prompt template). It
  keeps normal identifiers, the map card in the deployed chat (**first tracked order per conversation only**;
  see `project-status.md`), and an **identity lock enforced in Apex**. Fallback: v33. Every lookup action has a
  `lockedEmail` input bound to `@variables.verified_email`, and `OCC_CaseLookupUtil.violatesLock`
  refuses any other email. Each also returns `verifiedEmail` + `identityLocked`, which the script
  stores. New lookup actions must follow the same pattern.
  **After every agent publish, republish the Embedded Service deployment** `Agentforce_Service_Agent`,
  or cards are sent but not drawn.
  **One map card per conversation is a platform limit — accepted, don't re-investigate.** Only an
  action the *model* invokes and displays via `show_command` produces a card. A deterministic `run`
  never does (v36), and the model won't display a second one. A post-action `run` is also skipped
  whenever the same action's `set`s flip an instruction condition (v34/v35). `OCC_ShowDeliveryMap`
  is the unused leftover of that experiment; delete it after the demo. Apex-only
  changes reach the active version without a republish. Fallbacks: v4 (pre-Phase-9), v1 (original
  build). (The earlier "only v16 renders the card" belief was wrong; see `project-status.md`.)
  - **No `after_reasoning` escalation safety net** (removed 2026-09-18): it fired on every visit to
    the escalation subagent, including the ones that now correctly just re-ask for a mis-heard
    detail, which created junk High-priority Cases. A partial answer is not a refusal.
  - Escalation is structural, not prompt-dependent: `CreateEscalationCase` sets
    `@variables.escalation_case_number`, instructions branch on it, and an `after_reasoning`
    safety net logs a Case with reason `unlogged_escalation` if the model skipped the action. Keep
    this pattern for any action that must not be silently skipped. Syntax reference:
    `sf-skills-1.55.0/skills/agentforce-generate/references/agent-script-core-language.md`.
  - The router re-classifies **every turn** from scratch, not only the first. A follow-up line
    like "I don't remember my order number" is routed on its own, so escalation cues must live in
    router descriptions, not only in a subagent's instructions.
  - `aiAuthoringBundles/Keyburn_Customer_Service_1/` = the v1 snapshot (its meta has
    `<target>Keyburn_Customer_Service.v1</target>`); `genAiPlannerBundles/*_vN/` are compiled
    output from publish — don't hand-edit either.
  - Edit loop: edit draft → `sf agent validate authoring-bundle` → `sf agent publish
    authoring-bundle` (creates a new **inactive** version and retrieves it) → `sf agent activate
    --version N` → re-run evals. Rollback = activate the previous version number.
  - Publishing does not activate. A saved Agent Builder edit isn't live until it's published
    **and** activated. The 09-15 confirm-back edit sat unpublished for two days because of this.
  - If you edit in Agent Builder instead, retrieve right after or the local draft goes stale.
    `AiAuthoringBundle` / `GenAiPlannerBundle` don't exist at the project's API 61.0, so plain
    `sf project retrieve start --metadata ...` silently skips them. Retrieve with a
    `package.xml` whose `<version>` is 67.0 via `--manifest`.
  - `docfiles/agent_builder_topics.md` is the original design text and is **not** in sync. The
    `.agent` file wins.
- 5 subagents behind `agent_router`: Order Status, Case Status, Return Eligibility, Policy/FAQ,
  Escalation — plus `off_topic` and `ambiguous_question` handlers.
  Agent Script: `start_agent agent_router:` → `subagent <name>:` blocks with
  `reasoning:` / `actions:`; routing via `@utils.transition to @subagent.X`; action invocation
  `ActionName: @actions.ActionName with param = ...`; targets are `apex://ClassName` or
  `standardInvocableAction://streamKnowledgeSearch`. Router model is
  `model://sfdc_ai__DefaultEinsteinHyperClassifier`. The agent user sits under `config:` →
  `access:` → `default_agent_user:`.
- Custom object `Order__c` (deliberately not standard Order) + `Case.Escalation_Summary__c`
  (Long Text). `Order_Number__c` is a unique External ID (e.g. `ORD-1042`).
- **Order tracking (Phase 9):** `Order__c.Current_Location__c` (Geolocation) +
  `Location_Updated__c`; delivery address = the Contact's `Mailing*` fields with explicit
  coordinates. Warehouse origin and the Google Maps key live in `Keyburn_Setting__mdt` (record
  `Default`). Google **Routes API** (not the legacy Directions API) with origin = warehouse,
  `intermediates` = parcel, destination = customer: the whole polyline draws the map, and
  **`legs[last]`** is the distance/time still to drive. Both *Routes API* and *Maps Static API*
  must be enabled **and** allowed in the key's API restrictions.
- Data Cloud + Agentforce Data Library over 5 Knowledge articles (record type `Policy_FAQ`,
  body field `Article_Body__c`). Policy/FAQ uses the **native "Answer Question with Knowledge"
  standard action** (`standardInvocableAction://streamKnowledgeSearch`) grounded on the Data
  Library. `OCC_PolicyFAQLookup` (custom Apex/SOSL) exists as a deployed-but-unused fallback.
- Voice: native in-Builder voice preview (Enhanced Chat v2) works. Production telephony would
  need a paid Voice add-on — out of scope. The fix that made voice work was found by following
  an external guide and was never fully root-caused, so a voice regression means starting
  diagnosis from scratch.

### Apex actions (`sfdx-project/force-app/main/default/classes/`)

| Class | Subagent | Does |
|-------|----------|------|
| `OCC_GetOrderStatus` | Order Status | email + order # → status, item, dates |
| `OCC_CheckReturnEligibility` | Return Eligibility | email + order # → eligible flag + one-line reason (reads `Return_Eligible__c`) |
| `OCC_GetCaseStatus` | Case Status | email + case # → status, subject, priority, `openRelatedCaseCount` (repeat-complaint signal) |
| `OCC_UpdateCase` | Case Status | appends a published `CaseComment`; never changes status/priority/owner |
| `OCC_CreateEscalationCase` | Escalation | creates High-priority Case with `Escalation_Summary__c`; reason codes `financial_request`, `unverifiable_identity`, `frustration`, `out_of_scope` (+ `unlogged_escalation` from the script's safety net) |
| `OCC_GetOrderDeliveryInfo` | Order Status | email + order # → remaining distance, driving time, position age, static-map URL/`<img>` (Google Routes + Static Maps; callout) |
| `OCC_DeliveryMap` | shared | route + static-map + haversine fallback + "9 minutes ago"; used by the action, the record page and the REST endpoint |
| `OCC_OrderMapController` | record page | `occOrderDeliveryMap` LWC on `Order__c`; record access governs, so no email check |
| `OCC_OrderMapRest` | Phase 11 page | `GET /services/apexrest/keyburn/ordermap?email=&orderNumber=`, same verification as the agent action |
| `OCC_GetOrderMapLink` | (unused) | standalone rich-link action; the model skipped it, so the card moved into `OCC_GetOrderDeliveryInfo`. Pinned by agent v11 — delete with v11 after the demo |
| `OCC_ListOpenCases` | Case Status | email + order-or-case # → open case count + up to 3 "case #, subject" |
| `OCC_CreateSupportCase` | Case Status | email + order-or-case # + issue → Medium-priority Case (Subject/Priority/ContactId only) |
| `OCC_ExplainOrderWorkflow` | Policy/FAQ | question → finds the PNG File on Knowledge article `how-an-order-moves-through-keyburn` → Flex prompt template `OCC_Order_Workflow_Diagram` (GPT-4o reads the image) → `answered` + spoken answer; `NOT_IN_DIAGRAM` → `answered=false` |
| `OCC_PolicyFAQLookup` | (unused fallback) | stopword-stripped SOSL over published `Knowledge__kav` |
| `OCC_CaseLookupUtil` | shared | `normalize()` for spoken order/case numbers; `verifiedContactId()` = email + an identifier that belongs to that Contact |

Every action has a matching `*Test` class except `OCC_CaseLookupUtil` (covered indirectly).

**Pattern all actions follow — copy it for new actions:**

- `public with sharing` class with inner `Request` / `Response` classes of `@InvocableVariable`s;
  a single `@InvocableMethod(... category='Order Case Concierge')` looping over requests into a
  private per-request helper.
- Identity verification is structural: look up `Contact` by exact `Email`, then query child
  records by `Contact__c` / `ContactId`, then match the identifier in Apex via
  `OCC_CaseLookupUtil.normalize()` on both sides. An email/number mismatch is just "not found".
- Always return a `found`/`success` flag plus a `message` that is safe to read to the caller
  verbatim — never return null for the agent to interpret.
- Whole body in `try/catch`: log with `System.debug(LoggingLevel.ERROR, ...)`, return a clean
  generic message.

`OCC_CaseLookupUtil`'s name is now narrower than its job (it serves order lookups too). Renaming
it needs a destructive delete of the old class, so it was deliberately deferred until after the
demo.

### Permission sets

- `Order_Case_Concierge_Agent` — agent running user. Read-only on `Order__c`, `Contact`,
  `Knowledge__kav`; create/edit on `Case`; create on `CaseComment`; no delete, no view/modify-all.
- `OrderCaseConcierge_DataAdmin` — same `classAccesses`, but full CRUD + view/modify-all, for
  the admin doing data loads.

Deploying a permission set does **not** assign it. `PermissionSetAssignment` is a data
operation — that's what `scripts/assign_agent_permset.apex` is for.

Agent running user: `__AGENT_USERNAME__`
(Id `__AGENT_USER_ID__`, license *Einstein Agent*, profile *Einstein Agent User*).

## Standing constraints — do not violate

1. **Do not change Organization-Wide Defaults.** They were reverted deliberately. If a
   visibility problem appears, fix it via record linkage or a targeted Sharing Rule scoped by
   Public Group — never OWD. Note `Order__c.object-meta.xml` carries `sharingModel`; don't edit
   that value, and don't retrieve/deploy it blindly if the org's setting has drifted.
2. **Every Contact must be linked to an Account.** A Contact with no AccountId is always
   private regardless of OWD; this was the root cause of the "not found" failures. The chosen
   model is **one dedicated Account per Contact**, named `"FirstName LastName"` — so
   `sample-data/accounts_sample.csv` must be imported (Insert into Account) *before*
   `scripts/link_contacts_to_account.apex` is run, since the script matches Contacts to existing
   Accounts by name. `sample-data/contacts_sample.csv` has no Account column, so the script must
   be re-run after any Contact reload. It is idempotent.
3. **All SOQL/DML in Apex uses `WITH USER_MODE` / `as user`**, and classes are
   `public with sharing`. This is a structural least-privilege guarantee and part of the demo
   narrative — do not relax it for convenience.
4. **Any new Apex class needs a `<classAccesses>` entry in both permission sets.** Agentforce
   invocation is blocked at the platform level before any try/catch runs without it. New
   fields/objects also need explicit permissions in the agent permset (least-privilege).
5. **Do not add explicit `<fieldPermissions>` for platform-required fields**
   (`Knowledge__kav.Title`, `Case.CaseNumber`, `Case.Status`, `Order__c.Order_Number__c`) —
   deploys fail. The same applies to **every `Contact.Mailing*` component** (Street, City,
   PostalCode, Latitude, Longitude): "Invalid field permission field name". Object read grants them. Such fields are implicitly readable once object read exists; delete the entry
   rather than trying to satisfy it. `PermissionSet` also rejects `<default>` on
   `<recordTypeVisibilities>` (only `Profile` supports it).
6. **Customer-facing failure messages stay clean.** No `DEBUG: ` + exception text in responses;
   those lines were temporary and have been reverted.
7. Spoken order/case numbers are normalized in `OCC_CaseLookupUtil` (strip non-digits, then
   leading zeros — "1026" → matches `00001026`, "ORD-1042" and "1042" both match `ORD-1042`).
   Keep this path when adding lookups.

## Debugging notes worth not rediscovering

**`WITH USER_MODE` fails in two different ways, and only one of them is visible.** An FLS/CRUD
violation **throws** (`System.QueryException`). A **sharing** restriction **does not throw** — it
silently drops the record from the result set, which is indistinguishable from "no such data"
from the outside. When a query returns empty but the record demonstrably exists, suspect sharing
before FLS. This distinction was the crux of the longest debugging chain in the build.

**`UserRecordAccess` is the definitive answer to "can this user actually see this record"** —
it returns real access after CRUD, FLS *and* sharing:

```sql
SELECT RecordId, HasReadAccess, MaxAccessLevel FROM UserRecordAccess
WHERE UserId = '__AGENT_USER_ID__' AND RecordId IN ('003...','500...')
```

`HasReadAccess=false, MaxAccessLevel=None` on a record that exists = a sharing gap. Reach for
this before theorizing.

**When Debug Logs are empty**, a fast substitute is to temporarily return the raw exception in
the customer-facing message (`resp.message = 'DEBUG: ' + e.getMessage();`) and read it straight
out of the agent transcript. Revert it immediately after — see constraint 6.

## Commands

Salesforce CLI, org alias `devorg`. **Run from `sfdx-project/`** (source format, API 61.0).

```powershell
sf org login web --alias devorg

# Deploy everything, or by type (fresh-org order: CustomObject, Layout, Profile, Settings,
# then data import, then ApexClass, PermissionSet — see src/SFCLI_Script.txt)
sf project deploy start --target-org devorg
sf project deploy start --target-org devorg --metadata ApexClass

# Retrieve after changes made in the org UI
sf project retrieve start --target-org devorg

# Agent script (see Architecture): validate → publish (new inactive version) → activate
sf agent validate authoring-bundle --api-name Keyburn_Customer_Service --target-org devorg
sf agent publish authoring-bundle --api-name Keyburn_Customer_Service --target-org devorg
sf agent activate --api-name Keyburn_Customer_Service --version 6 --target-org devorg   # rollback: --version 4 (pre-Phase-9)

# Trace a conversation against the active agent (real actions): which subagent, which actions
sf agent preview start --api-name Keyburn_Customer_Service --target-org devorg --json   # -> sessionId
sf agent preview send --api-name Keyburn_Customer_Service --session-id <ID> --utterance "..." --target-org devorg
sf agent preview end --api-name Keyburn_Customer_Service --session-id <ID> --target-org devorg
sf agent trace read --session-id <ID> --turn 1 --format detail --dimension routing   # or: actions, errors

# Apex tests — all, or one class
sf apex run test --target-org devorg --wait 10
sf apex run test --target-org devorg --class-names OCC_GetOrderStatusTest --result-format human --wait 10

# Anonymous-Apex scripts
sf apex run --file scripts/link_contacts_to_account.apex --target-org devorg   # after any data load
sf apex run --file scripts/publish_knowledge_articles.apex --target-org devorg # publishes Policy_FAQ drafts
sf apex run --file scripts/test_actions.apex --target-org devorg               # smoke-test all 5 actions
sf apex run --file scripts/assign_agent_permset.apex --target-org devorg       # edit AGENT_USERNAME first
sf apex run --file scripts/set_demo_geodata.apex --target-org devorg           # Phase 9 addresses + parcel positions
sf apex run --file scripts/set_keyburn_settings.apex --target-org devorg       # warehouse + Google key (generate from .example, see below)

# Phase 10: workflow diagram (regenerate PNG from the repo root) and its Knowledge article
powershell -File ..\docfiles\make_order_workflow_diagram.ps1
powershell -File scripts\create_order_workflow_article.ps1   # article + File + agent-user share + publish
sf project deploy start --target-org devorg --source-dir force-app/main/default/genAiPromptTemplates --api-version 67.0
```

`test_actions.apex` runs as admin, so it proves business logic only — **not** FLS/sharing.
Verify permission behavior as the agent user or through a real agent transcript.

**Custom metadata records can't be deployed in this org** — the *type* deploys, but a record fails
with `UNKNOWN_EXCEPTION` and no component error (not a permissions problem: the Apex Metadata API
creates the same record fine). So `Keyburn_Setting.Default` is created by
`scripts/set_keyburn_settings.apex`, which is git-ignored and generated from its `.example` with
the key from `secrets.env` — that's also why the key never lands in the repo. Two related traps:
`.forceignore` must exclude `**/*.example` or the CLI parses templates as metadata and fails the
same opaque way, and Apex script files must be written **without a BOM**
(`[IO.File]::WriteAllText(..., UTF8Encoding($false))`, never `Set-Content -Encoding utf8`).

### Eval harness (Phase 8)

Agent API is live via External Client App `Keyburn_ECA` (client credentials, Run As = admin,
JWT access tokens). The agent ID is the `BotDefinition` Id (`0Xx`), not a `BotVersion` Id
(`0X9`). Client ID/secret live only in env vars — never commit them. Use `bypassUser: true`
(the harness default): actions then run as the agent user; `false` runs them as the ECA's Run As
user (admin), bypassing the least-privilege permset.

ECA gotchas: an empty-body **404** on session start means the token isn't a JWT (`eyJ...`) —
enable *Issue JWT-based access tokens for named users*. `no client credentials user enabled` =
no Run As user; `user is not admin approved` = Run As user lacks the ECA's policy permission set.

```powershell
pip install requests pyyaml
. .\load_secrets.ps1          # from the repo root; loads secrets.env into the session
cd src; py -3.8 run_eval.py eval_cases.yaml
```

- Each case = fresh session, turns sent in order; only the **last** agent reply (`Inform`
  messages) is scored with case-insensitive `contains_any` / `must_not_contain`.
- Writes `eval_report.json` to the current directory, overwriting it — copy each run you want to
  keep into `src/eval_reports/` as `eval_report_runNN_<label>.json` (before/after runs are demo
  material). Runs so far: 01 baseline 3/11 → 02 test fixes 6/11 → 03 agent v2 10/11 →
  04 agent v3 12/15 (original 11: 10/11; 4 `open_cases` cases added) → 05 stricter tests 13/15
  → 06 agent v4 14/15 → 06b repeat 14/15 (same single failure: test wording) → 07 agent v5 with
  3 `tracking` cases 18/18 → 08 stricter map-claim tests 16/18 → 09 agent v6 18/18 → 09b
  repeat 18/18.
- Nondeterminism is real (a skipped action was ~1 in 5 in traces). Repeat a run before calling
  something fixed, and trace failures with `sf agent preview` + `sf agent trace read` rather than
  guessing from the reply text.
- **Trace a reported failure before editing the agent.** Several "agent defects" turned out to be
  test defects: as the agent improves it needs fewer turns, so a scripted turn changes meaning
  (a trailing "Yes." starts meaning "yes, something else") and the suite mis-scores a correct
  answer. Assert the defect's *signature* (e.g. `"I have your email as"`), not a generic pattern
  like "no questions in the reply".
- **A pass is not proof an escalation happened.** Run 04's `edge_out_of_scope_request` passed
  while no Case was created (the agent only promised one). For anything that should write data,
  check the org (`SELECT CaseNumber, Subject, CreatedBy.Username FROM Case WHERE CreatedDate =
  TODAY`), or make the test require the spoken case number.
- Open-cases eval data: `maria.garcia@example.com` must keep **no open cases**
  (`case_list_open_none_offers_to_open`). Never create cases for her. New support cases from the
  eval land on `alex.chen@example.com`.
- `run_eval.py` scores the final turn's text and saves a per-turn `transcript`. Add
  `match_scope: conversation` to a case whose answer may land on an earlier turn — the agent
  chooses how many turns it needs, so a scripted confirm turn can end up drawing only a closing
  pleasantry. That flag widens `contains_*` to the whole conversation and `must_not_contain` with
  it; leave it off when the assertion is about the *final* reply specifically.
- On this machine `python` is the Microsoft Store stub; use `py -3.8 run_eval.py eval_cases.yaml`.
- `run_eval.py` only scores `Inform` messages. An **empty `final_reply`** usually means the agent
  sent a non-text message (e.g. `{"type": "Escalate", "targets": []}`, a platform handoff) —
  check the raw response before assuming a harness or network failure.
- Eval data depends on the sample data: `jane.doe@example.com` / `ORD-1042`,
  `john.smith@example.com` / `ORD-2077`. `happy_case_status` uses case `1026`, which is an
  **org-generated CaseNumber** — update it in `eval_cases.yaml` after reloading Cases.
- `edge_ambiguous_order_number` ("O-1O42") intentionally fails lookup; it expects confirm-back.
- Fix loop: failing case → edit the draft `.agent` file → validate → publish → activate →
  re-run → diff reports. Label each run as either a test fix or an agent fix, and never mix the two
  in one run, or the pass-rate climb overstates the agent's improvement.
- Escalation cases create real High-priority Cases in the org (created by the agent user) on
  every run. That's expected; clean them up before the demo if the case list will be shown.
- **Expect a bad first run.** 50–70% pass is normal and is *good material* — save that first
  report. A climbing pass rate across saved runs is the Reliability & Evaluation evidence; a
  suite that passes first time mostly signals the tests were too easy.

## Remaining work

Phase 8 is **closed** (14/15 on agent v4, stable). **Agent v4 is the frozen demo-safe fallback.**
Phases 9–12 are planned in detail, with spikes and cut-offs, in `docfiles/BUILD_RUNBOOK.md`:

- **The Builder preview is not the deployed chat client.** Rich UI (the `OrderDeliveryMap` Custom
  Lightning Type) renders only in the deployed Embedded Messaging client, via the type's
  `enhancedWebChat` renderer — **never in the Builder preview**. Test visual changes on the
  `KeyburnChatTest` Visualforce page (Setup → Visualforce Pages → Preview). That path needed CSP
  trusted sites, CORS origins, guest access on the deployment and Omni-Channel routing to the agent
  — see `project-status.md` 2026-09-18.
- **Embedded Messaging needs the 15-character org ID** in `embeddedservice_bootstrap.init()`
  (`__ORG_ID_15__`). With the 18-character ID the chat loads and messages send, but every live
  event poll returns 400 — *"OrgId in the header and token must match"* — so replies only appear
  after a page refresh.
- **What a Custom Lightning Type card needs in the deployed chat** (all proven 2026-09-18, v30;
  pattern = Salesforce's `trailheadapps/agent-script-recipes` CustomLightningTypes recipe):
  1. The type is **Apex-backed**: `schema.json` = `"lightning:type": "@apexClassType/c__Class$Inner"`
     (`OrderDeliveryMapCard` → `OCC_GetOrderDeliveryInfo$DeliveryMapCard`). A standalone JSON-schema
     type is silently ignored, and an existing type can't be converted (breaking change), so make a
     new one.
  2. The renderer LWC has `<targetConfig targets="lightning__AgentforceOutput"><sourceType
     name="c__Type"/>`.
  3. The instruction explicitly says to **call the `show_command` tool** to display that output.
     Otherwise the model decides each turn whether to display, and mostly doesn't.
  4. It's the **only displayable output** of the action.
  5. Every URL in it is on a **CSP Trusted Site**. Otherwise it arrives as `URL_Redacted`, which
     fails a `urlType` field.
  6. **Republish the Embedded Service deployment** after adding or changing a type.

  To debug, read what the client receives: DevTools → Network → the conversation `entries`
  response (`formatType: ExperienceType` = card sent). The admin Connect API hides that payload.
  Captures contain the Google key, so save them outside the repo.
- **Never rewrite the `.agent` file with PowerShell `Get-Content` / `WriteAllLines`.** Windows
  PowerShell 5.1 reads BOM-less UTF-8 as Windows-1252, so every em-dash and curly quote comes back
  double-encoded (`—` → `â€”`) once written as UTF-8. Use the Edit tool, or
  `[IO.File]::ReadAllText(path, UTF8Encoding($false))` for both read and write. Happened once
  (2026-09-18) and was repaired before publishing.
- **Don't draw conclusions from a behaviour the model chooses per turn.** "Only v16 renders the
  card" (v23–v27 compared against it, including byte-identical republishes) came from a random
  `show_command` choice. Capture the payload before comparing versions.
- **When something that worked stops working, list everything that changed since — including
  environment and test-harness fixes — and revert one at a time** before editing the component you
  suspect. Four agent versions were spent on the map before the real cause (an unrelated org-ID fix
  had changed how the client receives messages) was found by reverting.
- **Write identifiers normally** ("order 1042", "jane.doe@example.com"). The platform's voice layer
  tags and pronounces them itself; instructions that spell them out ("one zero four two", "jane
  dot doe") leak into text chat verbatim.
- Declare only the Custom Lightning Type output for the map (`deliveryMap`). A rich link output
  also declared on V2 degrades to text and dumps raw URLs and `URL_Redacted` under the card. The
  old JSON-schema type `OrderDeliveryMap` is unused; delete it after the demo.
- **The Google key is sent to every chat user's browser** inside the static-map URL. When rotating
  after the demo, split it into a server-only key (Routes API) and a referrer-restricted key
  (Maps Static API).
- **The double-confirmation defect only reproduces in voice**, never over the Agent API or in
  scripted preview traces. Suspect the voice layer's own entity confirmation, not the agent script;
  compare voice against preview *text* mode before editing instructions again.
- **Phase 9 — done (agent v16, 21/21).** Spoken tracking works. Map surfaces: the
  `occOrderDeliveryMap` LWC on the `Order__c` record page (**working**, image links to Google Maps
  directions) and `OCC_OrderMapRest` for the Phase 11 page, **and the deployed chat** (v30, via the
  `OrderDeliveryMapCard` Custom Lightning Type; see the checklist above). Rich *link* cards still
  render only on Enhanced Chat V1 / Apple Messages / LINE. The agent never claims a map in words.
- **Phase 10 — done (agent v38, run 27 26/27).** `Draft` status (ORD-1100, jane.doe) and the
  order-workflow diagram read at question time by a multimodal Flex prompt template. The image is
  the source of truth, and two facts exist only in it (draft kept 30 days; no cancelling once
  shipped), which the `workflow_*` evals assert. Details and root causes: `project-status.md`
  2026-09-18. Knowledge for the build:
  - A Flex template takes an image as a **File input** (`SOBJECT://ContentDocument`, passed as
    `{"id": "069..."}`). A rich-text image in `Article_Body__c` is not a File and can't be the input.
  - `GenAiPromptTemplate` deploys need `--api-version 67.0`, and `versionIdentifier` must be
    platform-generated: deploy without it, retrieve, then set `activeVersionIdentifier` and
    redeploy. Published versions are immutable, so a content change is a new version.
  - **The agent user does not inherit read on a File through the Knowledge article it's attached
    to.** The template then fails with `[Provide:{LATEST PUBLISHED VERSION ID}]`. The fix is a
    read-only `ContentDocumentLink` from that File to the agent user, which
    `scripts/create_order_workflow_article.ps1` creates.
  - Knowledge `UrlName` uniqueness is checked against real org articles even inside Apex tests.
- **The Agent API returns text only** — every message has `"result": []`, no structured action
  output. A client that needs to *show* something (a map, a record) must fetch it itself, e.g. via
  `OCC_OrderMapRest`. This shapes Phase 11's page design.
- **Rich link card contract** (Salesforce Help, "Adaptive Response Format: Rich Link Response"):
  an action returns `List<ItemDetail>` with the fixed fields `linkURL`, `linkTitle`,
  `linkImageURL`, `linkImageMimeType`, `descriptionText`; Service Agent only; one image + one URL;
  PNG/JPEG; set the MIME type explicitly when the URL has no file extension. In Agent Script the
  output is `list[object]` with `complex_data_type_name: "@apexClassType/c__Class$Inner"` (that
  exact shape — the publish error names it) and **`is_displayable: True` only**. Do **not** also set
  `filter_from_agent: True`: it is the same flag as `is_displayable: False`, so the two together
  mark the card hidden and nothing renders. Put the card on an action the agent already calls —
  an optional second action gets skipped by the model.
- **Phase 11 — done (2026-09-20).** External call page using Amazon Bedrock Nova 2
  Sonic. Agentforce stays the brain; Nova only handles speech and relays turns through the Agent
  API. AWS account `__AWS_ACCOUNT_ID__`, region `eu-north-1`; **IAM access keys** in `secrets.env` (a
  Bedrock API key can't open the bidirectional stream). Run: `. .\load_secrets.ps1; py -3.12
  bedrock-voice\server.py` → `http://localhost:8765` (Chrome/Edge). Rules:
  - **The relay sends only what the caller was heard saying** (Nova's USER transcript or a typed
    turn), never Nova's tool argument. Nova once invented a caller "yes" to the identity
    confirm-back. Don't relax this.
  - The tool result key is `say_to_caller`: a message for the caller, often a question Nova must
    ask and never answer.
  - **Demo setup = laptop mic + speakers** (the audience must hear both sides), not a headset.
    Make one warm-up call first: a cold first Agentforce turn took 13.8 s.
  - **Delivery map on the page** (2026-09-19): `relay.py` calls `OCC_OrderMapRest` only after a
    tracking answer ("minutes by car") or a status answer saying the order shipped (the laptop mic
    can hear "where is" as "what is"). Candidate emails are Agentforce's confirm-backs plus emails
    the caller said. The call locks to the **first email Salesforce verifies**, never to the first
    read-back, because a read-back can be a mishearing the caller corrects. The response
    includes `directionsUrl` (Google Maps link, no key). If the agent's confirm-back or tracking
    wording changes, update the regexes in `relay.py`.
  - **Auto hang-up** (2026-09-19): the server sends `goodbye` when Agentforce's reply matches
    `relay.is_goodbye` (a closing phrase and no `?`). The page hangs up after Nova's `END_TURN` and
    local playback. Only a new relayed caller turn (`tool_start`) cancels it, never transcript text
    alone (ASR fragments, or speaker echo).
    The REST call runs as the ECA's Run As user (admin); that's a known trade-off.
  - Use `aws-sdk-bedrock-runtime` 0.11 API (`AsyncBedrockRuntimeConfig.resolve(...,
    transport=AWSCRTHTTPClient())`), not the older `amazon-nova-samples` code.
- **Demo surfaces in Salesforce (2026-09-19):**
  - `KeyburnHelp` VF page = branded "Keyburn · Order help" customer website with the deployed
    Embedded Messaging chat. `KeyburnChatTest` stays as the plain debug page.
  - The page is reached two ways:
    - the **Keyburn Website** tab in the **Keyburn Service** console app (orange header), which
      also has Cases, Contacts, Orders and Knowledge;
    - the public Force.com site **`Keyburn`**: `https://<my-domain>.my.salesforce-sites.com/keyburn/`.
      The guest profile `Keyburn Profile` gets page access only.
  - Chat embedding: the ESW site's `siteIframeWhiteListUrls` (in `sites/ESW_…site-meta.xml`) must
    list every domain that embeds the chat (VF, Sites, Lightning), plus a CORS origin for each
    (`Keyburn_Sites`).
  - Case list view **Agentforce Escalations** (subject starts with "Agent escalation"), and
    `Escalation_Summary__c` is on the Case layout.
  - **The list view lives in `sfdx-project/mdapi/case-listview/`** (metadata-API format). A
    source-format ListView needs a `Case.object-meta.xml` parent, which this project deliberately
    doesn't have. Deploy it with `sf project deploy start --metadata-dir mdapi/case-listview`.
  - `sites/*.site-meta.xml` contain the admin username → redacted as `__ADMIN_USERNAME__`.
  - **Channel + routing + voice are in source control** (retrieved 2026-09-20):
    `messagingChannels/Agentforce_Service_Agent` holds `isVoiceModeEnabled` (the mic button in the
    chat) and the Omni wiring `sessionHandlerAsa` = the agent, `sessionHandlerQueue` =
    `Service_Agent_Queue`; plus `queues/`, `queueRoutingConfigs/`, `serviceChannels/`,
    `presenceUserConfigs/`, `servicePresenceStatuses/`. The Order record page is
    `flexipages/Order_Record_Page` **and** the two `View`/`Flexipage` `actionOverrides` in
    `Order__c.object-meta.xml` — the page alone doesn't assign itself.
- Phase 12 — demo + deck. **Always the last phase**; no new features on Tue 22.

Carried over:

- Test-only fix: `case_open_new_support_case` requires "opened", but "Your support case number is
  …" is correct.
- **Re-test voice on v4**, including the open-cases flow. Voice was last verified on v2.
- **Rehearse the misheard-number moment in voice.** Voice works on v2, but the platform's
  injected voice prompt converts spoken "O" to 0 in identifiers, so "O-1O42" may silently match
  ORD-1042 and skip the confirm-back story. A digit mishearing is a more reliable demo. The text
  eval can't test this; only a voice run can.
- Clean-up: the `customer_email` / `confirmed_identifier` variables are never set. Also,
  eval runs have created many High-priority escalation Cases (00001031+); delete them before
  the demo if the case list is on screen.
- Low priority: check whether Claudeforce (Claude as Atlas Reasoning Engine model) is available
  in this org; if so, update the AI Tooling table's Model row in `Agentforce_FDE_Panel_Prep.md`.

## Working style

- Append to `project-status.md` when a decision is made or a phase completes.
- Prefer small, deployable increments — verify with a real agent transcript, not just a unit test.
- When something fails, root-cause it (e.g. `UserRecordAccess` SOQL for sharing questions)
  rather than widening permissions.
- Make org-UI changes durable: retrieve them into `sfdx-project/` afterwards.
- The builder is a Technical Architect with 15+ years in CRM — skip Salesforce fundamentals, but
  do flag Agentforce-specific quirks, which change shape often.
