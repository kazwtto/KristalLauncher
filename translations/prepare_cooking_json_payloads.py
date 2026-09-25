#!/usr/bin/env python3
"""Prepare staged-only Cooking with Kindness JSON replacements from translation sources."""

from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from pathlib import Path


FILES = ("dialoguedump.json", "data/i18n.json")
LANGUAGES = (("cooking-with-kindness-ptbr", "ptbr"), ("cooking-with-kindness-es", "es"))
VERSION = "1.0.2"
MINIMUM_LAUNCHER_VERSION = "0.17.49"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def escape_lua_string_quotes(value: str) -> str:
    """The game's _s() compiles normal dialogue inside a Lua quoted string."""
    escaped = []
    preceding_backslashes = 0
    for char in value:
        if char == '"' and preceding_backslashes % 2 == 0:
            escaped.append("\\")
        escaped.append(char)
        preceding_backslashes = preceding_backslashes + 1 if char == "\\" else 0
    return "".join(escaped)


def prepare(game_path: Path, repo: Path) -> None:
    with zipfile.ZipFile(game_path) as game:
        originals = {name: game.read(name) for name in FILES}

    for slug, language_field in LANGUAGES:
        source_dir = repo / "translations" / "sources" / slug
        manifest_path = source_dir / "translation.json"
        manifest = json.loads(manifest_path.read_text("utf-8"))
        files = []
        for target in FILES:
            original = json.loads(originals[target])
            source_path = source_dir / Path(target).name
            translated = json.loads(source_path.read_text("utf-8-sig"))
            if set(translated) != set(original):
                raise ValueError(f"{source_path}: keys differ from the original game")

            payload = {}
            translated_count = 0
            for key, item in original.items():
                source_item = translated[key]
                if not isinstance(item, dict) or not isinstance(source_item, dict):
                    raise ValueError(f"{source_path}: invalid item {key}")
                if source_item.get("english") != item.get("english"):
                    raise ValueError(f"{source_path}: original text changed at {key}")
                translation = source_item.get(language_field)
                if translation is not None and not isinstance(translation, str):
                    raise ValueError(f"{source_path}: invalid translation at {key}")
                effective = translation if translation and translation.strip() else item["english"]
                if effective != item["english"] and "Ⓥ" not in item["english"]:
                    effective = escape_lua_string_quotes(effective)
                translated_count += effective != item["english"]
                payload[key] = {**item, "english": effective}

            payload_bytes = (json.dumps(payload, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
            payload_path = source_dir / "payload" / target
            payload_path.parent.mkdir(parents=True, exist_ok=True)
            payload_path.write_bytes(payload_bytes)
            files.append({
                "source": f"payload/{target}",
                "target": target,
                "scope": "package",
                "sourceSha256": sha256(originals[target]),
                "translatedSha256": sha256(payload_bytes),
            })
            print(f"{slug}/{target}: {translated_count}/{len(original)} translated values")

        manifest["version"] = VERSION
        manifest["minimumLauncherVersion"] = MINIMUM_LAUNCHER_VERSION
        manifest["files"] = files
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", "utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--game", type=Path, required=True, help="Original Cooking with Kindness .love")
    args = parser.parse_args()
    prepare(args.game, Path(__file__).resolve().parent.parent)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
