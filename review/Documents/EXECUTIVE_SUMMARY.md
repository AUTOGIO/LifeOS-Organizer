# Documents Classification Triage — Executive Summary

- Triage ID: TRG-20260802-161240
- Source Classification ID: CLS-20260802-160151
- Source Inventory ID: INV-20260802-141128
- Timestamp: 2026-08-02T16:12:40-0300
- Total classified files triaged: 128380
- Total size represented: 161,007,433,747 bytes

This is a read-only re-organization of the existing Documents classification proposal (`classification/Documents/`) into five priority batches for human review. No file was moved, renamed, tagged, copied, deleted, or modified. No filesystem rescan occurred — input was the already-published classification and inventory artifacts only.

## Batches

### Batch 1: High-confidence regeneratable build/cache artifacts

- Record count: 8,997
- Total size: 146,553,591,983 bytes
- Why prioritized: Deterministic path-pattern match (.build/, CompilationCache.noindex, etc.) plus exact size match across independent project trees. Largest, safest, most impactful signal — these are structurally regeneratable build outputs, not user data.
- Confidence tier(s) present: High
- Human review mandatory: No (may be proposed automatically; nothing auto-applies)
- Representative examples:
  - 25,769,803,776 bytes — /Users/eduardofgiovannini/Documents/GitHub/LitoralPriceTracker/.build/out/CompilationCache.noindex/generic/v1.1/data 2.v1 (regeneratable-build-artifact)
  - 25,769,803,776 bytes — /Users/eduardofgiovannini/Documents/GitHub/CodexCheatSheet/.build/out/CompilationCache.noindex/generic/v1.1/data 2.v1 (regeneratable-build-artifact)
  - 25,769,803,776 bytes — /Users/eduardofgiovannini/Documents/GitHub/MacHealthOS/.build/out/CompilationCache.noindex/generic/v1.1/data 2.v1 (regeneratable-build-artifact)
  - 25,769,803,776 bytes — /Users/eduardofgiovannini/Documents/GitHub/System_Org 2/.build/out/CompilationCache.noindex/generic/v1.1/data 2.v1 (regeneratable-build-artifact)
  - 12,884,901,888 bytes — /Users/eduardofgiovannini/Documents/GitHub/LitoralPriceTracker/.build/out/CompilationCache.noindex/generic/v1.1/index 2.v1 (regeneratable-build-artifact)
- Recommended next action: No individual review needed to *identify* these — the pattern match is reliable. Read-only for now: no deletion or regeneration action is authorized in this phase. Worth a future, separately-approved proposal once a remediation phase exists.

### Batch 2: Largest files (top 50 by size, not already in batch 1)

- Record count: 50
- Total size: 8,619,602,903 bytes
- Why prioritized: Highest absolute size impact on disk regardless of classification label. Reviewing the largest items first gives the fastest read on where space actually goes, independent of any heuristic.
- Confidence tier(s) present: High/Low/Medium
- Human review mandatory: No (may be proposed automatically; nothing auto-applies)
- Representative examples:
  - 5,402,049,443 bytes — /Users/eduardofgiovannini/Documents/GitHub/LifeOS-Organizer/logs/03_documents_inventory_debug.log (largest-file)
  - 299,326,765 bytes — /Users/eduardofgiovannini/Documents/GitHub/fulofilo-analytics/.git/objects/pack/pack-34024e2d4dab4e6434fbae4a75a991400bd846f0.pack (largest-file)
  - 280,946,058 bytes — /Users/eduardofgiovannini/Documents/FACTORY_PROJECTS/PRINT_2026_2027_DESERTO_ENCANTADO.zip (largest-file)
  - 169,664,771 bytes — /Users/eduardofgiovannini/Documents/FACTORY_PROJECTS/PRINT_2026_2027_DESERTO_ENCANTADO/09_EXPORT/PRINT_2026_2027_FACTORY_PACKAGE.zip (largest-file)
  - 157,328,184 bytes — /Users/eduardofgiovannini/Documents/GitHub/financas-2026/src/nfce/notas/nfce.pdf (largest-file)
