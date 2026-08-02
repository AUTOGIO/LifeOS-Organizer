# Classification Design (Metadata-Before-AI Phase)

**Status: DESIGN ONLY. No classification script exists or has run. Nothing in this document has been executed against user files or against the inventory metadata beyond read-only analysis to produce grounded examples.**

This document does not authorize implementation. Per the operator's instruction, work stops after this design for approval before any classification output is generated or any code is written.

## Scope

- **In scope:** the 6 already-validated local targets — Documents, Desktop, Downloads, Pictures, Movies, Music (`DECISIONS.md` D7).
- **Explicitly excluded:** CloudStorage (D8) and Volumes. Neither is touched by this phase.
- **Input:** only the already-published `inventory/<Target>/metadata.csv` / `metadata.json` artifacts. This phase never re-scans the filesystem — it reads the frozen, validated snapshot that inventory already produced.
- **Governance.** This phase implements Charter principle 2 ("Metadata before AI") and stays entirely inside principle 3 ("Read-only before remediation"). Principle 4 ("Human approval before mutation") means classification output is a *proposal artifact*, never an action.

## 1. Category model

Four dimensions, each derived only from columns already present in `metadata.csv`/`metadata.json` (`RelativePath`, `Name`, `Extension`, `SizeBytes`, `CreationDate`, `ModificationDate`, `AccessDate`, `IsDirectory`, `IsPackage`). No new metadata collection, no content read, no hashing.

| Dimension | Derivation | Example (real, from current inventory) |
|---|---|---|
| **Project/workspace grouping** | Top-level segment of `RelativePath` under a target, treated as a candidate workspace boundary. | `Documents/GitHub` → 145,209 entries, 159.9 GB — a single top-level folder holding effectively all of Documents' size. |
| **File type/extension** | `Extension` column, mapped to a small label set (source-code, document, image, archive, build-artifact, other) via a static lookup table. | Documents' top extensions: `svg` (17,136), `py` (17,124), `xml` (13,991), `[none]` (13,702), `pyc` (4,088) — overwhelmingly source-code, consistent with the GitHub grouping above. |
| **Age/staleness** | Bucket on `ModificationDate`: `<30d`, `30-180d`, `180-365d`, `1-2y`, `2y+`. | Downloads: 52 files `<30d`, 1 file in `180-365d`. |
| **Size & duplicate-risk signals** | (a) `SizeBytes` outliers (top-N largest, already computed by inventory). (b) Candidate duplicates: exact `(Name, SizeBytes)` match, 2+ occurrences. This is a **name+size heuristic, not a hash comparison** — no hash column exists yet, so this dimension can only ever produce *candidates* for review, never a confirmed duplicate. | Documents: 4 files named `data 2.v1`, each exactly 25,769,803,776 bytes, under `GitHub/{LitoralPriceTracker,System_Org 2,MacHealthOS,CodexCheatSheet}/.build/out/CompilationCache.noindex/...` — independent projects' build caches, identical size by construction. |

A record may carry labels from more than one dimension (e.g. a file is simultaneously "source-code," "in the GitHub workspace," and "a duplicate-risk candidate").

## 2. Confidence thresholds and review rules

| Tier | Definition | Rule |
|---|---|---|
| **High** | Deterministic pattern match with low ambiguity: known build/cache path patterns (`.build/`, `node_modules/`, `.venv/`, `DerivedData/`, `CompilationCache.noindex/`), exact `(Name, SizeBytes)` match across ≥2 independent top-level projects, or an unambiguous extension→type mapping. | May be **proposed automatically** — i.e. the pipeline generates the label without a human in the loop for that specific record. This does **not** mean auto-applied; nothing in this phase applies anything (see below). |
| **Medium** | Name-pattern match with a size mismatch (e.g. `eduardo.pdf` vs. `eduardo copy.pdf` — 616,525 vs. 3,991,831 bytes: same naming convention, different content), near-identical size with near-identical name (`Detalhe processo.pdf` vs. `1Detalhe processo.pdf` — 342,826 vs. 343,061 bytes, 235-byte difference), or a staleness bucket boundary case on a small sample. | **Requires human review** before the label is considered final. Held in a separate "needs review" bucket in the output, not merged into the high-confidence list. |
| **Low** | Ambiguous top-level grouping (e.g. `.openclaw` vs. `.openclaw 2` — same apparent project, unclear if duplicate workspace or intentional fork), single-occurrence signals, or conflicting dimension labels on the same record. | **Requires human review.** Lowest priority for review queue ordering, but never silently dropped or auto-resolved. |

