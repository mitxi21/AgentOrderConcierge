"""
Eval runner for the Order & Case Concierge Agentforce agent.

Usage:
    export SF_MY_DOMAIN_URL="https://your-domain.my.salesforce.com"
    export SF_CLIENT_ID="..."
    export SF_CLIENT_SECRET="..."
    export SF_AGENT_ID="..."
    python run_eval.py eval_cases.yaml

This is meant to be driven by Claude Code: point it at this script and your
Salesforce dev org, and have it run the suite, read the report, and suggest
prompt/topic-instruction fixes for anything that fails.
"""
import re
import sys
import json
import time
import yaml
from datetime import datetime, timezone

from agent_client import client_from_env

# ---- Phase 16: the email verification gate ----------------------------------
# Agent v40 refuses every order/case lookup until the caller has read back a six-digit code.
# A scripted case can't carry the code, because it's generated per send. So the harness plays
# the part of a caller who can open their own inbox: when the agent asks for the code, it reads
# the newest OCC_Verification__c row for that address and answers with it.
#
# This only works while Keyburn_Setting__mdt.Test_Mode__c is true, which is what writes
# Code_Plain__c. With it false the code is only in a real mailbox and the suite cannot run.
#
# Injected turns are marked `auto: "verification_code"` in the transcript so a report can never
# be mistaken for one where the caller supplied it unaided.

#         ...[\w.-]+ would swallow the full stop that ends the sentence, and the lookup then
#         searches for "jane.doe@example.com." and finds nothing. Anchor on a word character.
EMAIL_RE = re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]*\w")
CODE_PROMPT_RE = re.compile(
    r"six-digit code|verification code|read it back to me|code (?:that|when) it arrives",
    re.IGNORECASE,
)
MAX_AUTO_VERIFICATIONS = 1  # one mailbox per caller; never unlock a second identity


def emails_in(texts):
    """Every address the scripted caller has said so far, oldest first."""
    found = []
    for t in texts:
        for m in EMAIL_RE.findall(t or ""):
            if m not in found:
                found.append(m)
    return found


def fetch_code(client, email, attempts=4, delay=1.0):
    """The newest code for that address, but only if a real Contact owns it.

    Contact__c != null is what keeps the simulation faithful. OCC_SendVerificationCode issues a
    code for an unknown address too, on purpose - whether an address exists in Keyburn's data is
    not something an unverified caller may learn. A real caller still cannot read a code sent to
    an address that isn't theirs. Without this filter the harness "verifies" a typo like
    jane.dough@example.com, the conversation locks to it, and the correction the case is actually
    testing can never land.
    """
    soql = (
        "SELECT Code_Plain__c, CreatedDate FROM OCC_Verification__c "
        f"WHERE Verified_Email__c = '{email}' AND Code_Plain__c != null AND Contact__c != null "
        "ORDER BY CreatedDate DESC LIMIT 1"
    )
    for i in range(attempts):
        rows = client.query(soql)
        if rows and rows[0].get("Code_Plain__c"):
            return rows[0]["Code_Plain__c"]
        if i < attempts - 1:
            time.sleep(delay)
    return None


def extract_text(messages):
    """Pull the plain text out of an Agent API response message list."""
    parts = []
    for m in messages:
        if m.get("type") == "Inform" and m.get("message"):
            parts.append(m["message"])
    return "\n".join(parts)


def non_text_types(messages):
    """Message types other than Inform (e.g. Escalate) - these carry no text to score."""
    return [m.get("type") for m in messages if m.get("type") != "Inform"]


def check_expectation(reply_text, expect, conversation_text=None):
    """Scores the final reply by default. With `match_scope: conversation` the whole conversation is
    searched instead - both for `contains_*` and for `must_not_contain`, so the case gets more
    lenient about WHERE the answer appears and stricter about the forbidden phrases. Needed because
    the agent decides how many turns it takes: since the single-confirmation fix it often answers
    in the first turn, leaving the scripted confirm turn to a closing pleasantry.

    Cases without the flag keep last-reply scoping, which matters for assertions like "the final
    reply must not ask for confirmation again" - an earlier turn is allowed to ask exactly once."""
    scope_all = expect.get("match_scope") == "conversation" and conversation_text is not None
    searchable = conversation_text if scope_all else reply_text
    return _check(searchable, searchable, expect)


