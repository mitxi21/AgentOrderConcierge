# Agentforce Eval Harness

Drives your live Agentforce agent through a scripted set of test conversations
via Salesforce's **Agent API**, and scores each one pass/fail.

## 1. One-time setup in your dev org

1. **Enable the agent for API access.** Agent API isn't supported for agents
   of type "Agentforce (Default)" — confirm your agent's type in Setup.
2. **Create an External Client App (ECA)** configured for the Client
   Credentials OAuth flow. In the ECA's OAuth settings, enable these scopes:
   `api`, `refresh_token`/`offline_access`, `chatbot_api`, `sfap_api`. On the
   Policy tab, enable **Client Credentials Flow** and set **Run As** to a
   user with API-only access.
3. **Get the agent's ID** (Setup → your agent → agent details page).
4. **Get your My Domain URL** (Setup → My Domain).
5. **Get the ECA's Consumer Key and Secret** (ECA → Settings tab → OAuth
   Settings).

## 2. Configure

```bash
pip install requests pyyaml
export SF_MY_DOMAIN_URL="https://your-domain.my.salesforce.com"
export SF_CLIENT_ID="<consumer key>"
export SF_CLIENT_SECRET="<consumer secret>"
export SF_AGENT_ID="<agent id>"
```

## 3. Run

```bash
python run_eval.py eval_cases.yaml
```

This prints a live pass/fail per case and writes a full `eval_report.json`
with each case's full transcript and failure reasons.

## 4. Have Claude Code close the loop

Point Claude Code at `eval_report.json` after a run and ask it to:
- summarize which topics/guardrails are failing and why
- propose specific edits to the relevant Topic's instructions in Agent
  Builder
- re-run the suite after you apply a fix, and diff the two reports

That loop — script drives the agent, Claude reads the structured failures,
you (or Claude) patch the topic instructions, re-run — is the concrete,
demoable version of "how did you detect, fix, or mitigate failure modes"
for the panel's Issues & Trade-offs section.

## Notes / things worth double-checking against current Salesforce docs
before the panel, since APIs evolve:
- Exact OAuth scope names and ECA policy toggles
  (developer.salesforce.com/docs/ai/agentforce/guide/agent-api-get-started.html)
- Whether your specific agent type needs `bypassUser: true` or `false` —
  this determines whose permissions the agent runs under, which is directly
  relevant to your "data access limits" guardrail story
