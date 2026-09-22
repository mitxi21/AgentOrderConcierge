"""Local shape check for a Testing Center spec before `sf agent test create`.

The CLI validates the whole spec server-side and one bad case rejects every case without naming
it, so check here first. Adapted from sf-skills agentforce-test/references/security-test-design.md
("Validate the spec before deploying"), with topic and action assertions allowed and checked
against the agent script.

    py -3.12 src/check_tc_spec.py sfdx-project/specs/Keyburn_Regression.yaml
"""
import re
import sys
from pathlib import Path

import yaml

AGENT = (Path(__file__).resolve().parent.parent / "sfdx-project/force-app/main/default"
         "/aiAuthoringBundles/Keyburn_Customer_Service/Keyburn_Customer_Service.agent")


def agent_names():
    text = AGENT.read_text(encoding="utf-8")
    topics = set(re.findall(r"^subagent (\w+):", text, re.M))
    # Invocation names under `reasoning: actions:` bound to @actions.X (not @utils transitions).
    actions = set(re.findall(r"^\s+(\w+): @actions\.\w+", text, re.M))
    return topics, actions


def main(path):
    spec = yaml.safe_load(open(path, encoding="utf-8"))
    topics, actions = agent_names()
    cases, seen, bad = spec.get("testCases") or [], {}, 0

    def fail(i, msg):
        nonlocal bad
        print(f"case {i}: {msg}")
        bad += 1

    for k in ("name", "subjectType", "subjectName"):
        if not spec.get(k):
            print(f"missing top-level {k}")
            bad += 1

    for i, c in enumerate(cases, 1):
        u = c.get("utterance") or ""
        if not u.strip():
            fail(i, "missing or empty utterance")
        if not (c.get("expectedOutcome") or "").strip():
            fail(i, f"missing expectedOutcome -> {u[:50]}")
        t = c.get("expectedTopic")
        if t is not None and t not in topics:
            fail(i, f"expectedTopic {t!r} is not a subagent in the .agent file")
        acts = c.get("expectedActions")
        if acts is not None:
            if not isinstance(acts, list) or not all(isinstance(a, str) for a in acts):
                fail(i, "expectedActions must be a flat list of strings")
            else:
                for a in acts:
                    if a not in actions:
                        fail(i, f"expectedActions {a!r} is not a reasoning action in the .agent file")
        hist = c.get("conversationHistory") or []
        roles = [h.get("role") for h in hist]
        if roles and (len(roles) % 2 or roles != ["user", "agent"] * (len(roles) // 2)):
            fail(i, f"malformed history {roles} (must alternate user/agent and end on agent)")
        for n, h in enumerate(hist):
            if not (h.get("message") or "").strip():
                fail(i, f"history[{n}] has an empty message")
            if h.get("role") == "agent" and h.get("topic") and h["topic"] not in topics:
                fail(i, f"history[{n}] topic {h['topic']!r} is not a subagent")
        for where, v in ([("utterance", u)]
                         + [(f"history[{n}]", h.get("message") or "") for n, h in enumerate(hist)]
                         + [("expectedOutcome", c.get("expectedOutcome") or "")]):
            if "\n" in v:
                fail(i, f"raw newline in {where}")
            if any(ord(ch) > 126 for ch in v):
                fail(i, f"non-ASCII character in {where}")
        key = (tuple(h.get("message") for h in hist), u)
        if key in seen:
            fail(i, f"duplicate of case {seen[key]}")
        seen[key] = i
        # Plain duplicate utterances are legal but flagged, in case the server rejects them.
    utts = [c.get("utterance") for c in cases]
    dups = sorted({x for x in utts if utts.count(x) > 1})
    if dups:
        print(f"note: utterances used by more than one case: {dups}")

    if not cases:
        print("NO testCases found")
        bad += 1
    print(f"{len(cases)} cases checked, {bad} problem(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
