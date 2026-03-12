"""Fail when canonical BGV flow JSON still contains hardcoded environment literals."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

BANNED_LITERALS = {
    "https://dlresourcespl88.sharepoint.com/sites/dlrespl": "old SharePoint site URL",
    "7b78dcaf-8744-478b-a40f-633ed7becff3": "source BGV_Candidates list ID",
    "4acba8e0-46aa-4007-b752-b4aa88fee7f7": "source BGV_Requests list ID",
    "f5248a99-fdf1-4660-946a-d54e00575a40": "source BGV_FormData list ID",
    "d411563f-2b1c-4fa5-90fc-ecc5f50941a1": "source BGV Records library ID",
    "sites/dlresourcespl88.sharepoint.com,a1e3e6dd-e1df-4fde-8716-956137c7d557,b823cd7e-ca43-4824-a574-6d84eea5cf94": "source Word template source ID",
    "b!3ebjod_h3k-HFpVhN8fVV37NI7hDyiRIpXRthO6lz5Q_VhHUHCulT5D87MX1CUGh": "source Word template drive ID",
    "016SGZG5PNMCLLHQOWHRFJZTFJ5JG55C7V": "source Word template file ID",
    "cHRZOFNHGkaDf62MFIYLIq9-liquOypMpApm-AyRSqVUNlVFTjhUNjNWOTI4SEsxTVc0V1ZSV1o3Qi4u": "blue Form 1 ID",
    "cHRZOFNHGkaDf62MFIYLIq9-liquOypMpApm-AyRSqVUN1c5NE0wWEI2Nk1OMDlJSkI0N0RXUTRHMS4u": "blue Form 2 ID",
    "4475a565-7f2b-4df1-91cd-c8e3df8f805a": "production Teams group ID",
    "19:01523cb936ce49fca3e80d2ee293da6a@thread.tacv2": "production Teams channel ID",
    "recruitmentops@dlresources.com.sg": "production shared mailbox",
    "dlresplmain@dlresources.com.sg": "production employer fallback mailbox",
    "https://bgv-docx-parser-cshnd7aucchwfmfz.southeastasia-01.azurewebsites.net/api/parseauthorizationcontrols": "hardcoded Azure Function endpoint",
    "code=": "hardcoded Azure Function query key",
}

REQUIRED_TOKENS = {
    "__BGV_SPO_SITE_URL__",
    "__BGV_LIST_CANDIDATES_ID__",
    "__BGV_LIST_REQUESTS_ID__",
    "__BGV_LIST_FORMDATA_ID__",
    "__BGV_LIBRARY_RECORDS_ID__",
    "__BGV_AUTH_TEMPLATE_SOURCE__",
    "__BGV_AUTH_TEMPLATE_DRIVE_ID__",
    "__BGV_AUTH_TEMPLATE_FILE_ID__",
    "__BGV_FORM1_ID__",
    "__BGV_FORM2_ID__",
    "__BGV_SHARED_MAILBOX_ADDRESS__",
    "__BGV_INTERNAL_ALERT_TO__",
    "__BGV_EMPLOYER_FALLBACK_TO__",
    "__BGV_TEAMS_GROUP_ID__",
    "__BGV_TEAMS_CHANNEL_ID__",
    "__BGV_DOCX_PARSER_URI__",
}


def iter_flow_files(repo_root: Path) -> list[Path]:
    canonical_dir = repo_root / "flows" / "power-automate" / "unpacked" / "Workflows"
    return sorted(
        path for path in canonical_dir.glob("*.json") if not path.name.endswith(".json.data.xml")
    )


def validate_portability(repo_root: Path) -> tuple[bool, str]:
    hits: list[str] = []
    combined_text_parts: list[str] = []

    for path in iter_flow_files(repo_root):
        text = path.read_text(encoding="utf-8")
        combined_text_parts.append(text)
        for literal, label in BANNED_LITERALS.items():
            if literal in text:
                hits.append(f"{path.as_posix()}: {label}")

    if hits:
        return False, "Hardcoded portability literals remain:\n- " + "\n- ".join(hits)

    combined_text = "\n".join(combined_text_parts)
    missing_tokens = sorted(token for token in REQUIRED_TOKENS if token not in combined_text)
    if missing_tokens:
        return False, "Required portability tokens missing:\n- " + "\n- ".join(missing_tokens)

    return True, "Canonical BGV flow JSON is portability-tokenized."


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=".",
        help="Repository root containing flows/power-automate/unpacked/Workflows.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    ok, message = validate_portability(Path(args.repo_root).resolve())
    stream = sys.stdout if ok else sys.stderr
    print(message, file=stream)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
