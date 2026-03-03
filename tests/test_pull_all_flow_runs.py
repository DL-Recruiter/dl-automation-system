import importlib.util
import sys
from pathlib import Path

import pytest

MODULE_PATH = Path("scripts/active/pull_all_flow_runs.py")
sys.path.insert(0, str(MODULE_PATH.parent.resolve()))
SPEC = importlib.util.spec_from_file_location("pull_all_flow_runs", MODULE_PATH)
pull_all_flow_runs = importlib.util.module_from_spec(SPEC)
assert SPEC is not None and SPEC.loader is not None
SPEC.loader.exec_module(pull_all_flow_runs)


def test_discover_flows_reads_canonical_json_files(tmp_path: Path) -> None:
    workflows_dir = tmp_path / "Workflows"
    workflows_dir.mkdir()
    (workflows_dir / "BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json").write_text(
        "{}", encoding="utf-8"
    )
    (workflows_dir / "BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json.data.xml").write_text(
        "<xml/>", encoding="utf-8"
    )
    (workflows_dir / "notes.txt").write_text("ignored", encoding="utf-8")

    flows = pull_all_flow_runs.discover_flows(workflows_dir)

    assert len(flows) == 1
    assert flows[0]["flowName"] == "BGV_0_CandidateDeclaration"
    assert flows[0]["flowId"] == "8c1238c7-e4f1-f011-8406-002248582037"


def test_append_top_query_adds_top_parameter() -> None:
    runs_url = (
        "https://management.azure.com/providers/Microsoft.ProcessSimple/environments/"
        "env/flows/flow/runs?api-version=2016-11-01"
    )

    updated = pull_all_flow_runs.append_top_query(runs_url, 10)

    assert "$top=10" in updated
    assert "api-version=2016-11-01" in updated


def test_parse_top_env_rejects_non_integer() -> None:
    with pytest.raises(pull_all_flow_runs.PullAllRunsError):
        pull_all_flow_runs.parse_top_env("abc")
