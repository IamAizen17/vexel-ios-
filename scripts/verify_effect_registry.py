#!/usr/bin/env python3
import json
import math
from pathlib import Path

path = Path("App/Resources/effects.json")
data = json.loads(path.read_text(encoding="utf-8"))

categories = data.get("categories")
effects = data.get("effects")
assert isinstance(categories, list) and len(categories) == 13, "expected 13 source categories"
assert isinstance(effects, list) and len(effects) == 73, "expected 73 source effects"

category_ids = {item["id"] for item in categories}
assert len(category_ids) == len(categories), "duplicate category IDs"
assert all(isinstance(value, str) and value for value in category_ids), "category IDs must be non-empty strings"

effect_ids = [item["id"] for item in effects]
assert len(set(effect_ids)) == len(effect_ids), "duplicate effect IDs"

supported_types = {"number", "integer", "color", "point", "boolean", "choice", "stops"}


def is_number(value):
    return type(value) in (int, float) and math.isfinite(value)


def validate_value(effect_id, parameter, value, label):
    kind = parameter["type"]
    valid = False
    if kind == "number":
        valid = is_number(value)
    elif kind == "integer":
        valid = is_number(value) and int(value) == value
    elif kind == "boolean":
        valid = type(value) is bool
    elif kind == "color":
        valid = isinstance(value, str) and bool(value)
    elif kind == "choice":
        valid = isinstance(value, str) and value in parameter["choices"]
    elif kind == "point":
        valid = isinstance(value, list) and len(value) == 2 and all(is_number(v) for v in value)
    elif kind == "stops":
        valid = (
            isinstance(value, list)
            and len(value) >= 2
            and all(
                isinstance(stop, dict)
                and is_number(stop.get("offset"))
                and 0 <= stop["offset"] <= 1
                and isinstance(stop.get("color"), str)
                for stop in value
            )
        )
    assert valid, f"{effect_id}.{parameter['name']}: invalid {label} for {kind}"

    if kind in {"number", "integer"}:
        if "min" in parameter:
            assert value >= parameter["min"], f"{effect_id}.{parameter['name']}: {label} below minimum"
        if "max" in parameter:
            assert value <= parameter["max"], f"{effect_id}.{parameter['name']}: {label} above maximum"


for effect in effects:
    effect_id = effect["id"]
    assert isinstance(effect_id, str) and effect_id, "effect IDs must be non-empty strings"
    assert effect["category"] in category_ids, f'{effect_id}: unknown category'
    assert effect["target"] in {"any", "layer_3d"}, f'{effect_id}: unknown target'
    assert isinstance(effect["needsBackdrop"], bool), f'{effect_id}: needsBackdrop must be boolean'
    parameters = effect.get("params")
    assert isinstance(parameters, list), f"{effect_id}: params must be an array"
    names = [parameter.get("name") for parameter in parameters]
    assert all(isinstance(name, str) and name for name in names), f"{effect_id}: parameter names must be non-empty"
    assert len(set(names)) == len(names), f"{effect_id}: duplicate parameter names"

    for parameter in parameters:
        name = parameter["name"]
        kind = parameter.get("type")
        assert kind in supported_types, f"{effect_id}.{name}: unsupported parameter type {kind}"
        if kind in {"number", "integer"}:
            for bound in ("min", "max"):
                if bound in parameter:
                    assert is_number(parameter[bound]), f"{effect_id}.{name}: {bound} must be finite"
            if "min" in parameter and "max" in parameter:
                assert parameter["min"] < parameter["max"], f"{effect_id}.{name}: invalid numeric range"
        if kind == "choice":
            choices = parameter.get("choices")
            assert isinstance(choices, list) and choices and all(isinstance(v, str) and v for v in choices), (
                f"{effect_id}.{name}: choices must be non-empty strings"
            )
            assert len(set(choices)) == len(choices), f"{effect_id}.{name}: duplicate choices"
        if "default" in parameter:
            validate_value(effect_id, parameter, parameter["default"], "default")

print(f"Validated {len(effects)} effects, {len(categories)} categories and all parameter schemas/defaults.")
