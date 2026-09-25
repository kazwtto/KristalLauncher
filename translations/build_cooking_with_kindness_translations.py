#!/usr/bin/env python3
"""Build Cooking with Kindness community translations from text and JSON sources."""

from __future__ import annotations

import argparse
import json
import zipfile
from pathlib import Path

from build_text_packages import (
    full_archive_path,
    load_kristaltext,
    normalize_translation,
    relative_script_path,
    sha256,
)
from prepare_cooking_json_payloads import prepare as prepare_json_payloads
from repack_translation_packages import rebuild


PROJECT = {
    "archive": "cookingwithkindness.love",
    "mod_root": "mods/CookingwithKindness",
    "game_id": "cooking-with-kindness",
    "title": "Cooking with Kindness",
    "game_version": "DEMO v1.0.6",
}

LANGUAGES = (
    {
        "dialogue_file": "dialogue_ptbr.json",
        "slug": "cooking-with-kindness-ptbr",
        "package_id": "cooking-with-kindness.pt-br",
        "target": "pt-BR",
        "author": "dev",
        "name": {
            "pt-BR": "Cooking with Kindness em Português (Brasil)",
            "en": "Cooking with Kindness in Brazilian Portuguese",
            "es": "Cooking with Kindness en portugués de Brasil",
        },
        "description": {
            "pt-BR": "Tradução comunitária dos textos de Cooking with Kindness para português do Brasil.",
            "en": "Community translation of Cooking with Kindness text into Brazilian Portuguese.",
            "es": "Traducción comunitaria de los textos de Cooking with Kindness al portugués de Brasil.",
        },
    },
    {
        "dialogue_file": "dialogue_es.json",
        "slug": "cooking-with-kindness-es",
        "package_id": "cooking-with-kindness.es",
        "target": "es",
        "author": "dev + IA",
        "name": {
            "pt-BR": "Cooking with Kindness em Espanhol",
            "en": "Cooking with Kindness in Spanish",
            "es": "Cooking with Kindness en Español",
        },
        "description": {
            "pt-BR": "Tradução comunitária dos textos de Cooking with Kindness para espanhol.",
            "en": "Community translation of Cooking with Kindness text into Spanish.",
            "es": "Traducción comunitaria de los textos de Cooking with Kindness al español.",
        },
    },
)


def manifest_for(language: dict, texts_hash: str) -> dict:
    return {
        "schemaVersion": 1,
        "id": language["package_id"],
        "version": "1.0.1",
        "name": language["name"],
        "description": language["description"],
        "author": language["author"],
        "gameProjectId": PROJECT["game_id"],
        "gameVersion": PROJECT["game_version"],
        "sourceLanguage": "en",
        "targetLanguage": language["target"],
        "minimumLauncherVersion": "0.17.49",
        "textsFile": "texts.json",
        "textsSha256": texts_hash,
    }


def build_language(
    tool,
    language: dict,
    source_root: Path,
    repo: Path,
    selected_root: str,
    source_files: dict,
    raw_entries: list,
    entries: list,
    raw_by_name: dict[str, bytes],
    expected_ids: set[str],
) -> str:
    dialogue_path = source_root / language["dialogue_file"]
    dialogues = json.loads(dialogue_path.read_text("utf-8-sig"))
    if set(dialogues) != expected_ids:
        raise RuntimeError(f"{dialogue_path.name}: IDs differ from dialogues_info.json")
    blank = [entry_id for entry_id, item in dialogues.items() if not str(item.get("ptbr", "")).strip()]
    if blank:
        raise RuntimeError(f"{dialogue_path.name}: {len(blank)} empty translations")

    output: dict[str, dict] = {}
    stale: list[str] = []
    for entry, (relative, candidate) in zip(entries, raw_entries):
        item = dialogues.get(entry["id"])
        if item is None:
            continue
        script_path = relative_script_path(selected_root, relative, PROJECT["mod_root"])
        if script_path is None:
            continue
        if item.get("text") != candidate.text:
            stale.append(entry["id"])
            continue
        archive_name = full_archive_path(selected_root, relative)
        original_bytes = raw_by_name.get(archive_name)
        if original_bytes is None:
            raise RuntimeError(f"Missing source file in archive: {archive_name}")
        source_text = source_files[relative]
        translated = str(item["ptbr"])
        if language["target"] == "pt-BR":
            translated = normalize_translation(translated)
        replacement_expression = tool.build_lua_replacement(
            source_text,
            candidate,
            translated,
            allow_placeholder_reorder=False,
        )
        output[entry["id"]] = {
            "file": script_path,
            "fileHash": sha256(original_bytes),
            "startOffset": candidate.start,
            "endOffset": candidate.end,
            "source": candidate.text,
            "translation": translated,
            "originalExpression": source_text[candidate.start : candidate.end],
            "replacementExpression": replacement_expression,
        }

    if stale:
        raise RuntimeError(f"{dialogue_path.name}: {len(stale)} stale dialogue entries")
    if set(output) != expected_ids:
        missing = expected_ids - set(output)
        raise RuntimeError(f"{dialogue_path.name}: {len(missing)} entries do not map to game scripts")

    source_dir = repo / "translations" / "sources" / language["slug"]
    source_dir.mkdir(parents=True, exist_ok=True)
    texts_bytes = (json.dumps(output, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    manifest = manifest_for(language, sha256(texts_bytes))
    manifest_bytes = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    (source_dir / "texts.json").write_bytes(texts_bytes)
    (source_dir / "translation.json").write_bytes(manifest_bytes)

    print(f"{language['target']}: {len(output)} validated replacements")
    return language["slug"]


def update_catalog(path: Path, entries: list[dict]) -> None:
    catalog = json.loads(path.read_text("utf-8-sig"))
    ids = {entry["id"] for entry in entries}
    catalog["translations"] = [
        entry for entry in catalog["translations"] if entry["id"] not in ids
    ] + entries
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", "utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--kristaltext", type=Path, required=True)
    args = parser.parse_args()

    repo = Path(__file__).resolve().parent.parent
    archive = args.source_root / PROJECT["archive"]
    info = json.loads((args.source_root / "dialogues_info.json").read_text("utf-8-sig"))
    expected_ids = set(info)
    tool = load_kristaltext(args.kristaltext)
    selected_root, source_files, raw_entries, entries = tool.scan_project(
        archive,
        scope="auto",
        mod_name=None,
        include_libraries=False,
        include_labels=False,
        dedupe_text=False,
        sink_specs=[],
        field_specs=[],
    )
    source_files = dict(source_files)
    with zipfile.ZipFile(archive) as package:
        raw_by_name = {
            entry.filename: package.read(entry)
            for entry in package.infolist()
            if not entry.is_dir()
        }

    source_slugs = [
        build_language(
            tool,
            language,
            args.source_root,
            repo,
            selected_root,
            source_files,
            raw_entries,
            entries,
            raw_by_name,
            expected_ids,
        )
        for language in LANGUAGES
    ]
    prepare_json_payloads(archive, repo)
    catalog_entries = [
        rebuild(repo / "translations" / "sources" / slug, repo / "translations" / "packages")
        for slug in source_slugs
    ]
    update_catalog(repo / "translations" / "catalog.json", catalog_entries)
    update_catalog(repo / "app" / "src" / "main" / "assets" / "community_translation_catalog.json", catalog_entries)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
