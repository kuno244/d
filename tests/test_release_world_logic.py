import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from release_logic_reference import (  # noqa: E402
    apply_gather,
    create_initial_world,
    find_world_path,
    resolve_battle,
)


config = json.loads((ROOT / "data/world/world.json").read_text())["world"]
first = create_initial_world(config["seed"], config)
second = create_initial_world(config["seed"], config)
other = create_initial_world(config["seed"] + 1, config)

assert first == second
assert first != other
assert first["width"] == 1024 and first["height"] == 1024
assert first["chunk_size"] == 32 and first["region_size"] == 128
assert len(first["biomes"]) == 64 * 64
assert len(set(first["biomes"])) == 6
assert first["player_city_id"] == "city_player_001"

entities = first["entities"]
cells = [tuple(entity["cell"]) for entity in entities]
assert len(cells) == len(set(cells)), "world entities overlap"
assert all(0 <= x < 1024 and 0 <= y < 1024 for x, y in cells)
counts = {}
for entity in entities:
    counts[entity["kind"]] = counts.get(entity["kind"], 0) + 1
assert counts == {
    "CITY": 1,
    "RESOURCE": 600,
    "PVE": 240,
    "RUINS": 80,
    "VILLAGE": 56,
    "MONSTER_CAMP": 96,
    "FORTRESS": 24,
}

resource = next(entity for entity in entities if entity["kind"] == "RESOURCE")
wallet = {"food": 0, "wood": 0, "stone": 0, "gold": 0}
capacities = {key: 100_000 for key in wallet}
before = resource["remaining"]
claimed = apply_gather(resource, wallet, capacities, 350, now=10_000)
assert claimed > 0 and resource["remaining"] == before - claimed
assert wallet[resource["resource_type"]] == claimed
assert apply_gather(resource, wallet, capacities, 0, now=10_001) == 0

blocked = {(2, 1), (2, 2), (2, 3)}
path = find_world_path((1, 2), (3, 2), 5, 5, blocked)
assert path[0] == (1, 2) and path[-1] == (3, 2)
assert not any(cell in blocked for cell in path)
assert find_world_path((1, 1), (2, 2), 5, 5, {(2, 2)}) == []

victory = resolve_battle(
    {"troop_kingdom_swordsman": 50, "troop_kingdom_archer": 25},
    {"troop_kingdom_swordsman": 3, "troop_kingdom_archer": 4},
    enemy_power=180,
    seed=42,
)
repeat = resolve_battle(
    {"troop_kingdom_swordsman": 50, "troop_kingdom_archer": 25},
    {"troop_kingdom_swordsman": 3, "troop_kingdom_archer": 4},
    enemy_power=180,
    seed=42,
)
assert victory == repeat
assert victory["victory"] and victory["remaining_total"] > 0
assert 0 <= victory["casualty_ratio"] <= 1
print("PASS release world logic")
