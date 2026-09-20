#!/usr/bin/env python3
"""Rebuild selected text-only translation packages and synchronize catalogs."""

from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from pathlib import Path


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text("utf-8-sig"))


def save_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", "utf-8")


def rebuild(source_dir: Path, packages_dir: Path) -> dict:
    manifest_path = source_dir / "translation.json"
    texts_path = source_dir / "texts.json"
    manifest = load_json(manifest_path)
    texts_bytes = texts_path.read_bytes()
    texts_hash = sha256(texts_bytes)
    if manifest.get("textsFile") != "texts.json":
        raise RuntimeError(f"{source_dir.name}: unsupported textsFile")
    if manifest.get("textsSha256") != texts_hash:
        raise RuntimeError(f"{source_dir.name}: textsSha256 does not match texts.json")

    package_name = f"{source_dir.name}-{manifest['version']}.kllang"
    package_path = packages_dir / package_name
    manifest_bytes = manifest_path.read_bytes()
    with zipfile.ZipFile(package_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as package:
        package.writestr("translation.json", manifest_bytes)
        package.writestr("texts.json", texts_bytes)

    with zipfile.ZipFile(package_path) as package:
        names = [entry.filename for entry in package.infolist() if not entry.is_dir()]
        if names != ["translation.json", "texts.json"]:
            raise RuntimeError(f"{package_name}: unexpected entries {names}")
        packaged_manifest = json.loads(package.read("translation.json"))
        packaged_texts = package.read("texts.json")
        if sha256(packaged_texts) != packaged_manifest["textsSha256"]:
            raise RuntimeError(f"{package_name}: packaged text checksum mismatch")

    catalog_entry = dict(manifest)
    catalog_entry["package"] = f"packages/{package_name}"
    catalog_entry["sha256"] = sha256(package_path.read_bytes())
    print(f"{manifest['id']} {manifest['version']}: {catalog_entry['sha256']}")
    return catalog_entry


def update_catalog(path: Path, replacements: dict[str, dict]) -> None:
    catalog = load_json(path)
    found: set[str] = set()
    updated = []
    for entry in catalog["translations"]:
        replacement = replacements.get(entry["id"])
        if replacement is None:
            updated.append(entry)
        else:
            updated.append(replacement)
            found.add(entry["id"])
    missing = set(replacements) - found
    if missing:
        raise RuntimeError(f"{path}: missing catalog IDs: {sorted(missing)}")
    catalog["translations"] = updated
    save_json(path, catalog)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", nargs="+", help="Translation source directory name")
    args = parser.parse_args()

    repo = Path(__file__).resolve().parent.parent
    sources_dir = repo / "translations" / "sources"
    packages_dir = repo / "translations" / "packages"
    replacements = {
        entry["id"]: entry
        for entry in (
            rebuild(sources_dir / source, packages_dir)
            for source in args.source
        )
    }
    update_catalog(repo / "translations" / "catalog.json", replacements)
    update_catalog(
        repo / "app" / "src" / "main" / "assets" / "community_translation_catalog.json",
        replacements,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
