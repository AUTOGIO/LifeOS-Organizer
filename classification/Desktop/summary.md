# Classification Summary — Desktop (DRY RUN — proposal only)

- Classification ID: CLS-20260802-160130
- Source Inventory ID: INV-20260802-141614
- Timestamp: 2026-08-02T16:01:30-0300
- Total records: 312
- Package directories excluded: 0

## Confidence breakdown
- High: 265
- Medium: 5
- Low: 42

## By dimension
- duplicate-risk: 15
- file-type: 99
- project-grouping: 99
- staleness: 99

## Review queue
- 47 record(s) require human review (Medium/Low tier). High-tier records may be proposed automatically but nothing is auto-applied — this project has no mutation phase yet.

## Warnings
- None

## Errors
- None

## Known limitations
- Duplicate-risk detection compares exact Name+SizeBytes only; fuzzy near-duplicate name matching (e.g. "file copy.ext", "file (1).ext") is not implemented in this version.
- Duplicate-risk comparison is scoped within this target only, per operator decision (DECISIONS.md D10).

---
Footer: Classification CLS-20260802-160130 is a read-only proposal. It does not authorize, stage, or perform any file move, rename, copy, delete, or tag.
