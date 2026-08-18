#!/usr/bin/env python3

import argparse
import base64
import binascii
import plistlib
import re
import sys
import zipfile
from pathlib import Path, PurePosixPath


def version_tuple(value):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9]+(?:\.[0-9]+)*", value):
        raise ValueError(f"invalid numeric version: {value!r}")
    return tuple(int(component) for component in value.split("."))


def verify_ipa(ipa_path: Path, bundle_id: str, version: str, build: str):
    errors = []
    with zipfile.ZipFile(ipa_path) as archive:
        names = archive.namelist()
        info_candidates = [
            name
            for name in names
            if len(PurePosixPath(name).parts) == 3
            and PurePosixPath(name).parts[0] == "Payload"
            and PurePosixPath(name).parts[1].endswith(".app")
            and PurePosixPath(name).name == "Info.plist"
        ]
        if len(info_candidates) != 1:
            return ["IPA must contain exactly one top-level application Info.plist"]

        app_prefix = str(PurePosixPath(info_candidates[0]).parent) + "/"
        info = plistlib.loads(archive.read(info_candidates[0]))
        expected_values = {
            "CFBundleIdentifier": bundle_id,
            "CFBundleShortVersionString": version,
            "CFBundleVersion": build,
        }
        for key, expected in expected_values.items():
            if str(info.get(key, "")) != expected:
                errors.append(f"{key} must be {expected}")

        try:
            if version_tuple(info.get("MinimumOSVersion")) < (18, 0):
                errors.append("MinimumOSVersion must be iOS 18.0 or newer")
        except ValueError as error:
            errors.append(str(error))

        privacy_path = app_prefix + "PrivacyInfo.xcprivacy"
        if privacy_path not in names:
            errors.append("PrivacyInfo.xcprivacy is missing from the application bundle")
        else:
            privacy = plistlib.loads(archive.read(privacy_path))
            if privacy.get("NSPrivacyTracking") is not False:
                errors.append("NSPrivacyTracking must be false")

        public_key_path = app_prefix + "blocker-public-key.txt"
        try:
            encoded_key = archive.read(public_key_path).decode().strip()
            if len(base64.b64decode(encoded_key, validate=True)) != 32:
                raise ValueError
        except (KeyError, UnicodeDecodeError, binascii.Error, ValueError):
            errors.append("the bundled blocker public key must be valid 32-byte Ed25519 key data")

    return errors


def main():
    parser = argparse.ArgumentParser(description="Verify the exact IPA that will be uploaded.")
    parser.add_argument("--ipa", type=Path, required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    args = parser.parse_args()
    errors = verify_ipa(args.ipa, args.bundle_id, args.version, args.build)
    if errors:
        for error in errors:
            print(f"IPA verification: {error}", file=sys.stderr)
        raise SystemExit(1)
    print("exact IPA verification passed")


if __name__ == "__main__":
    main()
