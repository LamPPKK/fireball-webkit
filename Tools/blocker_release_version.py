#!/usr/bin/env python3

import argparse
import itertools
import json
import re
import sys
from pathlib import Path


TAG_PREFIX = "blocker-"


def parse_version(value):
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+", value, flags=re.ASCII):
        raise ValueError(f"invalid blocker version: {value!r}")
    return tuple(int(component) for component in value.split("."))


def compare_versions(left, right):
    for left_component, right_component in itertools.zip_longest(
        parse_version(left),
        parse_version(right),
        fillvalue=0,
    ):
        if left_component < right_component:
            return -1
        if left_component > right_component:
            return 1
    return 0


def blocker_versions(releases):
    versions = []
    for release in releases:
        tag = release.get("tagName", "")
        if not tag.startswith(TAG_PREFIX):
            continue
        version = tag.removeprefix(TAG_PREFIX)
        parse_version(version)
        versions.append(version)
    return versions


def latest_blocker_tag(releases):
    versions = blocker_versions(releases)
    if not versions:
        return ""
    latest = versions[0]
    for version in versions[1:]:
        if compare_versions(version, latest) > 0:
            latest = version
    return TAG_PREFIX + latest


def validate_candidate(candidate, releases):
    parse_version(candidate)
    latest_tag = latest_blocker_tag(releases)
    if not latest_tag:
        return
    latest = latest_tag.removeprefix(TAG_PREFIX)
    if compare_versions(candidate, latest) <= 0:
        raise ValueError(f"candidate {candidate} must be newer than published version {latest}")


def main():
    parser = argparse.ArgumentParser(description="Select and enforce monotonic blocker release versions.")
    parser.add_argument("--releases-json", type=Path, required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--candidate")
    mode.add_argument("--print-latest", action="store_true")
    args = parser.parse_args()
    releases = json.loads(args.releases_json.read_text())
    try:
        if args.candidate is not None:
            validate_candidate(args.candidate, releases)
            print(f"blocker release version {args.candidate} is monotonic")
        else:
            print(latest_blocker_tag(releases))
    except ValueError as error:
        print(f"blocker release version: {error}", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