**Hard rule, independent of tier:** no classification output, at any confidence level, triggers, stages, or queues a file move, rename, copy, delete, or tag write. This phase produces read-only proposal records only. That constraint is structural (see pipeline design below), not just documented — the classification pipeline has no code path that opens a write handle to anything outside its own `classification/` output tree.

## 3. Metadata-only classification pipeline design

Mirrors the inventory engine's proven pattern (`SYSTEM_ARCHITECTURE.md`, D1/D7) rather than inventing a new one:

```
inventory/<Target>/metadata.csv|json   Read-only input (already validated, already published)
        │
scripts/lib/classification_engine.zsh   (proposed) shared logic: load → normalize → apply
        │                                dimension rules → score confidence → stage → validate → publish
classification/<Target>/                New, separate output tree — never overwrites inventory/
        │
classification_proposal.csv/.json + summary.md + reports/1N_<target>_classification.txt
```

Key design constraints:

1. **No filesystem access.** The pipeline reads `metadata.csv`/`metadata.json` only. It never calls `find`, `stat`, or `mdls` against the live filesystem — that already happened in the inventory phase and is out of scope here. This is what makes "metadata-only" a structural guarantee rather than a policy statement.
2. **Traceable to source.** Every classification record carries a `SourceInventoryID` field citing the exact inventory run it was derived from (e.g. `INV-20260802-141128` for Documents), plus its own `ClassificationID` (`CLS-YYYYMMDD-HHMMSS`, same collision-safe format as `DECISIONS.md` D4). If the underlying inventory is ever re-run, old classification output is traceably stale, not silently reused.
3. **Staged write + validate + atomic publish**, identical pattern to D1: write to a `mktemp -d` staging directory, validate (row-count parity, ID consistency, confidence tier is one of the three defined values, no record references a path outside the target's own tree), then atomic `mv`. A failed validation leaves any prior classification output untouched.
4. **Execution lock**, identical pattern to D5/D6: one classification run per target at a time.
5. **Separate output tree.** `classification/<Target>/` is new and distinct from `inventory/<Target>/`. Nothing here is ever written back into the inventory artifacts.

Proposed per-record schema:

```
ClassificationID, SourceInventoryID, TargetName, FullPath, RelativePath,
Dimension, ProposedLabel, ConfidenceTier, ConfidenceReason, RequiresReview
```

## 4. Example proposed outputs for review

**Illustrative only — no script has generated these. Hand-derived from the real, already-published inventory metadata to show what the pipeline's output would look like.**

| Dimension | Path(s) | Proposed label | Tier | Reason |
|---|---|---|---|---|
| Size / duplicate-risk | 4 files named `data 2.v1`, 25,769,803,776 bytes each, under `GitHub/{LitoralPriceTracker,System_Org 2,MacHealthOS,CodexCheatSheet}/.build/out/CompilationCache.noindex/...` | `regeneratable-build-artifact` | **High** | Known build-cache path pattern + exact size match across 4 independent project trees. |
| Project grouping | `Documents/GitHub` (145,209 entries, 159.9 GB) | `source-code-workspace:GitHub` | **High** | Single unambiguous top-level folder; internal extension mix (svg/py/xml/pyc) confirms source-code, not documents. |
| Size / duplicate-risk | `Downloads/eduardo.pdf` (616,525 B) vs. `Downloads/eduardo copy.pdf` (3,991,831 B) | `possible-duplicate-candidate` | **Medium** | Name pattern (`X` vs. `X copy`) matches, but size differs by ~6.5x — likely a different or revised document, not a true duplicate. Needs a human look. |
| Size / duplicate-risk | `Downloads/tati/Detalhe processo.pdf` (342,826 B) vs. `Downloads/tati/1Detalhe processo.pdf` (343,061 B) | `possible-near-duplicate` | **Medium** | Near-identical name and size (235-byte difference). Could be a duplicate with a metadata-only difference, or two distinct versions. |
| Project grouping | `Documents/.openclaw` (52 entries, 126,135 B) vs. `Documents/.openclaw 2` (49 entries, 107,595 B) | `possible-duplicate-workspace` | **Low** | Same apparent project name, different entry counts and sizes. Ambiguous — could be an intentional fork, not a duplicate. |
| Age/staleness | `Downloads/*` — 1 file in the `180-365d` bucket against 52 in `<30d` | `stale-download-candidate` | **Medium** | Single old outlier in an otherwise fresh folder; small sample size, worth a glance rather than a confident label. |

## 5. Safety and rollback plan (for a future mutation phase — not requested, not scoped, not approved)

Classification itself never mutates anything — this section exists because the Charter's success criteria for the project as a whole include "guarantees rollback capability for future organization tasks," and that's easier to honor if considered now rather than retrofitted later. None of this is being requested for approval; it's a placeholder design so a future mutation-phase conversation doesn't start from zero.

If a future phase ever proposes acting on classification output (move, rename, tag), it would need, before any code runs:

1. A separate `DECISIONS.md` entry with explicit operator approval — per Charter principle 4, classification output alone is never sufficient authorization.
2. A rollback ledger written *before* the first action in any batch: `{ClassificationID, OriginalFullPath, ProposedNewPath, Timestamp, ApprovalRecordRef}` for every proposed action, so a revert script can restore original paths deterministically.
3. Dry-run as the default mode; an explicit flag (e.g. `--apply`) required to perform any real action, and even then gated by the staged-execute pattern already proven in D1.
4. No deletion capability, ever, during this project (`docs/SAFETY_RULES.md` rule 5 — permanent, not a phase boundary).
5. Full action logging (`docs/SAFETY_RULES.md` rule 6).

## 6. Implementation plan (not started)

1. **Schema sign-off** — finalize the classification record schema and `ClassificationID` format above. Needs operator confirmation before any code.
2. **Build the pipeline** — `scripts/lib/classification_engine.zsh` (mirrors D7's shared-library pattern) plus one wrapper per target, reading only `inventory/<Target>/metadata.csv`.
3. **Dry run on the smallest target first** — Downloads (53 files) — small enough to manually audit every proposed row by hand before trusting the pipeline on Documents' 128k+ rows.
4. **Review the dry run together** — calibrate thresholds against real false-positive/false-negative examples, the same way D7's engine was verified against real runs before being trusted.
5. **Extend to the remaining local targets** — one at a time, with the same rule-of-three discipline used in D7 (clone/prove first, refactor only once evidence justifies it), unless the Downloads dry run already gives enough confidence to parameterize immediately — that call gets made after step 4, not before.

Explicit stop point: no step above begins until this design is approved.

## 7. Policy defaults (resolved 2026-08-02, `DECISIONS.md` D10)

- **Staleness thresholds are target-specific**, not a single calendar bucket set: Downloads 30/90/180 days; Documents and Desktop 180/365/730 days; Pictures, Movies, and Music receive no staleness dimension by default.
- **Duplicate-risk comparison stays within each target only** for this phase. No cross-target comparison (e.g. the same file present in both Documents and Downloads is not linked).
- **Package directories are excluded by default** from classification output, since their internals were never inventoried (pruned at scan time).

Implementation status: `scripts/lib/classification_engine.zsh` + `scripts/10_downloads_classification.zsh` built for Downloads, logic-verified against real data. See `DECISIONS.md` D10 for the verification method and a bug found and fixed before reaching the operator.
