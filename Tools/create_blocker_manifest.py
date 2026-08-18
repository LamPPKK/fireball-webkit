#!/usr/bin/env python3

import argparse
import base64
import json
import re
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path


def canonical(payload):
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def create(index_path: Path, base_url: str, version: str, minimum_app_version: str, private_key: Path):
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+", version, flags=re.ASCII):
        raise ValueError("version must contain two or more dot-separated numeric components")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", minimum_app_version, flags=re.ASCII):
        raise ValueError("minimum app version must be major.minor.patch")
    index = json.loads(index_path.read_text())
    payload = {
        "artifacts": [
            {
                "identifier": artifact["identifier"],
                "sha256": artifact["sha256"],
                "url": f"{base_url.rstrip('/')}/{artifact['file']}",
            }
            for artifact in index["artifacts"]
        ],
        "createdAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "minimumAppVersion": minimum_app_version,
        "schemaVersion": 1,
        "sourceCommits": {"easylist": index["sourceCommit"], "easyprivacy": index["sourceCommit"]},
        "version": version,
    }
    with tempfile.NamedTemporaryFile() as message, tempfile.NamedTemporaryFile() as signature:
        message.write(canonical(payload))
        message.flush()
        subprocess.run(
            ["openssl", "pkeyutl", "-sign", "-rawin", "-inkey", str(private_key), "-in", message.name, "-out", signature.name],
            check=True,
        )
        signature.seek(0)
        encoded_signature = base64.b64encode(signature.read()).decode()
    return {"payload": payload, "signature": encoded_signature}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--index", type=Path, required=True)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--minimum-app-version", default="0.1.0")
    parser.add_argument("--private-key", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    manifest = create(args.index, args.base_url, args.version, args.minimum_app_version, args.private_key)
    args.output.write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
