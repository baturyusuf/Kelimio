#!/usr/bin/env python3
"""Upload an existing signed AAB to Google Play's internal track.

The Google Play Developer API can update only an app that already exists in
Play Console and has received its first AAB manually.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

SCOPE = "https://www.googleapis.com/auth/androidpublisher"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package-name", required=True)
    parser.add_argument("--aab", required=True, type=Path)
    parser.add_argument(
        "--service-account",
        type=Path,
        default=(
            Path(os.environ["PLAY_SERVICE_ACCOUNT_JSON"])
            if os.environ.get("PLAY_SERVICE_ACCOUNT_JSON")
            else None
        ),
    )
    parser.add_argument("--track", default="internal")
    parser.add_argument("--status", default="completed", choices=["draft", "inProgress", "halted", "completed"])
    parser.add_argument("--release-name")
    parser.add_argument("--notes-tr", default="Kelimio dahili test sürümü.")
    parser.add_argument("--notes-en", default="Kelimio internal test release.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.aab.is_file():
        raise SystemExit(f"AAB not found: {args.aab}")
    if args.service_account is None or not args.service_account.is_file():
        raise SystemExit(
            "Provide --service-account or PLAY_SERVICE_ACCOUNT_JSON. "
            "Do not commit the service-account file."
        )
    if args.package_name == "com.kelimio.app":
        raise SystemExit("The scaffold package name must not be uploaded to Google Play.")

    credentials = service_account.Credentials.from_service_account_file(
        str(args.service_account),
        scopes=[SCOPE],
    )
    publisher = build(
        "androidpublisher",
        "v3",
        credentials=credentials,
        cache_discovery=False,
    )
    edit_id: str | None = None
    try:
        edit = publisher.edits().insert(
            packageName=args.package_name,
            body={},
        ).execute()
        edit_id = edit["id"]

        uploaded = publisher.edits().bundles().upload(
            packageName=args.package_name,
            editId=edit_id,
            media_body=MediaFileUpload(
                str(args.aab),
                mimetype="application/octet-stream",
                resumable=True,
            ),
        ).execute()
        version_code = str(uploaded["versionCode"])

        release: dict[str, object] = {
            "status": args.status,
            "versionCodes": [version_code],
            "releaseNotes": [
                {"language": "tr-TR", "text": args.notes_tr[:500]},
                {"language": "en-US", "text": args.notes_en[:500]},
            ],
        }
        if args.release_name:
            release["name"] = args.release_name[:50]

        publisher.edits().tracks().update(
            packageName=args.package_name,
            editId=edit_id,
            track=args.track,
            body={"track": args.track, "releases": [release]},
        ).execute()
        committed = publisher.edits().commit(
            packageName=args.package_name,
            editId=edit_id,
        ).execute()
        print(
            f"Uploaded versionCode={version_code} to track={args.track}; "
            f"edit={committed.get('id', edit_id)}"
        )
        return 0
    except HttpError as exc:
        if edit_id:
            try:
                publisher.edits().delete(
                    packageName=args.package_name,
                    editId=edit_id,
                ).execute()
            except Exception:
                pass
        message = str(exc)
        if exc.resp.status in {400, 404}:
            message += (
                "\nVerify that the Play Console app exists and that its first "
                "AAB was uploaded manually before using the API."
            )
        print(message, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
