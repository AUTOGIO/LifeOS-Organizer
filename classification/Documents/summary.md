# Classification Summary — Documents (DRY RUN — proposal only)

- Classification ID: CLS-20260802-160151
- Source Inventory ID: INV-20260802-141128
- Timestamp: 2026-08-02T16:01:51-0300
- Total records: 463774
- Package directories excluded: 0

## Confidence breakdown
- High: 331495
- Medium: 42321
- Low: 89958

## By dimension
- duplicate-risk: 78634
- file-type: 128380
- project-grouping: 128380
- staleness: 128380

## Review queue
- 132279 record(s) require human review (Medium/Low tier). High-tier records may be proposed automatically but nothing is auto-applied — this project has no mutation phase yet.

## Warnings
- None

## Errors
- None

## Known limitations
- Duplicate-risk detection compares exact Name+SizeBytes only; fuzzy near-duplicate name matching (e.g. "file copy.ext", "file (1).ext") is not implemented in this version.
- Duplicate-risk comparison is scoped within this target only, per operator decision (DECISIONS.md D10).

---
Footer: Classification CLS-20260802-160151 is a read-only proposal. It does not authorize, stage, or perform any file move, rename, copy, delete, or tag.
