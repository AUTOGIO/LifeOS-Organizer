#!/bin/zsh
# Read-only macOS and project baseline. Writes only the report inside this project.

set -euo pipefail

PROJECT_DIR='/Users/eduardofgiovannini/Documents/GitHub/LifeOS-Organizer'
REPORT_PATH="$PROJECT_DIR/reports/01_environment_baseline.txt"
LOCK_DIR="$PROJECT_DIR/logs/.task01.lock"

if [[ "$(/bin/pwd -P)" != "$PROJECT_DIR" ]]; then
  print -u2 -- "ERROR: Run this script from $PROJECT_DIR"
  exit 1
fi

# Execution lock (mirrors scripts/03_documents_inventory.zsh, added after the
# 2026-08-02 concurrency incident — see DECISIONS.md D5). mkdir is atomic; a
# stale lock (holder PID no longer alive) is reclaimed automatically.
if ! /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
  holder_pid=''
  [[ -f "$LOCK_DIR/pid" ]] && holder_pid="$(<"$LOCK_DIR/pid")"
  if [[ -n "$holder_pid" ]] && /bin/kill -0 "$holder_pid" 2>/dev/null; then
    print -u2 -- "ERROR: Another Task 01 run (PID $holder_pid) holds the execution lock ($LOCK_DIR)."
    exit 1
  fi
  /bin/rm -rf "$LOCK_DIR"
  /bin/mkdir "$LOCK_DIR" || { print -u2 -- 'ERROR: Cannot acquire execution lock.'; exit 1; }
fi
print -- "$$" > "$LOCK_DIR/pid"
trap '/bin/rm -rf "$LOCK_DIR"' EXIT HUP INT TERM

print_section() {
  print
  print -- "=============================================================================="
  print -- "$1"
  print -- "=============================================================================="
}

print_value() {
  print -- "$1: $2"
}

optional_command() {
  if [[ -x "$1" ]]; then
    shift
    "$@" 2>&1 || print -- "Unavailable or returned a non-zero status."
  else
    print -- "Unavailable: $1"
  fi
}

list_immediate_names() {
  local target="$1"
  if [[ -d "$target" ]]; then
    (
      cd "$target"
      /bin/ls -1A 2>&1 || true
    )
  else
    print -- "Path does not exist."
  fi
}

path_status() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    print -- "EXISTS  $target"
  else
    print -- "MISSING  $target"
  fi
}

exec > "$REPORT_PATH" 2>&1

print -- "LifeOS Organizer — Environment and Safety Baseline"
print -- "Project: $PROJECT_DIR"
print -- "Read-only collection; generated report only."

print_section "CURRENT CONTEXT"
print_value "Current date and timezone" "$(/bin/date '+%Y-%m-%d %H:%M:%S %Z (%z)')"
print_value "Current username" "$(/usr/bin/id -un)"
print_value "Current home directory" "$HOME"
print_value "Computer name" "$(/usr/sbin/scutil --get ComputerName 2>/dev/null || print -- 'Unavailable')"
print_value "Hostname" "$(/bin/hostname 2>/dev/null || print -- 'Unavailable')"
print_value "Shell" "${SHELL:-Unavailable}"
print_value "Current project path" "$(/bin/pwd -P)"

print_section "MACOS AND HARDWARE"
optional_command /usr/bin/sw_vers /usr/bin/sw_vers
optional_command /usr/sbin/system_profiler /usr/sbin/system_profiler SPHardwareDataType

print_section "DISK AND MOUNTED-VOLUME OVERVIEW"
optional_command /bin/df /bin/df -h
print
print -- "diskutil list:"
optional_command /usr/sbin/diskutil /usr/sbin/diskutil list
print
print -- "Available capacity on home volume:"
optional_command /bin/df /bin/df -h "$HOME"

print_section "REQUIRED PATH EXISTENCE"
path_status '/Users/eduardofgiovannini/Desktop'
path_status '/Users/eduardofgiovannini/Documents'
path_status '/Users/eduardofgiovannini/Downloads'
path_status '/Users/eduardofgiovannini/Pictures'
path_status '/Users/eduardofgiovannini/Movies'
path_status '/Users/eduardofgiovannini/Music'
path_status '/Users/eduardofgiovannini/Library/CloudStorage'
path_status '/Users/eduardofgiovannini/Library/Mobile Documents'
path_status '/Volumes'

print_section "IMMEDIATE NAMES: /Users/eduardofgiovannini/Documents"
list_immediate_names '/Users/eduardofgiovannini/Documents'

print_section "IMMEDIATE NAMES: /Users/eduardofgiovannini/Library/CloudStorage"
list_immediate_names '/Users/eduardofgiovannini/Library/CloudStorage'

print_section "IMMEDIATE NAMES: /Volumes"
list_immediate_names '/Volumes'

print_section "COMPLETION"
print -- "Baseline collection complete. No existing user file was modified by this script."
