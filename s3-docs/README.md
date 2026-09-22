# s3-docs — policy documents for the S3 → Data 360 pipeline (Phase 13)

These files are uploaded to the S3 bucket named by `AWS_S3_BUCKET` in `secrets.env`. Data 360 reads
them in place through an unstructured data lake object (UDLO), indexes them, and the agent retrieves
from that index. The Knowledge articles (`docfiles/knowledge_articles.md`) are a separate source; these
documents fill gaps next to them and must not contradict them. Phase 14 scores Knowledge for conflicts.

HTML is used because Data 360 indexes HTML, TXT and PDF from S3, and HTML stays diffable in git.

| File | Owner | Facts that exist **only** here (the `s3_*` evals assert these) |
|---|---|---|
| `keyburn-delivery-service-levels.html` | Logistics | 3 delivery attempts; parcels held at the pickup point for **7 calendar days**; investigation after 5 business days without a scan, concluded within 10; signature required above 500 euros |
| `keyburn-extended-protection-plan.html` | Legal | +2 years after the 1-year warranty (3 years in total); can be added up to **60 days** after delivery; **one accidental damage claim per 12 months**; never pays cash |
| `keyburn-order-changes-and-address-corrections.html` | Customer Operations | a carrier redirect after shipping costs **4.99 euros**, same country only, before the first delivery attempt; gift message up to 200 characters |

### `visual/` — Phase 13b, image read at index time

`visual/keyburn-packaging-damage-guide.pdf` goes in the bucket's `visual/` folder. It has its own
data lake object (file type PDF), indexed by an **Intelligent Context** configuration with
**LLM-based parsing**. Its text layer only says that the pictures show "the grade and what to do".
**What to do for each grade exists only as pixels in the image**, so it can only be answered if the
parser read the image:
- grade A (dented corner): accept;
- grade B (crushed or punctured): accept, check the item, report it with a photo if it's damaged;
- **grade C (wet or torn open): refuse the delivery; the carrier returns it and a replacement ships
  automatically.**

This is the counterpart of Phase 10:
- Phase 10: GPT-4o reads the order-workflow diagram at **question time**.
- Phase 13b: an LLM reads this image **once, at index time**.

Regenerate the PDF with `py -3.12 s3-docs/visual/make_damage_guide.py`. It needs Pillow and fpdf2,
and Arial from `C:/Windows/Fonts`. A `pypdf` text extraction confirms that none of the instructions
leak into the text layer.

Relationship with Knowledge:
- The protection plan adds accidental-damage cover **as a paid add-on**. It doesn't change Article 3,
  where the standard warranty excludes accidental damage.
- The address rules agree with the workflow diagram: an order can't be cancelled after it ships, and
  only its address can still be redirected.

## Access

- **Upload:** done by hand in the S3 console. The Bedrock keys in `secrets.env` have no S3 access, by
  design.
- **Data 360 reads the bucket** as a dedicated IAM user, `keyburn-datacloud-s3`, with keys
  `AWS_S3_ACCESS_KEY_ID` / `AWS_S3_SECRET_ACCESS_KEY`. Its policy allows only `s3:ListBucket` and
  `s3:GetBucketLocation` on the bucket, plus `s3:GetObject` on its objects. A write was tested and is
  refused.
