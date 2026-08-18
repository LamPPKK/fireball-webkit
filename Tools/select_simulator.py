#!/usr/bin/env python3

import argparse
import json
import re
import subprocess
from pathlib import Path


RUNTIME_PATTERN = re.compile(r"\.SimRuntime\.iOS-(\d+)(?:-(\d+))?(?:-(\d+))?$")


def runtime_version(identifier: str):
    match = RUNTIME_PATTERN.search(identifier)
    if not match:
        return None
    return tuple(int(component or 0) for component in match.groups())


def select_device(payload: dict, family: str, minimum_major: int = 18) -> dict:
    prefix = "iPhone" if family == "iphone" else "iPad"
    candidates = []
    for runtime, devices in payload.get("devices", {}).items():
        version = runtime_version(runtime)
        if version is None or version[0] < minimum_major:
            continue
        for device in devices:
            if device.get("isAvailable") and device.get("name", "").startswith(prefix):
                candidates.append((version, device["name"], device["udid"], device))

    if not candidates:
        raise RuntimeError(f"No available {family} simulator running iOS {minimum_major} or later")

    # Exercise the oldest installed supported runtime; stable name/UDID ordering
    # keeps the choice deterministic when a runner exposes several devices.
    return min(candidates, key=lambda candidate: candidate[:3])[3]


def load_devices(input_path: Path | None) -> dict:
    if input_path is not None:
        return json.loads(input_path.read_text())
    result = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--family", choices=("iphone", "ipad"), required=True)
    parser.add_argument("--minimum-major", type=int, default=18)
    parser.add_argument("--input", type=Path)
    args = parser.parse_args()

    device = select_device(load_devices(args.input), args.family, args.minimum_major)
    print(device["udid"])


if __name__ == "__main__":
    main()