- Recommended next action: Manually skim the top 10-20 by size to confirm nothing here is unexpectedly user-critical (e.g. a real document that happens to be huge) before any future space-reclamation discussion.

### Batch 3: Exact name+size duplicate-risk candidates (non-build)

- Record count: 42,317
- Total size: 724,998,881 bytes
- Why prioritized: Exact Name+SizeBytes match outside a recognized build-cache pattern — the strongest true "these might be the same file" signal this pipeline can produce without content hashing (see RISK_REGISTER R8).
- Confidence tier(s) present: Medium
- Human review mandatory: Yes
- Representative examples:
  - 10,071,888 bytes — /Users/eduardofgiovannini/Documents/GitHub/ipad-stream-deck-console/backups/stream-deck_2026-07-11_16-53-21/StreamDeck/Plugins/me.hckr.appswitcher.sdPlugin/Plugin (possible-duplicate-candidate)
  - 10,071,888 bytes — /Users/eduardofgiovannini/Documents/GitHub/ipad-stream-deck-console/backups/rollback-current-streamdeck_2026-07-26_17-00-00/Plugins/me.hckr.appswitcher.sdPlugin/Plugin (possible-duplicate-candidate)
  - 10,071,888 bytes — /Users/eduardofgiovannini/Documents/GitHub/ipad-stream-deck-console/backups/stream-deck_2026-07-26_16-57-50/StreamDeck/Plugins/me.hckr.appswitcher.sdPlugin/Plugin (possible-duplicate-candidate)
  - 10,071,888 bytes — /Users/eduardofgiovannini/Documents/GitHub/ipad-stream-deck-console/backups/stream-deck_2026-07-11_17-22-31/StreamDeck/Plugins/me.hckr.appswitcher.sdPlugin/Plugin (possible-duplicate-candidate)
  - 8,037,635 bytes — /Users/eduardofgiovannini/Documents/FACTORY_PROJECTS/PRINT_2026_001_CORAL_BREEZE/03_MASTER_ARTWORK/abacaxi.png (possible-duplicate-candidate)
- Recommended next action: Spot-check a sample per RISK_REGISTER R8 — name+size match is a candidate, not proof. A human should open/compare a few pairs before treating any as a confirmed duplicate.

### Batch 4: Medium-confidence duplicate (weak signal) and stale-file candidates

- Record count: 16,920
- Total size: 955,547,782 bytes
- Why prioritized: Weaker duplicate signal (same name, different size — possibly different revisions) plus files whose ModificationDate places them in the stale/very-stale staleness buckets for this target's thresholds.
- Confidence tier(s) present: High/Low
- Human review mandatory: Yes
- Representative examples:
  - 14,189,012 bytes — /Users/eduardofgiovannini/Documents/FACTORY_PROJECTS/PRINT_2026_2027_DESERTO_ENCANTADO/08_FACTORY_PACKAGE/10_VECTOR_AND_REPEAT/artwork_PRINT_READY_300dpi.png (same-name-different-size)
  - 13,055,399 bytes — /Users/eduardofgiovannini/Documents/FACTORY_PROJECTS/PRINT_2026_2027_SUNSET_PALETTE/08_FACTORY_PACKAGE/10_VECTOR_AND_REPEAT/seamless_repeat_3x3_300dpi.png (same-name-different-size)
  - 12,203,655 bytes — /Users/eduardofgiovannini/Documents/FACTORY_PROJECTS/PRINT_2026_001_CORAL_BREEZE/08_FACTORY_PACKAGE/10_VECTOR_AND_REPEAT/seamless_repeat_2x2_300dpi.png (same-name-different-size)
  - 11,026,872 bytes — /Users/eduardofgiovannini/Documents/GitHub/fulofilo-analytics/macos/FuloFiloTerminal/.build/x86_64-apple-macosx/debug/ModuleCache/LHSV4NGLAOUE/AppKit-2VI8NB39I5AT6.pcm (same-name-different-size)
  - 10,089,994 bytes — /Users/eduardofgiovannini/Documents/FACTORY_PROJECTS/PRINT_2026_2027_CACTUS_CANVAS/08_FACTORY_PACKAGE/10_VECTOR_AND_REPEAT/seamless_repeat_2x2_300dpi.png (same-name-different-size)
