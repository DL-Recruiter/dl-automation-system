"""Verify Power Automate flow runs via ARM or connector endpoint."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Callable

TOKEN_SCOPE_DEFAULT = "https://management.azure.com/.default"
API_VERSION_DEFAULT = "2016-11-01"
BASE_URL_DEFAULT = "https://management.azure.com"

Opener = Callable[[urllib.request.Request], Any]


class VerificationError(RuntimeError):
    """Raised when verification cannot proceed."""


def load_dotenv_if_present(path: str = ".env") -> None:
    env_path = Path(path)
    if not env_path.exists():
        return

    for line in env_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def require_env(var_name: str) -> str:
    value = os.getenv(var_name)
    if value:
        return value
    raise VerificationError(f"Missing required environment variable: {var_name}")


def _urlopen(request: urllib.request.Request) -> Any:
    return urllib.request.urlopen(request, timeout=30)


def request_access_token(
    tenant_id: str,
    client_id: str,
    client_secret: str,
    scope: str = TOKEN_SCOPE_DEFAULT,
    opener: Opener = _urlopen,
) -> str:
    token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
    payload = urllib.parse.urlencode(
        {
            "client_id": client_id,
            "client_secret": client_secret,
            "scope": scope,
            "grant_type": "client_credentials",
        }
    ).encode("utf-8")

    request = urllib.request.Request(
        token_url,
        data=payload,
        method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )

    try:
        with opener(request) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise VerificationError(f"Token request failed ({exc.code}): {detail}") from exc

    token = body.get("access_token")
    if not token:
        raise VerificationError("Token response missing access_token.")
    return token


def build_runs_url() -> str:
    explicit_url = os.getenv("FLOW_VERIFY_RUNS_URL")
    if explicit_url:
        return explicit_url

    base_url = os.getenv("FLOW_VERIFY_BASE_URL", BASE_URL_DEFAULT).rstrip("/")
    environment_id = require_env("FLOW_VERIFY_ENVIRONMENT_ID")
    flow_id = require_env("FLOW_VERIFY_FLOW_ID")
    api_version = os.getenv("FLOW_VERIFY_API_VERSION", API_VERSION_DEFAULT)

    return (
        f"{base_url}/providers/Microsoft.ProcessSimple/environments/"
        f"{environment_id}/flows/{flow_id}/runs?api-version={api_version}"
    )


def fetch_run_history(access_token: str, runs_url: str, opener: Opener = _urlopen) -> dict[str, Any]:
    request = urllib.request.Request(
        runs_url,
        method="GET",
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
        },
    )

    try:
        with opener(request) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise VerificationError(f"Run-history request failed ({exc.code}): {detail}") from exc


def normalize_run_entry(run_entry: dict[str, Any]) -> dict[str, Any]:
    properties = run_entry.get("properties", {})
    trigger = properties.get("trigger", {})

    return {
        "name": run_entry.get("name"),
        "status": properties.get("status"),
        "startTime": properties.get("startTime"),
        "endTime": properties.get("endTime"),
        "triggerOutputsLink": trigger.get("outputsLink"),
        "outputsLink": properties.get("outputsLink"),
    }


def summarize_runs(payload: dict[str, Any]) -> list[dict[str, Any]]:
    runs = payload.get("value", [])
    if not isinstance(runs, list):
        raise VerificationError("Run-history response field 'value' must be a list.")
    return [normalize_run_entry(item) for item in runs]


def main() -> int:
    try:
        load_dotenv_if_present()

        tenant_id = require_env("FLOW_VERIFY_TENANT_ID")
        client_id = require_env("FLOW_VERIFY_CLIENT_ID")
        client_secret = require_env("FLOW_VERIFY_CLIENT_SECRET")
        scope = os.getenv("FLOW_VERIFY_SCOPE", TOKEN_SCOPE_DEFAULT)

        token = request_access_token(
            tenant_id=tenant_id,
            client_id=client_id,
            client_secret=client_secret,
            scope=scope,
        )

        runs_url = build_runs_url()
        payload = fetch_run_history(token, runs_url)
        summary = summarize_runs(payload)

        print(json.dumps({"runsUrl": runs_url, "runCount": len(summary), "runs": summary}, indent=2))
        return 0
    except VerificationError as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
