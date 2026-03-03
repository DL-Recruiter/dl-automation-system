"""Pull run history for all canonical Power Automate workflows."""

from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

import verify_flow_runs

WORKFLOWS_DIR_DEFAULT = Path("flows/power-automate/unpacked/Workflows")
REPORT_PATH_DEFAULT = Path("out/flow_run_history_latest.json")
FLOW_FILE_PATTERN = re.compile(
    r"^(?P<name>.+)-(?P<id>[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12})\.json$"
)


class PullAllRunsError(RuntimeError):
    """Raised when pull-all flow run verification cannot proceed."""


def discover_flows(workflows_dir: Path) -> list[dict[str, str]]:
    if not workflows_dir.exists():
        raise PullAllRunsError(f"Canonical workflows directory does not exist: {workflows_dir}")

    flows: list[dict[str, str]] = []
    for path in sorted(workflows_dir.glob("*.json")):
        match = FLOW_FILE_PATTERN.match(path.name)
        if not match:
            continue
        flows.append(
            {
                "flowName": match.group("name"),
                "flowId": match.group("id").lower(),
                "path": str(path),
            }
        )

    if not flows:
        raise PullAllRunsError(f"No canonical workflow JSON files found in: {workflows_dir}")
    return flows


def append_top_query(runs_url: str, top: int | None) -> str:
    if top is None:
        return runs_url

    parsed = urlparse(runs_url)
    query = dict(parse_qsl(parsed.query, keep_blank_values=True))
    query["$top"] = str(top)
    return urlunparse(parsed._replace(query=urlencode(query)))


def parse_top_env(raw_value: str | None) -> int | None:
    if not raw_value:
        return None
    try:
        parsed = int(raw_value)
    except ValueError as exc:
        raise PullAllRunsError("FLOW_VERIFY_TOP must be an integer when provided.") from exc
    if parsed <= 0:
        raise PullAllRunsError("FLOW_VERIFY_TOP must be greater than zero.")
    return parsed


def now_utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def main() -> int:
    verify_flow_runs.load_dotenv_if_present()
    try:
        tenant_id = verify_flow_runs.require_env("FLOW_VERIFY_TENANT_ID")
        client_id = verify_flow_runs.require_env("FLOW_VERIFY_CLIENT_ID")
        client_secret = verify_flow_runs.require_env("FLOW_VERIFY_CLIENT_SECRET")
        environment_id = verify_flow_runs.require_env("FLOW_VERIFY_ENVIRONMENT_ID")
        scope = os.getenv("FLOW_VERIFY_SCOPE", verify_flow_runs.TOKEN_SCOPE_DEFAULT)
        base_url = os.getenv("FLOW_VERIFY_BASE_URL", verify_flow_runs.BASE_URL_DEFAULT)
        api_version = os.getenv("FLOW_VERIFY_API_VERSION", verify_flow_runs.API_VERSION_DEFAULT)
        workflows_dir = Path(os.getenv("FLOW_VERIFY_CANONICAL_DIR", str(WORKFLOWS_DIR_DEFAULT)))
        report_path = Path(os.getenv("FLOW_VERIFY_REPORT_PATH", str(REPORT_PATH_DEFAULT)))
        top = parse_top_env(os.getenv("FLOW_VERIFY_TOP"))

        flows = discover_flows(workflows_dir)
        token = verify_flow_runs.request_access_token(
            tenant_id=tenant_id,
            client_id=client_id,
            client_secret=client_secret,
            scope=scope,
        )

        results: list[dict[str, object]] = []
        failed_count = 0
        for flow in flows:
            runs_url = verify_flow_runs.build_runs_url_for(
                environment_id=environment_id,
                flow_id=flow["flowId"],
                base_url=base_url,
                api_version=api_version,
            )
            runs_url = append_top_query(runs_url, top)
            entry: dict[str, object] = {
                "flowName": flow["flowName"],
                "flowId": flow["flowId"],
                "path": flow["path"],
                "runsUrl": runs_url,
            }

            try:
                payload = verify_flow_runs.fetch_run_history(token, runs_url)
                runs = verify_flow_runs.summarize_runs(payload)
                entry["runCount"] = len(runs)
                entry["runs"] = runs
            except verify_flow_runs.VerificationError as exc:
                failed_count += 1
                entry["error"] = str(exc)
                entry["runCount"] = 0
                entry["runs"] = []

            results.append(entry)

        report = {
            "generatedAtUtc": now_utc_iso(),
            "environmentId": environment_id,
            "flowCount": len(results),
            "failedFlowCount": failed_count,
            "flows": results,
        }
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(
            json.dumps(
                {
                    "reportPath": str(report_path),
                    "flowCount": len(results),
                    "failedFlowCount": failed_count,
                },
                indent=2,
            )
        )
        return 0 if failed_count == 0 else 2
    except (PullAllRunsError, verify_flow_runs.VerificationError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
