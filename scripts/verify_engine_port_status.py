#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / "App/Resources/engine-port-status.json").read_text())
registry = json.loads((ROOT / "App/Resources/effects.json").read_text())
metal = (ROOT / "Packages/VexelRenderer/Sources/VexelRenderer/MetalShaders.metal").read_text()

shader_files = manifest["shaderFiles"]
effects = manifest["effects"]

assert len(shader_files) == 81, f"Expected 81 pinned source shaders, found {len(shader_files)}"
assert len({item["sourcePath"] for item in shader_files}) == len(shader_files), "Duplicate shader source path"
assert len(effects) == 73, f"Expected 73 effect records, found {len(effects)}"
assert len({item["id"] for item in effects}) == len(effects), "Duplicate effect ID"
expected_categories = {item["id"] for item in registry["categories"] if item["id"] != "all"}
assert {item["category"] for item in effects} == expected_categories, "Effect categories differ from the registry (excluding the 'all' picker filter)"

registry_by_id = {item["id"]: item for item in registry["effects"]}
manifest_by_id = {item["id"]: item for item in effects}
assert set(registry_by_id) == set(manifest_by_id), "Port status effect IDs differ from canonical registry"

for item in effects:
    source = registry_by_id[item["id"]]
    assert item["category"] == source["category"], f"Category drift: {item['id']}"
    assert item["target"] == source["target"], f"Target drift: {item['id']}"
    assert item["needsBackdrop"] == source["needsBackdrop"], f"Backdrop drift: {item['id']}"
    assert item["status"] in {"not_started", "partial", "complete"}, f"Invalid effect status: {item['id']}"

for item in shader_files:
    assert item["status"] in {"not_started", "partial", "complete"}, f"Invalid shader status: {item['sourcePath']}"
    if item["status"] in {"partial", "complete"}:
        function = item.get("mslFunction")
        assert function and function in metal, f"Missing MSL function for {item['sourcePath']}"

print(f"Verified {len(shader_files)} source shaders and {len(effects)} effect contracts.")
print(f"Shader coverage: {sum(x['status'] != 'not_started' for x in shader_files)} partial/complete.")
print(f"Effect coverage: {sum(x['status'] != 'not_started' for x in effects)} partial/complete.")
