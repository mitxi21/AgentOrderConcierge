"""Per-case summary of a Testing Center run, mapped back to the eval ids in the spec.

    py -3.12 src/summarize_tc_run.py src/eval_reports/testing_center/<run>.json [spec.yaml]

Takes the JSON from `sf agent test run --result-format json --json` (or `sf agent test results`).
Each case's `# eval: <id>` comment in the spec gives its name; failing cases also print the
agent's reply and the judge's reason.
"""
import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
METRICS = ("topic_assertion", "actions_assertion", "output_validation")


def main(run_path, spec_path=ROOT / "sfdx-project/specs/Keyburn_Regression.yaml"):
    ids = re.findall(r"# eval: (\w+)", Path(spec_path).read_text(encoding="utf-8"))
    data = json.loads(Path(run_path).read_text(encoding="utf-8-sig"))
    run = data.get("result", data)
    totals = {m: [0, 0] for m in METRICS}
    print(f"run {run.get('runId')}  {run.get('startTime')} -> {run.get('endTime')}")
    for tc in sorted(run["testCases"], key=lambda t: t["testNumber"]):
        n = tc["testNumber"]
        res = {r["name"]: r for r in tc.get("testResults", [])}
        row = []
        for m in METRICS:
            v = res[m]["result"] if m in res else "-"
            row.append(v)
            if m in res:
                totals[m][1] += 1
                totals[m][0] += v == "PASS"
        g = tc.get("generatedData", {})
        name = ids[n - 1] if n <= len(ids) else f"case{n}"
        bad = any(v not in ("PASS", "-") for v in row)
        print(f"{n:2} {name:46} {row[0]:8}{row[1]:8}{row[2]:8} topic={g.get('topic')} "
              f"actions={html.unescape(g.get('actionsSequence', ''))}{'  <<<' if bad else ''}")
        if bad:
            print("     reply:", html.unescape(g.get("generatedResponse", ""))[:300])
            print("     judge:", res.get("output_validation", {}).get("metricExplainability", "")[:300])
    print("  ".join(f"{m} {p}/{t}" for m, (p, t) in totals.items()))


if __name__ == "__main__":
    main(*sys.argv[1:])
