#!/usr/bin/env python3
"""Read bounded local logs, including the capture that belongs to a selected insertion."""
import argparse
import json
import re
import sys
from pathlib import Path


def load_records(directory):
    candidates = []
    for path in directory.glob("events*.jsonl"):
        match = re.fullmatch(r"events(?:\.(\d+))?\.jsonl", path.name)
        if match:
            candidates.append((int(match.group(1) or 0), path))
    records, malformed = [], 0
    for _, path in sorted(candidates, reverse=True):
        try:
            with path.open(encoding="utf-8", errors="replace") as stream:
                for line in stream:
                    try:
                        item = json.loads(line)
                        if not isinstance(item, dict) or item.get("schemaVersion") != 1:
                            raise ValueError("unsupported record")
                        records.append(item)
                    except (ValueError, TypeError):
                        malformed += 1
        except FileNotFoundError:
            # A running app may rotate between listing and opening.
            continue
    return records, malformed


def for_operation(records, operation):
    operation = operation.lower()
    matching = [r for r in records if str(r.get("operationID", "")).lower() == operation]
    captures = {r.get("fields", {}).get("captureID") for r in matching} - {None}
    return [r for r in records if str(r.get("operationID", "")).lower() == operation
            or (r.get("operationID") is None and r.get("fields", {}).get("captureID") in captures)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=Path.home() / "Library/Logs/Prompt Injector")
    parser.add_argument("--last", type=int, default=80)
    parser.add_argument("--operation", help="Insertion operationID; also includes its capture events")
    parser.add_argument("--session", help="Process sessionID")
    parser.add_argument("--build", help="Exact buildID")
    parser.add_argument("--source", help="Source fingerprint prefix")
    parser.add_argument("--level", choices=["info", "warning", "error"])
    parser.add_argument("--json", action="store_true", help="Output JSONL")
    args = parser.parse_args()
    if not 1 <= args.last <= 10000:
        parser.error("--last must be between 1 and 10000")
    records, malformed = load_records(args.directory)
    if args.operation:
        records = for_operation(records, args.operation)
    if args.session:
        records = [r for r in records if str(r.get("sessionID", "")).lower() == args.session.lower()]
    if args.build:
        records = [r for r in records if r.get("build", {}).get("buildID") == args.build]
    if args.source:
        records = [r for r in records if r.get("build", {}).get("sourceFingerprint", "").startswith(args.source)]
    if args.level:
        records = [r for r in records if r.get("level") == args.level]
    if malformed:
        print(f"Skipped {malformed} incomplete/unsupported log lines; history may be incomplete.", file=sys.stderr)
    if not records:
        print("No matching logs. Launch the current built app and reproduce the operation first.", file=sys.stderr)
        return 1
    for item in records[-args.last:]:
        if args.json:
            print(json.dumps(item, ensure_ascii=False, separators=(",", ":")))
        else:
            build = item.get("build", {})
            print(f"{item.get('timestamp')} {item.get('level', '').upper():7} {item.get('event')} "
                  f"build={build.get('buildID')} source={build.get('sourceFingerprint', '')[:12]} "
                  f"session={item.get('sessionID')} op={item.get('operationID', '-')} "
                  f"{json.dumps(item.get('fields', {}), ensure_ascii=False)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
