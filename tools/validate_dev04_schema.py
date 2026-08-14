#!/usr/bin/env python3
"""DEVELOPMENT 04 data/schema validation independent from Godot runtime."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

RESOURCES = {"food", "wood", "stone", "gold"}
BUILDING_IDS = {
    "building_royal_citadel", "building_barracks", "building_archery_range",
    "building_royal_stable", "building_grand_academy", "building_farm",
    "building_lumber_mill", "building_stone_quarry", "building_watchtower",
    "building_alliance_hall",
}
RESEARCH_BRANCHES = {"economy", "military", "development", "exploration"}


def _load(root: Path, rel: str) -> Any:
    with (root / rel).open("r", encoding="utf-8") as fh:
        return json.load(fh)


def _positive_pair(value: Any) -> bool:
    return (
        isinstance(value, list) and len(value) == 2
        and all(isinstance(v, int) and v > 0 for v in value)
    )


def _cost_ok(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and set(value) == RESOURCES
        and all(isinstance(value[k], (int, float)) and value[k] >= 0 for k in RESOURCES)
    )


def _research_dag(nodes: dict[str, dict], errors: list[str]) -> bool:
    state: dict[str, int] = {}
    acyclic = True

    def visit(node_id: str, chain: list[str]) -> None:
        nonlocal acyclic
        mark = state.get(node_id, 0)
        if mark == 2:
            return
        if mark == 1:
            acyclic = False
            errors.append("research dependency cycle: " + " -> ".join(chain + [node_id]))
            return
        state[node_id] = 1
        for dep in nodes[node_id].get("prerequisites", []):
            dep_id = dep if isinstance(dep, str) else dep.get("id") if isinstance(dep, dict) else None
            if dep_id in nodes:
                visit(dep_id, chain + [node_id])
        state[node_id] = 2

    for node_id in nodes:
        if state.get(node_id, 0) == 0:
            visit(node_id, [])
    return acyclic


def validate(root: Path | str) -> dict[str, Any]:
    root = Path(root)
    errors: list[str] = []
    warnings: list[str] = []

    try:
        buildings_doc = _load(root, "data/buildings/buildings.json")
        troops_doc = _load(root, "data/troops/troops.json")
        research_doc = _load(root, "data/research/research.json")
        resources_doc = _load(root, "data/resources/resources.json")
        city_cfg = _load(root, "data/city/city_config.json")
        economy_cfg = _load(root, "data/economy/economy.json")
        save_schema = _load(root, "data/save/save_schema.json")
        registry_doc = _load(root, "registry/asset_registry.json")
        shipping_doc = _load(root, "registry/shipping_manifest.json")
    except (OSError, json.JSONDecodeError) as exc:
        return {
            "passed": False, "errors": [f"load failure: {exc}"], "warnings": [],
            "buildings": 0, "building_levels": 0, "troops": 0, "resources": 0,
            "research_nodes": 0, "research_dag_acyclic": False, "save_version": 0,
        }

    buildings = buildings_doc.get("items", [])
    troops = troops_doc.get("items", [])
    research = research_doc.get("items", [])
    resources = resources_doc.get("items", [])
    registry_assets = {a.get("asset_id"): a for a in registry_doc.get("assets", [])}
    shipping_assets = {a.get("asset_id"): a for a in shipping_doc.get("shipping_assets", [])}

    building_ids = [b.get("id") for b in buildings]
    if len(buildings) != 10 or set(building_ids) != BUILDING_IDS or len(set(building_ids)) != 10:
        errors.append(f"building IDs/count invalid: {len(buildings)}")

    building_level_count = 0
    for b in buildings:
        bid = b.get("id", "<missing>")
        if not _positive_pair(b.get("footprint")):
            errors.append(f"{bid}: invalid footprint")
        if b.get("max_level") != 20:
            errors.append(f"{bid}: max_level must be 20")
        levels = b.get("levels", [])
        building_level_count += len(levels)
        if [row.get("level") for row in levels] != list(range(1, 21)):
            errors.append(f"{bid}: levels must be explicit 1..20")
        if not _cost_ok(b.get("base_cost")):
            errors.append(f"{bid}: invalid base_cost")
        previous_power = -1
        for row in levels:
            level = row.get("level", "?")
            if not _cost_ok(row.get("cost")):
                errors.append(f"{bid} L{level}: invalid cost")
            if not isinstance(row.get("build_time_sec"), (int, float)) or row.get("build_time_sec", 0) <= 0:
                errors.append(f"{bid} L{level}: invalid build time")
            if not isinstance(row.get("power"), (int, float)) or row.get("power", -1) < 0:
                errors.append(f"{bid} L{level}: invalid power")
            elif row["power"] < previous_power:
                errors.append(f"{bid}: power regresses at L{level}")
            previous_power = row.get("power", previous_power)
            req = row.get("citadel_required_level")
            if not isinstance(req, int) or not 1 <= req <= 20:
                errors.append(f"{bid} L{level}: invalid citadel gate")
        aid = b.get("asset_id")
        if aid not in registry_assets:
            errors.append(f"{bid}: asset_id absent from Asset Registry: {aid}")
        elif registry_assets[aid].get("category") != "BUILDING":
            errors.append(f"{bid}: asset category is not BUILDING")
        if aid not in shipping_assets:
            errors.append(f"{bid}: building asset is not shipping ready: {aid}")

    resource_ids = [r.get("id") for r in resources]
    if len(resources) != 4 or set(resource_ids) != RESOURCES or len(set(resource_ids)) != 4:
        errors.append(f"resource IDs/count invalid: {resource_ids}")
    if set(economy_cfg.get("resources", [])) != RESOURCES:
        errors.append("economy resource set does not match definitions")
    for key in ("starting_resources", "starting_capacity"):
        value = economy_cfg.get(key, {})
        if set(value) != RESOURCES or any(not isinstance(v, (int, float)) or v < 0 for v in value.values()):
            errors.append(f"economy {key} invalid")

    troop_ids: set[str] = set()
    for troop in troops:
        tid = troop.get("id", "<missing>")
        if tid in troop_ids:
            errors.append(f"duplicate troop id: {tid}")
        troop_ids.add(tid)
        building_id = troop.get("training_building_id")
        if building_id not in BUILDING_IDS:
            errors.append(f"{tid}: invalid training building {building_id}")
        if not _cost_ok(troop.get("base_training_cost")):
            errors.append(f"{tid}: invalid training cost")
        if troop.get("asset_id") not in registry_assets:
            errors.append(f"{tid}: asset_id missing from registry")
        if not isinstance(troop.get("base_training_time_sec"), (int, float)) or troop.get("base_training_time_sec", 0) <= 0:
            errors.append(f"{tid}: invalid training time")
    if len(troops) != 5:
        errors.append(f"expected 5 troops, found {len(troops)}")

    branches = set(research_doc.get("branches", []))
    if branches != RESEARCH_BRANCHES:
        errors.append(f"research branches invalid: {sorted(branches)}")
    research_nodes: dict[str, dict] = {}
    for node in research:
        rid = node.get("id", "<missing>")
        if rid in research_nodes:
            errors.append(f"duplicate research id: {rid}")
        research_nodes[rid] = node
    if len(research) != 20:
        errors.append(f"expected 20 research nodes, found {len(research)}")
    for rid, node in research_nodes.items():
        if node.get("branch") not in RESEARCH_BRANCHES:
            errors.append(f"{rid}: invalid branch")
        if node.get("max_level") != 5:
            errors.append(f"{rid}: max_level must be 5")
        if not _cost_ok(node.get("base_cost")):
            errors.append(f"{rid}: invalid research cost")
        if not isinstance(node.get("base_research_time_sec"), (int, float)) or node.get("base_research_time_sec", 0) <= 0:
            errors.append(f"{rid}: invalid research time")
        if not isinstance(node.get("academy_requirement"), int) or not 1 <= node.get("academy_requirement", 0) <= 20:
            errors.append(f"{rid}: invalid Academy requirement")
        if node.get("research_tier") not in range(1, 6):
            errors.append(f"{rid}: invalid research tier")
        if node.get("citadel_requirement") not in {3, 5, 7, 10, 16}:
            errors.append(f"{rid}: invalid Citadel research gate")
        if not node.get("effects"):
            errors.append(f"{rid}: missing effects")
        for dep in node.get("prerequisites", []):
            dep_id = dep if isinstance(dep, str) else dep.get("id") if isinstance(dep, dict) else None
            if dep_id == rid:
                errors.append(f"{rid}: self dependency")
            if dep_id not in research_nodes:
                errors.append(f"{rid}: missing prerequisite {dep_id}")
    dag_ok = _research_dag(research_nodes, errors)

    grid = city_cfg.get("grid", {})
    if not all(isinstance(grid.get(k), int) and grid[k] > 0 for k in ("width", "height")):
        errors.append("city grid dimensions invalid")
    if not isinstance(grid.get("cell_size"), (int, float)) or grid.get("cell_size", 0) <= 0:
        errors.append("city grid cell_size invalid")
    construction = city_cfg.get("construction", {})
    if construction.get("initial_builder_slots") != 1:
        errors.append("initial builder slots must be 1")
    if construction.get("max_future_builder_slots", 0) < construction.get("initial_builder_slots", 1):
        errors.append("max future builder slots invalid")
    decoration_ids = city_cfg.get("decoration", {}).get("allowed_asset_ids", [])
    for aid in decoration_ids:
        if aid not in registry_assets:
            errors.append(f"decoration asset missing from registry: {aid}")
        elif aid not in shipping_assets:
            errors.append(f"decoration asset not shipping ready: {aid}")

    save_version = save_schema.get("current_save_version", 0)
    if save_version != 3:
        errors.append(f"current release save version must be 3, got {save_version}")
    required_dict = set(save_schema.get("required_dictionary_keys", []))
    required = {"profile", "resources", "capacities", "city_state", "progression", "troop_state", "research_state", "world_state"}
    if not required.issubset(required_dict):
        errors.append("save schema missing DEVELOPMENT 04 top-level dictionaries")
    city_keys = set(save_schema.get("city_state_keys", []))
    for key in {"buildings", "decorations", "construction_queues", "production", "population", "city_power"}:
        if key not in city_keys:
            errors.append(f"save city_state missing key: {key}")

    if shipping_doc.get("shipping_asset_count") != len(shipping_assets):
        errors.append("shipping manifest asset count metadata mismatch")
    if shipping_doc.get("development_phase") != "DEVELOPMENT_04":
        warnings.append("shipping manifest development_phase is not DEVELOPMENT_04")

    return {
        "passed": not errors,
        "errors": errors,
        "warnings": warnings,
        "buildings": len(buildings),
        "building_levels": building_level_count,
        "troops": len(troops),
        "resources": len(resources),
        "research_nodes": len(research),
        "research_dag_acyclic": dag_ok,
        "save_version": save_version,
    }


def main(argv: list[str]) -> int:
    root = Path(argv[1]) if len(argv) > 1 else Path(__file__).resolve().parents[1]
    result = validate(root)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
