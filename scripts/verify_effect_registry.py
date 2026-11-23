#!/usr/bin/env python3
import json
from pathlib import Path

path = Path("App/Resources/effects.json")
data = json.loads(path.read_text(encoding="utf-8"))

categories = data.get("categories")
effects = data.get("effects")
assert isinstance(categories, list) and len(categories) == 13, "expected 13 source categories"
assert isinstance(effects, list) and len(effects) == 73, "expected 73 source effects"

category_ids = {item["id"] for item in categories}
assert len(category_ids) == len(categories), "duplicate category IDs"

effect_ids = [item["id"] for item in effects]
assert len(set(effect_ids)) == len(effect_ids), "duplicate effect IDs"

supported_types = {"number", "integer", "color", "point", "boolean", "choice", "stops"}
for effect in effects:
    assert effect["category"] in category_ids, f'{effect["id"]}: unknown category'
    assert effect["target"] in {"any", "layer_3d"}, f'{effect["id"]}: unknown target'
    assert isinstance(effect["needsBackdrop"], bool), f'{effect["id"]}: needsBackdrop must be boolean'
    for parameter in effect["params"]:
        assert parameter["type"] in supported_types, (
            f'{effect["id"]}.{parameter["name"]}: unsupported parameter type {parameter["type"]}'
        )
        if parameter["type"] in {"number", "integer"} and "min" in parameter and "max" in parameter:
            assert parameter["min"] < parameter["max"], (
                f'{effect["id"]}.{parameter["name"]}: invalid numeric range'
            )
        if parameter["type"] == "choice":
            assert parameter["default"] in parameter["choices"], (
                f'{effect["id"]}.{parameter["name"]}: default is not an allowed choice'
            )

print(f"Validated {len(effects)} effects, {len(categories)} categories and all parameter schemas.")
