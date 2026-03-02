import json
from pathlib import Path


def test_connection_fixture_covers_expected_api_names() -> None:
    fixture_path = Path('tests/fixtures/connections.mock.json')
    payload = json.loads(fixture_path.read_text(encoding='utf-8'))

    connector_api_names = {connector['apiName'] for connector in payload['connectors']}

    assert 'shared_flowrunops' in connector_api_names
    assert 'new_flowrunops' in connector_api_names


def test_flow_fixture_has_required_connections() -> None:
    fixture_path = Path('tests/fixtures/connections.mock.json')
    payload = json.loads(fixture_path.read_text(encoding='utf-8'))

    flow_map = {flow['name']: flow for flow in payload['flows']}

    main_api_names = {item['apiName'] for item in flow_map['main']['connections']}
    exporter_api_names = {item['apiName'] for item in flow_map['FlowRunLogs exporter']['connections']}

    assert 'shared_sharepointonline' in main_api_names
    assert {'shared_flowrunops', 'shared_sharepointonline'}.issubset(exporter_api_names)
