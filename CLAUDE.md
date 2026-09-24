# AgentFDE — Order & Case Concierge

Voice-enabled Agentforce Service Cloud agent built in a Salesforce **DEV org**, for a Forward
Deployed Engineer Builders Panel at Salesforce. **Demo: 2026-09-24, 14:45, Salesforce Madrid office.**

Salesforce agent name: "Keyburn Customer Service" (dev name `Keyburn_Customer_Service`),
presented as "Order & Case Concierge". Fictional company: Keyburn.

**Git repo, published publicly on GitHub** (since 2026-09-19; moved out of OneDrive). Commit
before risky edits so there is history to fall back on.

**Org identifiers are redacted by a git filter.** `.gitattributes` routes text files through a
`redact` clean/smudge filter: the working copy keeps the real org ID, My Domain, agent username,
agent user ID and AWS account ID (deployable), and commits contain a placeholder in their place:
each `REDACT_*` key name wrapped in double underscores. Values come from the `REDACT_*` lines in
`secrets.env` (never repeat a value in a doc — reference its key name, as this file does), and
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
| `docfiles/DEMO_GUIDE.md` | Phase 18: demo script, pre-flight checklists, failure recovery, design-decision crib sheet (the deck itself is a claude.ai Slides artifact) |
| `docfiles/BUILD_RUNBOOK.md` | Phased build plan (phases 0–18; 9–11 added 2026-09-17, 12–17 from panel feedback 2026-09-22, 18 = demo + deck, always last) |
| `docfiles/agent_builder_topics.md` | Paste-ready instructions per topic/subagent + eval→topic mapping |
| `docfiles/README_eval_harness.md` | Agent API / External Client App setup for the eval harness |
| `docfiles/knowledge_articles.md` | Source text of the 5 Policy/FAQ Knowledge articles |
| `docfiles/flex_credits_estimate.md` | Flex Credits consumption model for a production deployment (~57 credits/conversation; the OTP gate is 51% of it). Rate card 2026-08-31 |
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
| `s3-docs/` | Phase 13: policy documents in the S3 bucket that Data 360 indexes as unstructured data lake objects. `visual/` holds the packaging damage guide PDF, whose instructions exist only as pixels — live in the agent since v46 |
| `sfdx-project/specs/` | Phase 15: Testing Center spec `Keyburn_Regression.yaml` (deployed as `AiEvaluationDefinition`) + the UI-only voice set `Keyburn_Voice.md`. Results in `src/eval_reports/testing_center/` |
| `tools/knowledge-readiness/` | Phase 14 (planned): vendored `salesforce/agentforce-knowledge-readiness`, its own sfdx project. Git-ignored (local only) |

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
  is the working draft and the file to edit. **Active version: v46** = v44 plus the Phase 13b
  packaging damage guide on Policy/FAQ (v45 was the same thing with citations still on; see
  `project-status.md` 2026-09-23). v44 = the verification gate **disabled** plus a working two-step
  call close. v43 was the same change with `call_closing` routing too eagerly — a bare "okay" ended
  the call — and v44 is the fix. v42 = the Phase 16 gate made *structural*; v41 = the Apex guard on its own;
  v40 = the gate as an instruction only, which the model demonstrably skipped; v38 = v33 (the Phase 9
  demo candidate) + Phase 10 (Draft status, workflow diagram read by a multimodal prompt template).
  It keeps normal identifiers, the map card in the deployed chat (**first tracked order per conversation only**;
  see `project-status.md`), and an **identity lock enforced in Apex**. Fallbacks: v44 (drops the
  damage-guide question, nothing else), v42 (gate back on), then v38, then v33.
  **The OTP gate is built and switched off** (2026-09-23, for the demo): a caller on stage cannot
  open the mailbox the code goes to, so the gate stalls the call. It is off by one variable default —
  `email_verified: mutable boolean = True` — plus the three "if not verified, go to
  `customer_verification`" sentences and the three subagent-level routes into it, all removed with a
  comment marking the spot. **The Apex guard is unchanged and still refuses on `false`**, so the
  `with emailVerified = @variables.email_verified` bindings must stay bound to that variable;
  deleting them would pass null, which is permissive for a different reason. `customer_verification`,
  both Apex actions, `OCC_Verification__c` and the permission sets are untouched. Re-enabling is a
  revert of those edits and a republish — no Apex deploy either way.
  **Two bound inputs carry the guardrails, and both are enforced in Apex, never in the prompt:**
  `lockedEmail = @variables.verified_email` (`OCC_CaseLookupUtil.violatesLock` refuses any other
  email) and `emailVerified = @variables.email_verified` (`OCC_CaseLookupUtil.notVerified` refuses
  before any SOQL when the caller has not read back the code). Each lookup also returns
  `verifiedEmail` + `identityLocked`, which the script stores. **New lookup actions must follow both
  patterns.** `notVerified` treats *null* as permissive on purpose — null means a non-agent caller
  (Apex tests, the record page, `OCC_OrderMapRest`), and it is what makes a rollback to v40 clean.
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
  - **Ending the call is two steps, and the split is load-bearing** (v44). Step one, "is there
    anything else I can help you with?", is in the `system:` instructions and stays with whichever
    subagent just answered — it is a *question*, so the call must stay open for the answer. Step two
    is `subagent call_closing`, whose one job is a single sentence with **no question mark**: the
    Phase 11 page hangs up on `relay.is_goodbye`, and that rejects any reply containing `?`. A
    closing line ending "…anything else?" leaves the caller on a line nobody ever ends.
    Two traps, both hit on 2026-09-23:
    - **"End the call" is not an escalation.** `go_to_escalation`'s router description said "such as
      cancelling or deleting their account", and "please cancel the call" matched it — a junk
      High-priority Case, then the escalation subagent repeating the same handoff sentence on every
      later turn because the router kept landing there. Both router descriptions now name the
      distinction explicitly.
    - **A bare acknowledgement is not a goodbye.** v43 routed "okay" to `call_closing` and hung up
      mid-lookup. v44 excludes "okay"/"sure"/"yes"/"thanks" on their own and any answer to a
      question just asked, in the router description *and* in `call_closing` itself, and forbids
      escalation from logging a case and closing in the same turn.
  - `aiAuthoringBundles/Keyburn_Customer_Service_1/` = the v1 snapshot (its meta has
    `<target>Keyburn_Customer_Service.v1</target>`); `genAiPlannerBundles/*_vN/` are compiled
    output from publish — don't hand-edit either.
  - Edit loop: edit draft → `sf agent validate authoring-bundle` → `sf agent publish
    authoring-bundle` (creates a new **inactive** version and retrieves it) → `sf agent activate
    --version N` → re-run evals. Rollback = activate the previous version number.
  - Publishing does not activate. A saved Agent Builder edit isn't live until it's published
    **and** activated. The 09-15 confirm-back edit sat unpublished for two days because of this.
  - If you edit in Agent Builder instead, retrieve right after or the local draft goes stale.
    `AiAuthoringBundle` / `GenAiPlannerBundle` didn't exist at the project's old API 61.0, so plain
    `sf project retrieve start --metadata ...` silently skips them. Retrieve with a
    `package.xml` whose `<version>` is 67.0 via `--manifest`. (`sfdx-project.json` is now at 67.0,
    which is also the org's maximum; the manifest route is still the proven one.)
  - `docfiles/agent_builder_topics.md` is the original design text and is **not** in sync. The
    `.agent` file wins.
- 5 subagents behind `agent_router`: Order Status, Case Status, Return Eligibility, Policy/FAQ,
  Escalation — plus `call_closing` (ends the call), `customer_verification` (built, currently
  unreachable — the gate is off) and the `off_topic` / `ambiguous_question` handlers.
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
- **Phase 13b — the S3 packaging damage guide (agent v46).** A second grounding corpus next to
  Knowledge: S3 → unstructured data lake object `Keyburn_Visual_Docs_v2` → **Intelligent Context**
  configuration `Keyburn_Visual_Docs_ICon` → retriever → RETRIEVER-type data library → the same
  `streamKnowledgeSearch` action, invoked under a second alias. Things that cost time to learn:
  - **Image Processing must be ON.** With it off (as the runbook originally said) the parser returns
    the PDF's text layer and skips its figures. `Keyburn_Visual_Docs_IC_v2` is that negative, kept
    next to `ICon` as an A/B pair on the identical file. Check the `_chunk__dlm` table, never the
    transcript; chunks appear ~11 minutes after a configuration is published.
  - **One action can serve as two tools.** An invocation alias may carry its own `description:`, so
    `AnswerFromPackagingDamageGuide: @actions.AnswerQuestionsWithKnowledge` with
    `ragFeatureConfigId = @variables.damage_guide_rag_id` gives the model a tool choice rather than a
    prose rule, and the corpus is bound rather than slot-filled. Copy this for any further corpus.
  - **Citations are off on that alias.** The citation resolves to a presigned S3 URL carrying the
    bucket user's access key id — fine in a trace, not on a shared screen. The Knowledge alias keeps
    its citations. The image-derived chunks carry `Citations__c` = `{}` regardless.
  - **Retrievers are UI-only**: no CLI, no sObject, no REST route, and `information_schema` /
    `SHOW TABLES` are rejected by the Data Cloud SQL endpoint. Take the id from the browser URL.
    Everything downstream is scriptable (`sf agent adl create --source-type retriever`).
  - The retrieval hop costs **~10 s**, and chunks come back as **markdown**, so the instruction has
    to forbid speaking the asterisks.
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
| `OCC_CreateEscalationCase` | Escalation | creates High-priority Case with `Escalation_Summary__c`. The model's reason codes (`financial_request`, `unverifiable_identity`, `frustration`, `out_of_scope`, anything else → fallback) are mapped by `named()` to a production-style Subject + Type + Reason; `Origin` = `Agentforce Agent` on every agent Case. **Never store a reason code on a Case** |
| `OCC_GetOrderDeliveryInfo` | Order Status | email + order # → remaining distance, driving time, position age, static-map URL/`<img>` (Google Routes + Static Maps; callout) |
| `OCC_DeliveryMap` | shared | route + static-map + haversine fallback + "9 minutes ago"; used by the action, the record page and the REST endpoint |
| `OCC_OrderMapController` | record page | `occOrderDeliveryMap` LWC on `Order__c`; record access governs, so no email check |
| `OCC_OrderMapRest` | Phase 11 page | `GET /services/apexrest/keyburn/ordermap?email=&orderNumber=`, same verification as the agent action |
| `OCC_GetOrderMapLink` | (unused) | standalone rich-link action; the model skipped it, so the card moved into `OCC_GetOrderDeliveryInfo`. Pinned by agent v11 — delete with v11 after the demo |
| `OCC_ListOpenCases` | Case Status | email + order-or-case # → open case count + up to 3 "case #, subject" |
| `OCC_CreateSupportCase` | Case Status | email + order-or-case # + issue → Medium-priority Case (Subject/Priority/ContactId only) |
| `OCC_ExplainOrderWorkflow` | Policy/FAQ | question → finds the PNG File on Knowledge article `how-an-order-moves-through-keyburn` → Flex prompt template `OCC_Order_Workflow_Diagram` (GPT-4o reads the image) → `answered` + spoken answer; `NOT_IN_DIAGRAM` → `answered=false` |
| `OCC_PolicyFAQLookup` | (unused fallback) | stopword-stripped SOSL over published `Knowledge__kav` |
| `OCC_SendVerificationCode` | Customer Verification | email → six-digit code on an `OCC_Verification__c` row (salted hash only; `Code_Plain__c` **only** while `Keyburn_Setting__mdt.Test_Mode__c` is true) and, outside test mode, an email. Takes `lockedEmail`: no code is ever issued for a second address. An unknown address gets the same answer as a known one — existence is not disclosed |
| `OCC_VerifyCode` | Customer Verification | email + code → `verified`. **The only thing that can set `@variables.email_verified`** |
| `OCC_CaseLookupUtil` | shared | `normalize()` for spoken order/case numbers; `verifiedContactId()` = email + an identifier that belongs to that Contact; `violatesLock()` = the identity lock; `notVerified()` = the Phase 16 gate |

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

Agent running user: the `REDACT_AGENT_USERNAME` value in `secrets.env` (its Id is
`REDACT_AGENT_USER_ID`; license *Einstein Agent*, profile *Einstein Agent User*). Identifiers
live only in `secrets.env` — don't paste them back into this file.

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
   **This includes custom metadata types**: `<customMetadataTypeAccesses>` for `Keyburn_Setting__mdt`
   is what makes the Google key and warehouse origin readable by the agent user. From **API 62
   onwards `WITH USER_MODE` enforces custom-metadata-type access**, so the 61 → 67 bump turned a
   silent gap into "I'm having trouble tracking that order right now" in every tracking answer,
   while admin tests still passed (2026-09-22). After any API version bump, re-run both suites.
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

**An instruction is not a control surface.** Three times now a rule written into the prompt has been
silently ignored — `ExplainOrderWorkflow` skipped (4 reproductions), the router's partial-answer rule
(v39 changed nothing), and the Phase 16 verification gate (v40 answered a lookup with no code sent).
More prose never fixed any of them. Anything that **must not be skipped** needs a fact the model
cannot set: a bound input checked in Apex (`violatesLock`, `notVerified`) or a variable the
instructions branch on that only an action output can write. Prose is for tone and for choosing
between correct options.

**Verify a guardrail from the trace, not from the transcript.** A reply that reads correctly proves
nothing about what the action was actually given. `ssot__AiAgentInteractionStep__dlm`'s
`ssot__InputValueText__c` holds the real action input JSON, so
`... WHERE ssot__InputValueText__c LIKE '%"emailVerified":false%'` answers "has this guard ever been
bypassed" in one query. That is how the Phase 16 gate was confirmed (it never has) and how the
"platform might drop a false boolean" worry was disproved.

**A green eval case can still be an ungrounded answer.** Run 32's
`case_list_open_none_offers_to_open` passed on *"You do not have any open cases"* while
`ListOpenCases` was never called — the answer was true only because the test data makes it true.
Keyword scoring cannot see this; an action assertion can. It is the same failure as the
`ExplainOrderWorkflow` skip, and it is the reason both suites exist. Open.

**A subagent that interrupts a flow needs a way back into it.** `customer_verification` shipped with
`go_to_escalation` as its only exit, so after a successful check it had nowhere to hand control and
asked the caller to repeat what they had already said. Four eval failures, one missing transition.
When adding a subagent, list every subagent that can route *into* it and give it a route back out.

**`WITH USER_MODE` fails in two different ways, and only one of them is visible.** An FLS/CRUD
violation **throws** (`System.QueryException`). A **sharing** restriction **does not throw** — it
silently drops the record from the result set, which is indistinguishable from "no such data"
from the outside. When a query returns empty but the record demonstrably exists, suspect sharing
before FLS. This distinction was the crux of the longest debugging chain in the build.

**`UserRecordAccess` is the definitive answer to "can this user actually see this record"** —
it returns real access after CRUD, FLS *and* sharing:

```sql
SELECT RecordId, HasReadAccess, MaxAccessLevel FROM UserRecordAccess
WHERE UserId = '<agent user Id — REDACT_AGENT_USER_ID in secrets.env>'
  AND RecordId IN ('003...','500...')
```

`HasReadAccess=false, MaxAccessLevel=None` on a record that exists = a sharing gap. Reach for
this before theorizing.

**When Debug Logs are empty**, a fast substitute is to temporarily return the raw exception in
the customer-facing message (`resp.message = 'DEBUG: ' + e.getMessage();`) and read it straight
out of the agent transcript. Revert it immediately after — see constraint 6.

## Commands

Salesforce CLI, org alias `devorg`. **Run from `sfdx-project/`** (source format, API 67.0 — the org's maximum).

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

# Phase 17: read the Session Tracing tables (PowerShell). The CLI HTML-escapes the pipe, so a plain
# Select-String "READOUT\|" matches only the script's own source echo - decode the entity instead:
#   ... | Select-String "USER_DEBUG.*READOUT" |
#         ForEach-Object { ($_ -replace '.*DEBUG\|READOUT&#124;','') -replace '&#124;',' | ' }
sf apex run --file scripts/observability_readout.apex --target-org devorg        # volume, actions, escalation rate, quality
sf apex run --file scripts/observability_session_detail.apex --target-org devorg # one session, turn by turn (edit SESSION_ID)

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
  repeat 18/18. … → 27 v38 26/27 → 28 v38 26/27 (first traced run) → 29 / 29b v38 + rewritten
  Knowledge 29/29 (2 `knowledge_*` cases added) → 30 v39 26/29 (the API-67 custom-metadata break,
  since fixed) → 31 v40 24/29 (first run with the verification gate) → 32 / 32b v42 29/29 twice
  (gate enforced in Apex) → **33 / 33b v44 29/29 twice** (gate switched off + two-step call close;
  `auto_verifications` 0 and no reply asks for a code, both as expected —
  `eval_report_run33_v44_gate_off_call_closing.json`, `eval_report_run33b_v44_repeat.json`) →
  **34 / 34b v46 31/31 twice** (Phase 13b; the suite grew by the two `s3_*` cases,
  `eval_report_run34_v46_s3_damage_guide.json`, `eval_report_run34b_v46_repeat.json`).
- **The harness answers the verification gate itself** — dormant on v44, since nothing asks for a
  code any more, so `auto_verifications` is 0. It wakes up unchanged if you roll back to v42.
  When a reply asks for the six-digit code,
  `run_eval.py` reads the newest `OCC_Verification__c` row for that address and sends it as an extra
  turn, marked `auto: "verification_code"` in the transcript and counted in `auto_verifications`.
  It needs `Keyburn_Setting__mdt.Test_Mode__c = true` (that is what writes `Code_Plain__c`), and it
  requires `Contact__c != null` on the row, so it will not "verify" a typo a real caller could never
  receive mail at. One mailbox per case: it never unlocks a second identity.
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
- **Testing Center (Phase 15)** — the second suite, next to the harness. Spec:
  `sfdx-project/specs/Keyburn_Regression.yaml`; each case has an `# eval: <id>` comment. It asserts
  topic, actions and an LLM-judged outcome. Run from `sfdx-project/`, in PowerShell:

  ```powershell
  py -3.12 ..\src\check_tc_spec.py specs\Keyburn_Regression.yaml     # local check; the server names no failing case
  sf agent test create --spec specs/Keyburn_Regression.yaml --api-name Keyburn_Regression --force-overwrite -o devorg
  sf agent test run --api-name Keyburn_Regression --wait 30 --result-format json -o devorg --json > ..\src\eval_reports\testing_center\tc_runNN_<label>.json
  py -3.12 ..\src\summarize_tc_run.py ..\src\eval_reports\testing_center\tc_runNN_<label>.json
  ```

  Things to know:
  - It runs **real actions as the agent user**: each run creates about 5 Cases.
  - `conversationHistory` is replayed as text and no actions run for it. Anything that depends on a
    variable set by an action output stays harness-only (e.g. `guardrail_identity_switch_refused`).
  - **v44 removes this problem**: the gate is off, so replayed-history cases reach their lookups
    again and `UNVERIFIED_REFUSAL` no longer fires. The paragraph below applies only if you roll
    back to v42.
  - **Since v42 this costs the suite every gated case.** `email_verified` is False in a replayed
    history, so every lookup case now hits `UNVERIFIED_REFUSAL`. That coverage belongs in the Studio
    **conversation / voice** suites, which execute turns for real; the CLI suite keeps the cases that
    need no lookup (policy, workflow, escalation). Don't "fix" it by weakening the Apex guard.
  - Don't assert `AnswerQuestionsWithKnowledge`. The agent-level `knowledge:` block injects the
    articles into the `policy_faq` prompt, so FAQs are answered without that action.
  - Voice cases are only in the UI: `specs/Keyburn_Voice.md`.
  - **Agentforce Studio → Tests is a different store** from this CLI suite (its suites are not
    `AiEvaluationDefinition`, so `sf agent test list` never shows them). Upload CSVs:
    `specs/Keyburn_Regression_upload.csv` (rows that fire an action), `_noaction.csv` (rows that
    can't — a **blank Expected Actions cell fails**, it doesn't skip) and
    `Keyburn_Conversation_upload.csv` (simulated multi-turn callers). In Studio: turn **off**
    Completeness and Conciseness, check the **Conditions** step for live vs simulated actions
    (simulated returns null outputs, so the agent says "case number is None"), and select only the
    conversation-level scorers for a **conversation or voice** suite — their actual subagent/action
    values always come back empty (it follows the conversation runner, not voice or personas), while
    a single-turn suite captures both. **Voice testing is the Studio wizard's Data step**
    (*Select Conversation Output: Text and voice*); it stores a ~12 MB WAV per conversation against
    this org's 20 MB file limit, so keep it to 3 cases and run
    `scripts/purge_voice_recordings.apex` straight after.
  - Baseline and all of the above with evidence: `docfiles/testing_center_run01.md`.
  - Suite runs create Cases as the agent user. `scripts/purge_eval_cases.apex` deletes them
    (`Origin = 'Agentforce Agent'` + creator profile *Einstein Agent User*) and keeps the seeded
    data, so jane.doe keeps open cases and maria.garcia keeps none.
- **Expect a bad first run.** 50–70% pass is normal and is *good material* — save that first
  report. A climbing pass rate across saved runs is the Reliability & Evaluation evidence; a
  suite that passes first time mostly signals the tests were too easy.

## Remaining work

Phase 8 is **closed** (14/15 on agent v4, stable). Active is **v46** (v44 plus the Phase 13b
packaging damage guide on Policy/FAQ); the demo-safe fallbacks are **v44** (OTP gate built but
switched off, two-step call close working — drops only the damage question), then **v42** (gate back
on), then **v38**, then v33. **The agent was published twice on the evening of Wed 23, so the
Embedded Service deployment `Agentforce_Service_Agent` must be republished before the demo** or the
map card is sent but not drawn.
Phases 9–18 are planned in detail, with spikes and cut-offs, in `docfiles/BUILD_RUNBOOK.md`.
**Panel feedback on 2026-09-22 reopened the scope:** Phases 12–17 add observability (Session Tracing,
Agent Analytics, Sessions & Intents), an S3 → Data 360 unstructured pipeline, a Knowledge readiness
evaluation, Testing Center (text + voice) and an email verification (OTP) gate, built Tue 22 – Wed 23.
Phase 16 (the OTP gate) is the only change to the agent's core flow; its cut-off is Wed 23 18:00.

- **The Builder preview is not the deployed chat client.** Rich UI (the `OrderDeliveryMap` Custom
  Lightning Type) renders only in the deployed Embedded Messaging client, via the type's
  `enhancedWebChat` renderer — **never in the Builder preview**. Test visual changes on the
  `KeyburnChatTest` Visualforce page (Setup → Visualforce Pages → Preview). That path needed CSP
  trusted sites, CORS origins, guest access on the deployment and Omni-Channel routing to the agent
  — see `project-status.md` 2026-09-18.
- **Embedded Messaging needs the 15-character org ID** in `embeddedservice_bootstrap.init()`
  (`REDACT_ORG_ID_15` in `secrets.env`). With the 18-character ID the chat loads and messages send, but every live
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
  API. AWS account and region `eu-north-1` (`REDACT_AWS_ACCOUNT_ID`); **IAM access keys** in `secrets.env` (a
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
  - Case list view **Agentforce Escalations** (`Origin` = Agentforce Agent + `Priority` = High), and
    `Escalation_Summary__c` is on the Case layout.
  - **The list view lives in `sfdx-project/mdapi/case-listview/`** (metadata-API format). A
    source-format ListView needs a `Case.object-meta.xml` parent, which this project deliberately
    doesn't have. Deploy it with `sf project deploy start --metadata-dir mdapi/case-listview`.
  - `sites/*.site-meta.xml` contain the admin username → redacted through `REDACT_ADMIN_USERNAME`.
  - **Channel + routing + voice are in source control** (retrieved 2026-09-20):
    `messagingChannels/Agentforce_Service_Agent` holds `isVoiceModeEnabled` (the mic button in the
    chat) and the Omni wiring `sessionHandlerAsa` = the agent, `sessionHandlerQueue` =
    `Service_Agent_Queue`; plus `queues/`, `queueRoutingConfigs/`, `serviceChannels/`,
    `presenceUserConfigs/`, `servicePresenceStatuses/`. The Order record page is
    `flexipages/Order_Record_Page` **and** the two `View`/`Flexipage` `actionOverrides` in
    `Order__c.object-meta.xml` — the page alone doesn't assign itself.
- **Phase 12 — done (2026-09-22).** Session Tracing is on, and a preview session reaches Data Cloud in about
  3 minutes (`ssot__AiAgentSession__dlm` / `…Interaction__dlm` / `…InteractionStep__dlm`). Check it with
  `ConnectApi.CdpQuery.queryAnsiSqlV2` from anonymous Apex. The CLI token gets 401 on `/ssot/query-sql`
  (no Data Cloud scope), and `sf api request` / `sf data query` break in Git Bash ("C:\Program" path
  bug), so use PowerShell.
  **Turn on anything that provisions Data Cloud objects in the Setup UI, never through a metadata deploy.**
  `EinsteinAISettings.enableAIFeedbackWithDC=true` deployed the flag but left the page's Data Space blank,
  and Session Tracing then failed with "Data space not ready". Switching it off and on in the UI fixed it.
  `AgentforcePlatformTracingSettings` needs API 68 and isn't available in this org.
  Agent Analytics (Service + Employee) is installed. The templates only appeared once the admin had
  **Tableau Next Limited Consumer** and at least one session had been traced.
- **Phase 14 — done (2026-09-22).** Knowledge readiness tool (`tools/knowledge-readiness/`, vendored,
  git-ignored) scored 68 → 85 after its *Fix with AI* retitled Warranty/Returns/Exchange (reports:
  `docfiles/knowledge_readiness_run01.md` / `_run02.md`). Evals: run 29 and run 29b, **29/29 twice** on v38.
  **A published Knowledge change is invisible to the agent until the data stream refreshes and the
  Data Library index re-chunks.** Publishing archives the old version, and the search ignores archived
  versions, so in between the article is simply missing. To check, compare `SourceRecordId__c` in
  `KA_Agent_Library_Data_Space_chunk__dlm` with the online `Knowledge__kav` Ids. **No Knowledge edits
  after Wed 23.** The readiness tool's **Rerun** re-scores a run in place, so save its numbers first.
- **Phase 17 — built 2026-09-22 (pre-freeze); re-run as `run02` on 2026-09-24 (demo day).**
  `scripts/observability_readout.apex` and `scripts/observability_session_detail.apex` read the
  Session Tracing tables through `ConnectApi.CdpQuery.queryAnsiSqlV2` (run from PowerShell; see the
  decode note in the Commands block — a plain `READOUT|` grep returns nothing but source echo).
  Results: `docfiles/observability_readout_run01.md` and `_run02.md`.
  **Agent Analytics Escalation Rate is 0% and that is correct**: the platform metric means
  handoff-to-human, and `ssot__AiAgentSessionEndType__c` is `NOT_SET` on every session in this org.
  Escalation here logs a Case and keeps the conversation, so quote the trace-based number
  (run02: 105 of 681 sessions = **15.4%**), not the dashboard. The Phase 17 health alert watches the
  platform metric, so it will never fire. Purging eval Cases does not affect any of this - traces
  outlive the Cases. **No Apex class is
  deployed for observability** — the skill's `AgentforceOptimizeService` was skipped so no
  permission set has to grant it. Reading the trace tables:
  - rows are `ConnectApi.CdpQueryV2Row` (`row.rowData`), and column order comes from
    `metadata.get(col).placeInOrder`, not `keySet()`;
  - `NOT_SET` is the sentinel for empty, not null;
  - the subagent name carries the planner id of the version that ran it
    (`order_status_16jak000003GChp`); the agent version itself is on the participant row;
  - a moment carries several tag types (Quality / Deflection / Abandonment) — join
    `AiAgentTagDefinition` or the values come out mixed; values are text.
  - **Deleting Cases doesn't delete traces**, so trace counts and Case counts diverge after a purge.
  Agent Health Monitoring alert `3VRak00000007BBGAY` (Escalation Rate ≥ 0.1 raw ratio over 24 h,
  filtered to this agent, every 15 min). `minuteLevelFrequency` accepts **only 15 or 30**, this org's
  SDMs are labelled *Base* / *Extension* (match on `app`, not the label), and
  `sf api request rest --method DELETE` needs a `-b` body file `{"mode":"raw","raw":""}`.
- Phase 18 — demo + deck (was Phase 12 until 2026-09-22). **Always the last phase**; the agent
  version is frozen at Wed 23 18:00.

Carried over:

- Test-only fix: `case_open_new_support_case` requires "opened", but "Your support case number is
  …" is correct.
- **Voice verified on v46** (2026-09-23 evening, builder's own run): the call worked end to end,
  including the Phase 13b packaging-damage question and the workflow "what is the next status"
  question, both answered correctly. That closes the long-standing "voice last verified on v2" item.
  The open-cases flow was not part of that run, so it remains unverified in voice.
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
