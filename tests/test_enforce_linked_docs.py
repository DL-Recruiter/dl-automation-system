import importlib.util
from pathlib import Path

MODULE_PATH = Path("scripts/active/enforce_linked_docs.py")
SPEC = importlib.util.spec_from_file_location("enforce_linked_docs", MODULE_PATH)
enforce_linked_docs = importlib.util.module_from_spec(SPEC)
assert SPEC is not None and SPEC.loader is not None
SPEC.loader.exec_module(enforce_linked_docs)


def test_validate_doc_linkage_passes_without_flow_changes() -> None:
    ok, message = enforce_linked_docs.validate_doc_linkage(
        ["docs/progress.md", "scripts/active/verify_flow_runs.py"]
    )

    assert ok is True
    assert "No canonical flow JSON changes detected." in message


def test_validate_doc_linkage_fails_when_progress_missing() -> None:
    ok, message = enforce_linked_docs.validate_doc_linkage(
        [
            "flows/power-automate/unpacked/Workflows/BGV_5_Response1-AAA.json",
            "docs/flows_easy_english.md",
        ]
    )

    assert ok is False
    assert "docs/progress.md was not updated" in message


def test_validate_doc_linkage_fails_when_linked_doc_missing() -> None:
    ok, message = enforce_linked_docs.validate_doc_linkage(
        [
            "flows/power-automate/unpacked/Workflows/BGV_5_Response1-AAA.json",
            "docs/progress.md",
        ]
    )

    assert ok is False
    assert "no linked behavior documentation was updated" in message


def test_validate_doc_linkage_passes_with_required_docs() -> None:
    ok, message = enforce_linked_docs.validate_doc_linkage(
        [
            "flows/power-automate/unpacked/Workflows/BGV_5_Response1-AAA.json",
            "docs/progress.md",
            "docs/flows_easy_english.md",
        ]
    )

    assert ok is True
    assert "requirements satisfied" in message
