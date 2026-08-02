#!/bin/zsh
# LifeOS Organizer — Task 04
# Metadata-only inventory for the configured Desktop target.
# This script never opens user documents or follows symlinks.
# Cloned from the validated scripts/03_documents_inventory.zsh (see DECISIONS.md
# D1-D6) after that pattern was proven end-to-end on 2026-08-02.

# Classification uses expected false tests (for example, "is this a directory?").
# Keep unset-variable and pipeline safeguards without treating those tests as fatal.
set -uo pipefail

PROJECT_DIR='/Users/eduardofgiovannini/Documents/GitHub/LifeOS-Organizer'
CONFIG_PATH="$PROJECT_DIR/config/inventory_targets.yaml"
TEMPLATE_PATH="$PROJECT_DIR/templates/inventory_report_template.md"
TARGET_NAME='Desktop'
OUTPUT_DIR="$PROJECT_DIR/inventory/$TARGET_NAME"
CSV_PATH="$OUTPUT_DIR/metadata.csv"
JSON_PATH="$OUTPUT_DIR/metadata.json"
SUMMARY_PATH="$OUTPUT_DIR/summary.md"
REPORT_PATH="$PROJECT_DIR/reports/04_desktop_inventory.txt"
# Execution lock: prevents concurrent Task 04 runs from writing to shared
# output paths. Same pattern as Task 03 (see DECISIONS.md D5/D6), applied
# here from the start rather than retrofitted after an incident.
LOCK_DIR="$PROJECT_DIR/logs/.task04.lock"
# Spotlight enrichment is optional and disabled by default to keep large inventories bounded.
# Run COLLECT_SPOTLIGHT=1 ./scripts/04_desktop_inventory.zsh only when separately approved.
COLLECT_SPOTLIGHT="${COLLECT_SPOTLIGHT:-0}"

section() {
  print -- "## $1"
  print
}

csv_escape() {
  local value="$1"
  value=${value//\"/\"\"}
  print -rn -- "\"$value\""
}

json_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  print -rn -- "$value"
}

is_package_path() {
  local path="$1"
  [[ -d "$path" ]] || return 1
  case "${path:l}" in
    *.app|*.bundle|*.framework|*.kext|*.pages|*.numbers|*.key|*.photo\ library|*.sparsebundle) return 0 ;;
    *) return 1 ;;
  esac
}

