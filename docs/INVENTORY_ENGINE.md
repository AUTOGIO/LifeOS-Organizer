# Inventory Engine

## Architecture

The engine separates target definitions, report structure, target staging directories, and readiness validation. This makes each future inventory use the same controlled foundation.

## Configuration file

`config/inventory_targets.yaml` is the single list of approved target locations. Each target has a stable name and macOS path. Adding an approved target later requires changing only this configuration and creating its matching `inventory/` directory.

## Templates

`templates/inventory_report_template.md` defines the required report format for all future inventory output. Reports must use this format so results remain comparable and reviewable.

## Inventory folders

`inventory/` contains one staging directory per supported target: Documents, Desktop, Downloads, Pictures, Movies, Music, CloudStorage, and Volumes. These directories establish scope; they do not contain copied user files.

## Future reuse

Future tasks first run `scripts/02_inventory_engine.zsh` to confirm readiness. A separately approved read-only inventory script can then select a configured target, collect permitted metadata, and write a report using the shared template. No inventory action is authorized by this engine alone.
