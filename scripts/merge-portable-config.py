#!/usr/bin/env python3
"""Merge portable Codex preferences without replacing machine-local config."""

from __future__ import print_function

import argparse
import os
import re
import shutil
import stat
import tempfile


SECTION_RE = re.compile(r"^\s*\[([^\]]+)\]\s*(?:#.*)?$")
KEY_RE = re.compile(r"^\s*([A-Za-z0-9_.-]+)\s*=\s*(.+?)\s*$")
ROOT_KEYS = {
    "model",
    "model_provider",
    "model_reasoning_effort",
    "personality",
    "service_tier",
}
PROVIDER_KEYS = {
    "name",
    "wire_api",
    "requires_openai_auth",
    "supports_websockets",
}
PORTABLE_SECTIONS = {"desktop", "windows", "features"}


def allowed_key(section, key):
    if section == "":
        return key in ROOT_KEYS
    if section in PORTABLE_SECTIONS:
        return True
    if section.startswith("plugins."):
        return key == "enabled"
    if section.startswith("model_providers."):
        return key in PROVIDER_KEYS
    return False


def parse_portable(lines):
    values = {}
    section_order = []
    current = ""
    values[current] = {}

    for line in lines:
        section_match = SECTION_RE.match(line)
        if section_match:
            current = section_match.group(1)
            if current not in values:
                values[current] = {}
                section_order.append(current)
            continue

        key_match = KEY_RE.match(line)
        if not key_match:
            continue
        key = key_match.group(1)
        if current == "windows" and os.name != "nt":
            continue
        if allowed_key(current, key):
            values.setdefault(current, {})[key] = "{} = {}\n".format(
                key, key_match.group(2)
            )

    return values, section_order


def nonportable_records(lines, portable):
    records = []
    current = ""

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        section_match = SECTION_RE.match(line)
        if section_match:
            current = section_match.group(1)
            continue

        key_match = KEY_RE.match(line)
        if key_match and key_match.group(1) in portable.get(current, {}):
            continue
        records.append((current, stripped))

    return sorted(records)


def assert_portable_applied(portable, target_lines):
    target_portable, _ = parse_portable(target_lines)
    missing_or_changed = []
    for section, values in portable.items():
        for key, expected in values.items():
            actual = target_portable.get(section, {}).get(key)
            if actual != expected:
                missing_or_changed.append("{}::{}".format(section or "<root>", key))
    if missing_or_changed:
        raise RuntimeError(
            "Portable config verification failed for: {}".format(
                ", ".join(missing_or_changed)
            )
        )


def assert_nonportable_preserved(baseline_lines, result_lines, portable):
    before = nonportable_records(baseline_lines, portable)
    after = nonportable_records(result_lines, portable)
    if before != after:
        raise RuntimeError(
            "Refusing config merge because non-portable settings would change"
        )
    return len(before)


def current_section_map(lines):
    sections = {}
    current = ""
    for index, line in enumerate(lines):
        section_match = SECTION_RE.match(line)
        if section_match:
            current = section_match.group(1)
            sections.setdefault(current, index)
    return sections


def merge_lines(source_lines, target_lines):
    portable, section_order = parse_portable(source_lines)
    seen = set()
    output = []
    current = ""

    for line in target_lines:
        section_match = SECTION_RE.match(line)
        if section_match:
            current = section_match.group(1)
            output.append(line)
            continue

        key_match = KEY_RE.match(line)
        if key_match:
            key = key_match.group(1)
            replacement = portable.get(current, {}).get(key)
            if replacement is not None:
                output.append(replacement)
                seen.add((current, key))
                continue
        output.append(line)

    missing_root = [
        portable[""][key]
        for key in portable.get("", {})
        if ("", key) not in seen
    ]
    if missing_root:
        first_section = next(
            (i for i, line in enumerate(output) if SECTION_RE.match(line)),
            len(output),
        )
        insertion = list(missing_root)
        if insertion and first_section > 0 and output[first_section - 1].strip():
            insertion.append("\n")
        output[first_section:first_section] = insertion

    for section in section_order:
        missing = [
            portable[section][key]
            for key in portable.get(section, {})
            if (section, key) not in seen
        ]
        if not missing:
            continue

        section_positions = current_section_map(output)
        if section in section_positions:
            start = section_positions[section] + 1
            end = next(
                (
                    i
                    for i in range(start, len(output))
                    if SECTION_RE.match(output[i])
                ),
                len(output),
            )
            output[end:end] = missing
        else:
            if output and output[-1].strip():
                output.append("\n")
            output.append("[{}]\n".format(section))
            output.extend(missing)

    if output and not output[-1].endswith("\n"):
        output[-1] += "\n"
    return output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("template")
    parser.add_argument("target")
    parser.add_argument("--backup-suffix", default="")
    parser.add_argument(
        "--verify-against",
        default="",
        help="Verify target preservation against a pre-merge backup without writing.",
    )
    args = parser.parse_args()

    with open(args.template, "r", encoding="utf-8-sig") as handle:
        source_lines = handle.readlines()
    with open(args.target, "r", encoding="utf-8-sig") as handle:
        target_lines = handle.readlines()
    portable, _ = parse_portable(source_lines)

    if args.verify_against:
        with open(args.verify_against, "r", encoding="utf-8-sig") as handle:
            baseline_lines = handle.readlines()
        preserved_count = assert_nonportable_preserved(
            baseline_lines, target_lines, portable
        )
        assert_portable_applied(portable, target_lines)
        print(
            "Verified portable preferences and preserved {} non-portable records".format(
                preserved_count
            )
        )
        return 0

    merged = merge_lines(source_lines, target_lines)
    assert_nonportable_preserved(target_lines, merged, portable)
    assert_portable_applied(portable, merged)
    original = "".join(target_lines)
    result = "".join(merged)
    if result == original:
        print("config.toml unchanged")
        return 0

    if args.backup_suffix:
        shutil.copy2(args.target, args.target + args.backup_suffix)

    target_mode = stat.S_IMODE(os.stat(args.target).st_mode)
    target_dir = os.path.dirname(os.path.abspath(args.target))
    descriptor, temp_path = tempfile.mkstemp(prefix=".config-", suffix=".toml", dir=target_dir)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(result)
        os.chmod(temp_path, target_mode)
        os.replace(temp_path, args.target)
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)

    print("Merged portable preferences into config.toml")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
