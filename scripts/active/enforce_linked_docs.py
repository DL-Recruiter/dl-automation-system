"""Enforce linked documentation updates for changed flow files."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

MANDATORY_DOC = "docs/progress.md"
LINKED_DOCS = {
    "System_SPEC.md",
    "docs/flows_easy_english.md",
    "docs/architecture_flows.md",
}


def get_changed_files(base: str, head: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", base, head],
        check=True,
        capture_output=True,
        text=True,
    )
    files = [line.strip().replace("\\", "/") for line in result.stdout.splitlines() if line.strip()]
    return sorted(set(files))


def is_canonical_flow_json(path: str) -> bool:
    if not path.startswith("flows/power-automate/unpacked/Workflows/"):
        return False
    if not path.endswith(".json"):
        return False
    return not path.endswith(".json.data.xml")


def validate_doc_linkage(changed_files: list[str]) -> tuple[bool, str]:
    changed_set = set(changed_files)
    changed_flows = sorted(path for path in changed_files if is_canonical_flow_json(path))

    if not changed_flows:
        return True, "No canonical flow JSON changes detected."

    if MANDATORY_DOC not in changed_set:
        return (
            False,
            "Canonical flow JSON changed but docs/progress.md was not updated.\n"
            f"Changed flow files:\n- " + "\n- ".join(changed_flows),
        )

    if not (changed_set & LINKED_DOCS):
        linked_doc_list = "\n- ".join(sorted(LINKED_DOCS))
        return (
            False,
            "Canonical flow JSON changed but no linked behavior documentation was updated.\n"
            "Update at least one linked doc:\n- "
            + linked_doc_list
            + "\nChanged flow files:\n- "
            + "\n- ".join(changed_flows),
        )

    return True, "Linked documentation requirements satisfied."


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, help="Base commit SHA/ref for diff.")
    parser.add_argument("--head", required=True, help="Head commit SHA/ref for diff.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        changed_files = get_changed_files(args.base, args.head)
    except subprocess.CalledProcessError as exc:
        print(exc.stderr.strip() or str(exc), file=sys.stderr)
        return 2

    ok, message = validate_doc_linkage(changed_files)
    if ok:
        print(message)
        return 0

    print(message, file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
