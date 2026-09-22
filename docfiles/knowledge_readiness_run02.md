# Knowledge readiness — run02_after_ai_fix (2026-09-22), before/after

Baseline: `knowledge_readiness_run01.md`. Same tool, scope and settings.

> Clicking **Rerun** on a run re-scores it **in place**. `run01_baseline` in the org now shows
> 84.7, not the 67.8 it scored originally. The baseline figures below come from the report saved
> before the rerun. Save each run's numbers before rerunning it.

## What changed between the runs

1. **Fix with AI** (the tool's Actions tab) on the three "Needs Work" articles. The tool drafted a
   rewrite; a person reviewed it and published it.
   - The titles became specific:
     - "Warranty Terms" → *Manufacturer Warranty Coverage, Exclusions, and Claim Process*
     - "Return Policy" → *30-Day Return Policy and Refund Process*
     - "Exchange Process" → *Item Exchange Eligibility and Process*
   - The Returns body was restructured into labelled sections. All facts were kept in all three.
2. **The AI invented a fact in one draft.** The Exchange rewrite widened "a different size, color,
   or model" to "size, color, or model, **style, or version**". It was caught by comparing the
   published text with the source, and corrected in v3 by a one-phrase edit.
3. **The workflow article was left alone on purpose** (the Phase 10 image-only design).

## Result: 68 → 85

| | run01 | run02 |
|---|---|---|
| **Overall** | **67.8** | **84.9** |
| Completeness | 45 | **81** |
| Structure | 84 | 83 |
| Clarity | 89 | 89 |
| Freshness | 76 | 76 |
| Duplication / Conflict | 100 / 100 | 100 / 100 |
| Ready / Needs Work / Not Ready | 2 / 3 / 1 | **5 / 1 / 0** |

| Article | run01 | run02 |
|---|---|---|
| Warranty | 57.1 Needs Work | **91.6 Ready** |
| Returns | 57.7 Needs Work | **88.6 Ready** |
| Exchange | 58.9 Needs Work | **92.8 Ready** |
| Damaged or Wrong Item | 92.8 Ready | 92.8 Ready |
| Shipping | 92.8 Ready | 92.8 Ready |
| How an order moves through Keyburn | 47.6 Not Ready | 50.6 Needs Work (unchanged article; LLM scoring variance) |

## The catch: better Knowledge scores, and a temporary regression in the agent

Straight after the rewrite, the Knowledge evals **failed**. The agent said *"I couldn't find
information about…"* for warranty and exchange questions. The trace showed the knowledge search
returning only the three **untouched** articles. The chain:

1. Publishing a new version archives the old one. The search drops archived versions, so the old
   chunks stop matching.
2. The Knowledge data stream (`Knowledge_kav_Home`, batch) picked up the new versions at its next
   refresh (14:20 UTC, 8 minutes after publishing).
3. The Data Library's **search index** re-chunks separately and later. Until it does, the new
   version IDs have **no chunks**, so the rewritten articles are invisible to the agent.

**Lessons:**
- A Knowledge edit that scores better in a readiness tool can still make the agent worse until the
  index catches up.
- Check the agent (evals + trace), not only the content score.
- Don't edit Knowledge on demo day.
- The `knowledge_*` evals added in this phase are what caught it.
