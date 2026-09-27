#!/usr/bin/env python3
"""Package Cooking with Kindness translations as complete JSON file replacements."""

from __future__ import annotations

import argparse
from pathlib import Path

from prepare_cooking_json_payloads import LANGUAGES, prepare
from repack_translation_packages import rebuild, update_catalog


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, required=True)
    args = parser.parse_args()

    repo = Path(__file__).resolve().parent.parent
    game = args.source_root / "cookingwithkindness.love"
    prepare(game, repo)
    entries = {}
    for slug, _ in LANGUAGES:
        entry = rebuild(repo / "translations" / "sources" / slug, repo / "translations" / "packages")
        entries[entry["id"]] = entry
    update_catalog(repo / "translations" / "catalog.json", entries)
    update_catalog(repo / "app" / "src" / "main" / "assets" / "community_translation_catalog.json", entries)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
