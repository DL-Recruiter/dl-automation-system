import importlib.util
import json
from pathlib import Path

import pytest

MODULE_PATH = Path("scripts/active/verify_flow_runs.py")
SPEC = importlib.util.spec_from_file_location("verify_flow_runs", MODULE_PATH)
verify_flow_runs = importlib.util.module_from_spec(SPEC)
assert SPEC is not None and SPEC.loader is not None
SPEC.loader.exec_module(verify_flow_runs)


class FakeResponse:
    def __init__(self, payload: dict):
        self._payload = payload

    def read(self) -> bytes:
        return json.dumps(self._payload).encode("utf-8")

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


def test_request_access_token_returns_access_token() -> None:
    def fake_open(request):
        assert request.get_method() == "POST"
        assert "oauth2/v2.0/token" in request.full_url
        return FakeResponse({"access_token": "token-123"})

    token = verify_flow_runs.request_access_token(
        tenant_id="tenant",
        client_id="client",
        client_secret="secret",
        opener=fake_open,
    )

    assert token == "token-123"


def test_fetch_and_summarize_runs_returns_required_fields() -> None:
    payload = {
        "value": [
            {
                "name": "run-1",
                "properties": {
                    "status": "Succeeded",
                    "startTime": "2026-02-27T00:00:00Z",
                    "endTime": "2026-02-27T00:01:00Z",
                    "trigger": {
                        "outputsLink": {
                            "uri": "https://example.local/trigger-output"
                        }
                    },
                    "outputsLink": {"uri": "https://example.local/outputs"},
                },
            }
        ]
    }

    def fake_open(request):
        assert request.get_method() == "GET"
        assert request.get_header("Authorization") == "Bearer token-abc"
        return FakeResponse(payload)

    response_payload = verify_flow_runs.fetch_run_history(
        access_token="token-abc",
        runs_url="https://management.azure.com/providers/Microsoft.ProcessSimple/environments/env/flows/flow/runs?api-version=2016-11-01",
        opener=fake_open,
    )
    summary = verify_flow_runs.summarize_runs(response_payload)

    assert summary == [
        {
            "name": "run-1",
            "status": "Succeeded",
            "startTime": "2026-02-27T00:00:00Z",
            "endTime": "2026-02-27T00:01:00Z",
            "triggerOutputsLink": {"uri": "https://example.local/trigger-output"},
            "outputsLink": {"uri": "https://example.local/outputs"},
        }
    ]


def test_build_runs_url_uses_explicit_override(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FLOW_VERIFY_RUNS_URL", "https://connector.internal/runs")

    assert verify_flow_runs.build_runs_url() == "https://connector.internal/runs"


def test_build_runs_url_for_composes_expected_arm_url() -> None:
    url = verify_flow_runs.build_runs_url_for(
        environment_id="env-123",
        flow_id="flow-456",
        base_url="https://management.azure.com/",
        api_version="2016-11-01",
    )

    assert (
        url
        == "https://management.azure.com/providers/Microsoft.ProcessSimple/environments/"
        "env-123/flows/flow-456/runs?api-version=2016-11-01"
    )
