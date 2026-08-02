# Pictures Package-Pruning Fix — Proposal (Assessment Only)

**Status: NOT IMPLEMENTED. No code has been changed. Pictures has not been re-inventoried or re-classified. This document is for approval before any of that happens.**

## The problem, quantified

`is_package_path()` and both `find -prune` expressions in `scripts/lib/inventory_engine.zsh` (D2) prune `*.photo\ library` (with a space — an older bundle-naming convention) but not `*.photoslibrary` (the actual modern Photos Library package extension, no space). Checked against the real, already-published `inventory/Pictures/metadata.csv`:

- **8,964 of Pictures' 8,982 total rows (99.8%) are the internals of one directory**: `Photos Library.photoslibrary`.
- Of those, 8,643 are files and 321 are directories — none flagged `IsPackage=true`, confirming the prune pattern never matched.
- Pictures' entire inventory report — 8,656 files, 326 directories — is therefore almost entirely one package's internal structure (`database/Photos.sqlite`, thumbnail caches, etc.), not a meaningful survey of the user's actual picture files. The real, non-package content of Pictures is roughly 13 files and 5 directories.
- Confirmed via `grep` across all 5 other local targets' `metadata.csv`: zero rows mention `.photoslibrary` anywhere else. The code lives in the shared engine (affects all future scans of any target), but the practical impact today is Pictures-only.

## Smallest safe change

Three one-line, purely additive edits — extend three existing OR-lists, remove nothing, restructure nothing:

1. `is_package_path()` case pattern (`scripts/lib/inventory_engine.zsh` line 49): add `*.photoslibrary` alongside the existing `*.photo\ library`.
2. The pre-scan entry-count `find -prune` expression (line 274, safe-mode vanish-tracking from D10): add `-o -name '*.photoslibrary'`.
3. The main scan `find -prune` expression (line 352): add `-o -name '*.photoslibrary'`.

All three must change together — they currently list the same eight patterns in the same order; if only one or two were updated, the three prune points would disagree with each other, which is exactly the kind of inconsistency this project's existing patterns were designed to avoid.

## Affected scope

- **Code:** shared engine (`scripts/lib/inventory_engine.zsh`), so every future run of any of the 6 local target wrappers (03-08) picks up the fix, not just Pictures'.
- **Practical/data impact today:** Pictures only — confirmed zero `.photoslibrary` occurrences in Documents, Desktop, Downloads, Movies, or Music.
- **Already-published artifacts are untouched by the code change alone.** `inventory/Pictures/metadata.csv`/`.json`/`summary.md` and the Pictures report keep reflecting the old (un-pruned) scan until Pictures is explicitly re-run.

## Does Pictures need to be re-inventoried? Yes — and there's a downstream chain

The fix only changes *future* scans. To get corrected data:

1. **Re-run Task 06** (`./scripts/06_pictures_inventory.zsh`). Expected result: file count drops from 8,656 to roughly 13, directory count from 326 to roughly 5, plus exactly one new package entry (`IsPackage=true`) for `Photos Library.photoslibrary` itself. A new `InventoryID` is generated, as with any run.
2. **Task 14 (Pictures classification) becomes stale the moment step 1 completes.** Its published `SourceInventoryID` would no longer match Pictures' current inventory. The classification engine's own validation gate (D10) would catch this as a hard mismatch if triage or any future step tried to cross-reference them — so this isn't a silent-drift risk, but Task 14 should be **re-run** (`./scripts/14_pictures_classification.zsh`) right after step 1 to keep the two in sync. Expect Pictures' classification output to shrink by roughly the same ~99% the inventory does — nearly all of its current 17,323 classification records exist only because the package's internals were individually classified.
3. **No triage exists for Pictures today**, so there's no third link in this chain to re-run.

## Validation plan (if approved)

1. `bash -n` on the modified library (same pre-existing zsh-only `<->` false positive noted every time; no new syntax errors expected).
2. Confirm the new pattern's specificity before trusting it at scale: `*.photoslibrary` requires an exact suffix match on the full entry name — same glob semantics as the existing `*.sparsebundle` pattern already in production use. Not a substring match, so it can't accidentally prune something like `myphotoslibrary-notes.txt`.
3. Operator runs Task 06 (Pictures inventory) on the real Mac. Confirm via the completion line and the published report: file/directory counts drop as predicted, `package_count` increases by exactly 1, and the built-in validation gate (row-count parity, consistent `InventoryID`) passes as it does for every run.
4. **Spot-check one other target unaffected in practice** (e.g. re-run Desktop, the smallest) to confirm zero behavioral change where `.photoslibrary` doesn't exist — due diligence on a shared-engine edit, consistent with how D10/D11 changes were verified before being trusted broadly.
5. Operator re-runs Task 14 (Pictures classification) against the corrected inventory. Confirm its `SourceInventoryID` now matches Pictures' new `InventoryID`, and that its own validation gate passes.
6. Update `DECISIONS.md`, `CHANGELOG.md`, `RISK_REGISTER.md`, `SYSTEM_ARCHITECTURE.md` (D2's original description) the same way every other engine change in this project has been documented.

## What this proposal does not do

- It does not touch any user file. It changes what the *inventory scanner* records about one package directory, nothing else.
- It does not implement anything yet. No line of `scripts/lib/inventory_engine.zsh` has been edited.
- It does not re-run Task 06 or Task 14. Both wait for explicit approval.
- It does not affect CloudStorage or Volumes — out of scope for this proposal, as instructed.
