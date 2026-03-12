import importlib.util
from pathlib import Path

MODULE_PATH = Path("scripts/active/check_bgv_portability.py")
SPEC = importlib.util.spec_from_file_location("check_bgv_portability", MODULE_PATH)
check_bgv_portability = importlib.util.module_from_spec(SPEC)
assert SPEC is not None and SPEC.loader is not None
SPEC.loader.exec_module(check_bgv_portability)


def test_validate_portability_detects_banned_literal(tmp_path: Path) -> None:
    flow_dir = tmp_path / "flows" / "power-automate" / "unpacked" / "Workflows"
    flow_dir.mkdir(parents=True)
    (flow_dir / "BGV_Test.json").write_text(
        '{"dataset":"https://dlresourcespl88.sharepoint.com/sites/dlrespl"}',
        encoding="utf-8",
    )

    ok, message = check_bgv_portability.validate_portability(tmp_path)

    assert ok is False
    assert "old SharePoint site URL" in message


def test_validate_portability_detects_missing_tokens(tmp_path: Path) -> None:
    flow_dir = tmp_path / "flows" / "power-automate" / "unpacked" / "Workflows"
    flow_dir.mkdir(parents=True)
    (flow_dir / "BGV_Test.json").write_text('{"dataset":"clean"}', encoding="utf-8")

    ok, message = check_bgv_portability.validate_portability(tmp_path)

    assert ok is False
    assert "__BGV_SPO_SITE_URL__" in message


def test_validate_portability_passes_for_tokenized_solution(tmp_path: Path) -> None:
    flow_dir = tmp_path / "flows" / "power-automate" / "unpacked" / "Workflows"
    flow_dir.mkdir(parents=True)
    joined_tokens = " ".join(sorted(check_bgv_portability.REQUIRED_TOKENS))
    (flow_dir / "BGV_Test.json").write_text(joined_tokens, encoding="utf-8")

    ok, message = check_bgv_portability.validate_portability(tmp_path)

    assert ok is True
    assert "portability-tokenized" in message