emit_csv_row() {
  local field
  local -a fields
  fields=("$@")
  for (( field = 1; field <= ${#fields}; field++ )); do
    (( field > 1 )) && print -n -- ',' >&3
    csv_escape "${fields[$field]}" >&3
  done
  print >&3
}

emit_json_row() {
  local separator="$1"
  shift
  local -a keys values
  keys=(InventoryID FullPath RelativePath Name Extension IsDirectory IsPackage IsHidden IsSymlink Owner Group Permissions SizeBytes CreationDate ModificationDate AccessDate SpotlightContentType SpotlightKind)
  values=("$@")
  print -n -- "$separator{" >&4
  local index
  for (( index = 1; index <= ${#keys}; index++ )); do
    (( index > 1 )) && print -n -- ',' >&4
    print -n -- "\"${keys[$index]}\":\"" >&4
    json_escape "${values[$index]}" >&4
    print -n -- "\"" >&4
  done
  print -n -- '}' >&4
}

print_ranked_entries() {
  local title="$1"
  local limit="$2"
  local source_name="$3"
  local -A seen
  local candidate best best_value value
  local iteration=0
  local -a candidates

  if [[ "$source_name" == 'files' ]]; then
    candidates=("${(@k)file_sizes}")
  else
    candidates=("${(@k)directory_sizes}")
  fi

  print -- "### $title"
  if (( ${#candidates} == 0 )); then
    print -- '- None'
    print
    return
  fi

  while (( iteration < limit )); do
    best=''
    best_value=-1
    for candidate in $candidates; do
      if [[ -n "${seen[$candidate]:-}" ]]; then
        continue
      fi
      if [[ "$source_name" == 'files' ]]; then
        value=${file_sizes[$candidate]}
      else
        value=${directory_sizes[$candidate]}
      fi
      if (( value > best_value )); then
        best="$candidate"
        best_value=$value
      fi
    done
    if [[ -z "$best" ]]; then
      break
    fi
    print -- "- ${best_value} bytes — $best"
    seen[$best]=1
    ((iteration += 1))
  done
  print
}

print_top_extensions() {
  local -A seen
  local candidate best best_value value
  local iteration=0
  local -a candidates=("${(@k)extension_counts}")
  print -- '## Extension Summary'
  if (( ${#candidates} == 0 )); then
    print -- '- None'
    print
    return
  fi
  while (( iteration < 25 )); do
    best=''
    best_value=-1
    for candidate in $candidates; do
      if [[ -n "${seen[$candidate]:-}" ]]; then
        continue
      fi
      value=${extension_counts[$candidate]}
      if (( value > best_value )); then
        best="$candidate"
        best_value=$value
      fi
    done
    if [[ -z "$best" ]]; then
      break
    fi
    print -- "- $best: $best_value"
    seen[$best]=1
    ((iteration += 1))
  done
  print
}

if [[ "$(/bin/pwd -P)" != "$PROJECT_DIR" ]]; then
  print -u2 -- "ERROR: Run this script from $PROJECT_DIR"
  exit 1
fi

if [[ ! -f "$CONFIG_PATH" || ! -f "$TEMPLATE_PATH" || ! -d "$OUTPUT_DIR" ]]; then
  print -u2 -- 'ERROR: Inventory framework prerequisites are missing.'
  exit 1
fi

TARGET_PATH="$(/usr/bin/awk '
  $0 == "Desktop:" { found=1; next }
  found && $1 == "path:" { print substr($0, index($0, ":") + 2); exit }
  found && /^[^[:space:]]/ { exit }
' "$CONFIG_PATH")"

if [[ -z "$TARGET_PATH" || ! -d "$TARGET_PATH" ]]; then
  print -u2 -- 'ERROR: Configured Desktop target is unavailable.'
  exit 1
fi

# Acquire the execution lock before touching any shared state. mkdir is
# atomic on the local filesystem, so this is race-free across concurrent
# invocations. A stale lock (holder PID no longer alive) is reclaimed;
# a live lock causes an immediate, non-destructive abort.
if ! /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
  holder_pid=''
  [[ -f "$LOCK_DIR/pid" ]] && holder_pid="$(<"$LOCK_DIR/pid")"
  if [[ -n "$holder_pid" ]] && /bin/kill -0 "$holder_pid" 2>/dev/null; then
    print -u2 -- "ERROR: Another Task 04 run (PID $holder_pid) holds the execution lock ($LOCK_DIR). Refusing to run concurrently. Let it finish or terminate it first."
    exit 1
  fi
  print -u2 -- "WARNING: Reclaiming stale execution lock (holder PID '${holder_pid:-unknown}' not running)."
  /bin/rm -rf "$LOCK_DIR"
  /bin/mkdir "$LOCK_DIR" || { print -u2 -- 'ERROR: Cannot acquire execution lock.'; exit 1; }
fi
print -- "$$" > "$LOCK_DIR/pid"

# Generated once per run; includes time-of-day so same-day reruns never
# collide (see DECISIONS.md D4 — same fix as Task 03, applied here from the start).
INVENTORY_ID="INV-$(/bin/date '+%Y%m%d')-$(/bin/date '+%H%M%S')"
RUN_DIR="$(/usr/bin/mktemp -d "$OUTPUT_DIR/.task04.XXXXXX")" || { /bin/rm -rf "$LOCK_DIR"; print -u2 -- 'ERROR: Cannot create repository-local staging directory.'; exit 1; }
CSV_PATH="$RUN_DIR/metadata.csv"
JSON_PATH="$RUN_DIR/metadata.json"
SUMMARY_PATH="$RUN_DIR/summary.md"
REPORT_PATH="$RUN_DIR/04_desktop_inventory.txt"
cleanup() { /bin/rm -rf "$RUN_DIR" "$LOCK_DIR"; }
trap cleanup EXIT HUP INT TERM

START_EPOCH=$(/bin/date +%s)
TIMESTAMP=$(/bin/date '+%Y-%m-%dT%H:%M:%S%z')
warnings=0
errors=0
spotlight_warning_recorded=0
typeset -i total_files=0 total_directories=0 hidden_count=0 package_count=0 symlink_count=0 total_size=0
typeset -A extension_counts file_sizes directory_sizes

print -- 'InventoryID,FullPath,RelativePath,Name,Extension,IsDirectory,IsPackage,IsHidden,IsSymlink,Owner,Group,Permissions,SizeBytes,CreationDate,ModificationDate,AccessDate,SpotlightContentType,SpotlightKind' > "$CSV_PATH"
print -- '[' > "$JSON_PATH"
exec 3>> "$CSV_PATH"
exec 4>> "$JSON_PATH"
json_separator=''

# -x prevents crossing mounts. Package directories are emitted once and pruned.
# stat receives batches of paths from find, avoiding one process per entry.
while IFS=$'\x1f' read -r item item_type owner group permissions size_bytes creation_date modification_date access_date; do
  if [[ "$size_bytes" != <-> ]]; then
    ((errors += 1))
    continue
  fi
  relative="${item#$TARGET_PATH/}"
  [[ "$item" == "$TARGET_PATH" ]] && relative='.'
  name="${item:t}"
  extension='[none]'
  if [[ "$name" != .* && "$name" == *.* ]]; then
    extension="${name##*.}"
  fi

  is_directory='false'
  [[ "$item_type" == 'Directory' ]] && is_directory='true'
  is_package='false'
  if is_package_path "$item"; then
    is_package='true'
    ((package_count += 1))
  fi
  is_hidden='false'
  [[ "$relative" == .* || "$relative" == */.* ]] && is_hidden='true'
  [[ "$is_hidden" == 'true' ]] && ((hidden_count += 1))
  is_symlink='false'
  [[ "$item_type" == 'Symbolic Link' ]] && is_symlink='true'
  [[ "$is_symlink" == 'true' ]] && ((symlink_count += 1))

  spotlight_type=''
  spotlight_kind=''
  if [[ "$COLLECT_SPOTLIGHT" == '1' && -x /usr/bin/mdls ]]; then
    # Retrieve both optional Spotlight fields in one metadata-only query.
    spotlight_values="$(/usr/bin/mdls -raw -name kMDItemContentType -name kMDItemKind -- "$item" 2>/dev/null || true)"
    spotlight_lines=("${(@f)spotlight_values}")
    spotlight_type="${spotlight_lines[1]:-}"
    spotlight_kind="${spotlight_lines[2]:-}"
    [[ "$spotlight_type" == '(null)' ]] && spotlight_type=''
    [[ "$spotlight_kind" == '(null)' ]] && spotlight_kind=''
  elif (( spotlight_warning_recorded == 0 )); then
    # Blank values are valid where optional Spotlight metadata was not collected.
    ((warnings += 1))
    spotlight_warning_recorded=1
  fi

  emit_csv_row "$INVENTORY_ID" "$item" "$relative" "$name" "$extension" "$is_directory" "$is_package" "$is_hidden" "$is_symlink" "$owner" "$group" "$permissions" "$size_bytes" "$creation_date" "$modification_date" "$access_date" "$spotlight_type" "$spotlight_kind"
  emit_json_row "$json_separator" "$INVENTORY_ID" "$item" "$relative" "$name" "$extension" "$is_directory" "$is_package" "$is_hidden" "$is_symlink" "$owner" "$group" "$permissions" "$size_bytes" "$creation_date" "$modification_date" "$access_date" "$spotlight_type" "$spotlight_kind"
  json_separator=$'\n,'

  if [[ "$is_directory" == 'true' ]]; then
    ((total_directories += 1))
    directory_sizes[$item]=${directory_sizes[$item]:-0}
  else
    ((total_files += 1))
    total_size=$(( total_size + size_bytes ))
    extension_counts[$extension]=$(( ${extension_counts[$extension]:-0} + 1 ))
    file_sizes[$item]=$size_bytes
    # Aggregate file sizes into every ancestor directory without a second tree scan.
    parent="${item:h}"
    while [[ "$parent" == "$TARGET_PATH" || "$parent" == "$TARGET_PATH"/* ]]; do
      directory_sizes[$parent]=$(( ${directory_sizes[$parent]:-0} + size_bytes ))
      [[ "$parent" == "$TARGET_PATH" ]] && break
      parent="${parent:h}"
    done
  fi
done < <(/usr/bin/find "$TARGET_PATH" -xdev \( -type d \( -name '*.app' -o -name '*.bundle' -o -name '*.framework' -o -name '*.kext' -o -name '*.pages' -o -name '*.numbers' -o -name '*.key' -o -name '*.photo library' -o -name '*.sparsebundle' \) -prune -o -exec /usr/bin/stat -f $'%N\x1f%HT\x1f%Su\x1f%Sg\x1f%Sp\x1f%z\x1f%SB\x1f%Sm\x1f%Sa' -t '%Y-%m-%dT%H:%M:%S%z' {} + \))

print >&4
print -- ']' >&4
exec 3>&-
exec 4>&-
END_EPOCH=$(/bin/date +%s)
RUNTIME=$(( END_EPOCH - START_EPOCH ))

{
  print -- '# LifeOS Organizer Inventory Report'
  print
  section 'Metadata'
  print -- "- Inventory ID: $INVENTORY_ID"
  print -- "- Timestamp: $TIMESTAMP"
  print -- "- Engine: Task 04 Desktop metadata inventory"
  print
  section 'Folder Path'
  print -- "$TARGET_PATH"
  print
  section 'Scan Time'
  print -- "${RUNTIME} seconds"
  print
  section 'Folder Statistics'
  print -- "- Total files: $total_files"
  print -- "- Total directories: $total_directories"
  print -- "- Total size (regular non-directory entries): $total_size bytes"
  print -- "- Hidden entries: $hidden_count"
  print -- "- Package directories: $package_count"
  print -- "- Symlinks: $symlink_count"
  print
  print_top_extensions
  print_ranked_entries 'Largest Files' 20 files
  print_ranked_entries 'Largest Directories' 20 directories
  section 'Age Summary'
  print -- 'Creation, modification, and access timestamps are present per entry in metadata.csv and metadata.json.'
  print
  section 'Notes'
  print -- '- Filesystem metadata was collected. Spotlight fields are present but blank unless optional enrichment is enabled.'
  print -- '- Package directories were recorded but not descended into.'
  print
  section 'Warnings'
  if (( warnings == 0 )); then print -- '- None'; else print -- "- $warnings optional metadata lookup warning(s)."; fi
  print
  section 'Errors'
  if (( errors == 0 )); then print -- '- None'; else print -- "- $errors entry metadata collection error(s)."; fi
  print
  section 'Observations'
  print -- '- This is metadata-only inventory; no document content was opened, parsed, summarized, or OCR-processed.'
  print
  print -- '---'
  print -- "Footer: Inventory $INVENTORY_ID is read-only and does not authorize file changes."
} > "$SUMMARY_PATH"

{
  print -- 'LifeOS Organizer — Desktop Metadata Inventory'
  print -- "Inventory ID: $INVENTORY_ID"
  print -- "Timestamp: $TIMESTAMP"
  print -- "Target: $TARGET_PATH"
  print -- "Runtime: ${RUNTIME} seconds"
  print
  print -- 'Collected: filesystem path, name, extension, type flags, ownership, permissions, size, timestamps, and optional Spotlight type/kind fields.'
  print -- 'Intentionally not collected: document contents, OCR output, document summaries, previews, hashes, duplicate analysis, or semantic classifications.'
  print -- "Files: $total_files"
  print -- "Directories: $total_directories"
  print -- "Total size: $total_size bytes"
  print -- "Warnings: $warnings"
  print -- "Errors: $errors"
  print -- 'Safety result: no user files were modified, moved, renamed, deleted, copied, or opened for content inspection.'
} > "$REPORT_PATH"

if ! /usr/bin/python3 - "$CSV_PATH" "$JSON_PATH" "$SUMMARY_PATH" "$REPORT_PATH" "$INVENTORY_ID" <<'PY'
import csv, json, re, sys
csv_path, json_path, summary_path, report_path, inventory_id = sys.argv[1:]
if not re.fullmatch(r"INV-\d{8}-\d{6}", inventory_id):
    raise SystemExit("Invalid Inventory ID format")
with open(csv_path, newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
with open(json_path, encoding="utf-8") as handle:
    records = json.load(handle)
if len(rows) != len(records):
    raise SystemExit(f"CSV/JSON row mismatch: {len(rows)} != {len(records)}")
if any(row.get("InventoryID") != inventory_id for row in rows):
    raise SystemExit("CSV contains an inconsistent Inventory ID")
if any(record.get("InventoryID") != inventory_id for record in records):
    raise SystemExit("JSON contains an inconsistent Inventory ID")
for path in (summary_path, report_path):
    if inventory_id not in open(path, encoding="utf-8").read():
        raise SystemExit(f"Missing Inventory ID in {path}")
PY
then
  print -u2 -- 'ERROR: Staged artifact validation failed; existing artifacts were preserved.'
  exit 1
fi

/bin/mv "$CSV_PATH" "$OUTPUT_DIR/metadata.csv" || exit 1
/bin/mv "$JSON_PATH" "$OUTPUT_DIR/metadata.json" || exit 1
/bin/mv "$SUMMARY_PATH" "$OUTPUT_DIR/summary.md" || exit 1
/bin/mv "$REPORT_PATH" "$PROJECT_DIR/reports/04_desktop_inventory.txt" || exit 1
print -- "Completed $INVENTORY_ID: $total_files files, $total_directories directories, $total_size bytes."
