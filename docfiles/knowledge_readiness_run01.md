# Knowledge readiness — run01_baseline (2026-09-22)

Tool: `salesforce/agentforce-knowledge-readiness`, deployed to the dev org as the Knowledge Readiness
app (Phase 14). Scope: the 6 published `Policy_FAQ` articles.
- Content field: `Article_Body__c` (Summary is always included).
- Data categories: off.
- Duplicate/conflict search index: `KA_Agent_Library_Data_Space` (the Agentforce Data Library over
  Knowledge, ADL = yes).
- LLM scoring on. Took 51 s.

Read from the tool's own objects (`KB_Assessment_Run__c`, `KB_Article_Assessment__c`,
`KB_Dimension_Result__c`) with SOQL, not from screenshots.

## Overall: 68 / 100 — 2 Ready, 3 Needs Work, 1 Not Ready

| Dimension (weight) | Score |
|---|---|
| Completeness (30%) | **45** |
| Structure (20%) | 84 |
| Clarity (10%) | 89 |
| Freshness (10%) | 76 |
| Duplication (15%) | 100 |
| Conflict (15%) | 100 |

## Per article

| Article | Score | Status | What pulled it down |
|---|---|---|---|
| How an order moves through Keyburn | **47.6** | Not Ready | Completeness 25, Structure 52: *"depends on an image for the workflow details, so chunked text will not be self-contained"* |
| Warranty Terms | 57.1 | Needs Work | Completeness 20: **BLOCKING — title has too few words (2)** |
| Return Policy | 57.7 | Needs Work | Completeness 20: same blocking title rule |
| Exchange Process | 58.9 | Needs Work | Completeness 20: same blocking title rule |
| Damaged or Wrong Item Received | 92.8 | Ready | — |
| Standard Shipping Timelines | 92.8 | Ready | — |

Clarity (78–92) and Structure (88–92 outside the workflow article) are strong on every article. The
body text isn't the problem.

## Findings

1. **Three articles are blocked by their titles, not their content.** A two-word title ("Return
   Policy") fails a deterministic gate: titles must be specific enough to anchor retrieval. The
   article is then capped at Completeness 20, and the gate also skips it for the duplicate/conflict
   pipeline (only the two Ready articles show Duplication/Conflict results). The fix is a more
   specific title. No content change is needed.
2. **The workflow article is Not Ready by design.** Phase 10 deliberately keeps two facts only in the
   diagram, so that a regression to text retrieval fails the evals. The tool correctly flags this
   as un-chunkable for text retrieval. That's the real trade-off: an image-only source is invisible
   to text RAG unless something reads the image, either at question time (Phase 10) or at index
   time (Phase 13b, Intelligent Context).
3. **No duplicates or conflicts** among the articles the pipeline reached. The S3 documents aren't
   Knowledge, so they're outside this tool's scope. A protection plan covering accidental damage
   next to Article 3's exclusion would be a real conflict if both lived in Knowledge.
4. **Freshness 76** everywhere, because every article was written this month. It's the ceiling
   for a new knowledge base, not a defect.