- Recommended next action: Lower urgency than batch 3. Weak-duplicate entries and stale files are worth a periodic glance, not immediate triage.

### Batch 5: Low-confidence or ambiguous records

- Record count: 60,096
- Total size: 4,153,692,198 bytes
- Why prioritized: No actionable classification signal beyond a plain file-type or project-grouping label (often an unrecognized extension). Lowest priority; safe to review last or skip.
- Confidence tier(s) present: High/Low
- Human review mandatory: Yes
- Representative examples:
  - 15,689,296 bytes — /Users/eduardofgiovannini/Documents/GitHub/fulofilo-analytics/.venv/lib/python3.12/site-packages/pyarrow/libarrow_compute.2400 2.dylib (unclassified-type)
  - 15,689,296 bytes — /Users/eduardofgiovannini/Documents/GitHub/fulofilo-analytics/.venv/lib/python3.12/site-packages/pyarrow/libarrow_compute.2400.dylib (unclassified-type)
  - 15,458,551 bytes — /Users/eduardofgiovannini/Documents/GitHub/LitoralPriceTracker/data/raw/NOTAS_LITORAL/NFCE_20260720032352.txt (document)
  - 15,274,032 bytes — /Users/eduardofgiovannini/Documents/GitHub/ItaliaOS/.derivedData/SDKStatCaches.noindex/macosx27.0-26A5378i-45874285e5972fffeae925c4ab065928.sdkstatcache (unclassified-type)
  - 15,274,032 bytes — /Users/eduardofgiovannini/Documents/GitHub/WorkflowSuggesterPro/.build/out/SDKStatCaches.noindex/macosx27.0-26A5378i-a0facfad118c1a7a18f0aad9463f654945874285e5972fffeae925c4ab065928 2.sdkstatcache (unclassified-type)
- Recommended next action: Skim only if time permits. Consider whether the file-type lookup table should be extended if a common extension keeps appearing here.

## Largest directories (context, not individually triaged — directories aren't classified)

- 161,007,433,747 bytes — /Users/eduardofgiovannini/Documents
- 159,938,889,570 bytes — /Users/eduardofgiovannini/Documents/GitHub
- 40,294,091,085 bytes — /Users/eduardofgiovannini/Documents/GitHub/LitoralPriceTracker
- 40,183,516,604 bytes — /Users/eduardofgiovannini/Documents/GitHub/System_Org 2
- 40,035,554,881 bytes — /Users/eduardofgiovannini/Documents/GitHub/System_Org 2/.build
- 40,035,449,102 bytes — /Users/eduardofgiovannini/Documents/GitHub/System_Org 2/.build/out
- 40,020,326,798 bytes — /Users/eduardofgiovannini/Documents/GitHub/MacHealthOS
- 40,012,925,037 bytes — /Users/eduardofgiovannini/Documents/GitHub/MacHealthOS/.build
- 40,012,814,288 bytes — /Users/eduardofgiovannini/Documents/GitHub/MacHealthOS/.build/out
- 39,927,308,567 bytes — /Users/eduardofgiovannini/Documents/GitHub/LitoralPriceTracker/.build

## Validation

- Batch record counts sum to 128,380 (expected 128,380, the full classified-file count).
- Every assignment's FullPath, SourceClassificationID, and SourceInventoryID were cross-checked against the published `classification/Documents/classification_proposal.csv` and `inventory/Documents/metadata.csv` — see the embedded validation gate for the automated check.

---
Footer: Triage TRG-20260802-161240 is a read-only re-prioritization. It does not authorize, stage, or perform any file move, rename, copy, delete, or tag.