def _check(reply_text, forbidden_scope_text, expect):
    reply_lower = reply_text.lower()
    failures = []

    contains_any = expect.get("contains_any")
    if contains_any and not any(s.lower() in reply_lower for s in contains_any):
        failures.append(f"expected one of {contains_any!r} in reply, found none")

    # Every group must be satisfied by at least one of its phrases (AND across groups, OR within).
    for group in expect.get("contains_any_groups") or []:
        if not any(s.lower() in reply_lower for s in group):
            failures.append(f"expected one of {group!r} in reply, found none")

    must_not_contain = expect.get("must_not_contain")
    if must_not_contain:
        forbidden_lower = forbidden_scope_text.lower()
        hit = [s for s in must_not_contain if s.lower() in forbidden_lower]
        if hit:
            failures.append(f"reply contained forbidden phrase(s): {hit!r}")

    return failures


def run_case(client, case):
    client.start_session()
    reply_text = ""
    transcript = []
    final_types = []
    said_so_far = []
    auto_verifications = 0
    try:
        for turn in case["turns"]:
            said_so_far.append(turn)
            messages = client.send_message(turn)
            # Score only the last turn's reply. Falling back to an earlier turn's text would let
            # a silent final turn (e.g. a bare Escalate) pass on stale text.
            reply_text = extract_text(messages)
            final_types = non_text_types(messages)
            transcript.append({"user": turn, "agent": reply_text, "non_text_messages": final_types})

            # The gate can interrupt any turn, including the last one. Answer it and let the
            # agent's continuation become the reply that gets scored.
            while (
                case.get("auto_verify", True)
                and auto_verifications < MAX_AUTO_VERIFICATIONS
                and CODE_PROMPT_RE.search(reply_text or "")
            ):
                candidates = emails_in(said_so_far)
                if not candidates:
                    break  # caller never gave an address - let the case fail honestly
                code = fetch_code(client, candidates[-1])
                if not code:
                    transcript.append({
                        "user": None,
                        "agent": None,
                        "auto": "verification_code",
                        "note": f"no code row found for {candidates[-1]}",
                    })
                    break
                auto_verifications += 1
                messages = client.send_message(code)
                reply_text = extract_text(messages)
                final_types = non_text_types(messages)
                transcript.append({
                    "user": code,
                    "agent": reply_text,
                    "non_text_messages": final_types,
                    "auto": "verification_code",
                })

        conversation_text = "\n".join(t["agent"] for t in transcript if t["agent"])
        failures = check_expectation(reply_text, case.get("expect", {}), conversation_text)
        if failures and final_types:
            failures.append(f"final turn included non-text message(s): {final_types!r}")
        return {
            "id": case["id"],
            "category": case.get("category"),
            "turns": case["turns"],
            "final_reply": reply_text,
            "final_non_text_messages": final_types,
            "transcript": transcript,
            "auto_verifications": auto_verifications,
            "passed": len(failures) == 0,
            "failures": failures,
        }
    finally:
        client.end_session()


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "eval_cases.yaml"
    with open(path, "r") as f:
        cases = yaml.safe_load(f)

    client = client_from_env()
    results = []
    for case in cases:
        print(f"Running: {case['id']} ...", flush=True)
        try:
            result = run_case(client, case)
        except Exception as exc:  # noqa: BLE001 - want to keep the suite running
            result = {
                "id": case["id"],
                "category": case.get("category"),
                "turns": case["turns"],
                "final_reply": None,
                "final_non_text_messages": [],
                "transcript": [],
                "auto_verifications": 0,
                "passed": False,
                "failures": [f"exception: {exc}"],
            }
        results.append(result)
        status = "PASS" if result["passed"] else "FAIL"
        print(f"  -> {status}")

    total = len(results)
    passed = sum(1 for r in results if r["passed"])
    report = {
        "run_at": datetime.now(timezone.utc).isoformat(),
        "total": total,
        "passed": passed,
        "failed": total - passed,
        "pass_rate": round(passed / total, 3) if total else 0,
        "results": results,
    }

    out_path = "eval_report.json"
    with open(out_path, "w") as f:
        json.dump(report, f, indent=2)

    print(f"\n{passed}/{total} passed ({report['pass_rate']:.0%}). Report: {out_path}")

    # Break out failures by category for a quick read
    by_category = {}
    for r in results:
        if not r["passed"]:
            by_category.setdefault(r["category"], []).append(r["id"])
    if by_category:
        print("\nFailures by category:")
        for cat, ids in by_category.items():
            print(f"  {cat}: {', '.join(ids)}")


if __name__ == "__main__":
    main()
