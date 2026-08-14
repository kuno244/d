"""Deterministic reference logic for the release world and battle loop.

This module intentionally has no Godot dependency. The GDScript services mirror these
rules and the Python tests protect persistence, generation, navigation, and combat math.
"""
from __future__ import annotations

from heapq import heappop, heappush
from math import sqrt
from typing import Iterable


MASK32 = 0xFFFFFFFF


class DeterministicRng:
    def __init__(self, seed: int):
        self.state = int(seed) & MASK32

    def next_u32(self) -> int:
        self.state = (1664525 * self.state + 1013904223) & MASK32
        return self.state

    def range(self, minimum: int, maximum_exclusive: int) -> int:
        if maximum_exclusive <= minimum:
            return minimum
        return minimum + self.next_u32() % (maximum_exclusive - minimum)


def biome_at(seed: int, x: int, y: int, biome_ids: list[str]) -> str:
    coarse = (x // 10) * 3 + (y // 10) * 5
    detail = ((x * 73856093) ^ (y * 19349663) ^ int(seed)) & MASK32
    return biome_ids[(coarse + detail // 268435456) % len(biome_ids)]


def _distance(a: tuple[int, int], b: tuple[int, int]) -> float:
    return sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2)


def _free_cell(
    rng: DeterministicRng,
    occupied: set[tuple[int, int]],
    width: int,
    height: int,
    start: tuple[int, int],
    minimum_start_distance: float,
) -> tuple[int, int]:
    for _ in range(width * height * 4):
        cell = (rng.range(2, width - 2), rng.range(2, height - 2))
        if cell not in occupied and _distance(cell, start) >= minimum_start_distance:
            occupied.add(cell)
            return cell
    for y in range(height):
        for x in range(width):
            cell = (x, y)
            if cell not in occupied:
                occupied.add(cell)
                return cell
    raise ValueError("world has no free entity cell")


def create_initial_world(seed: int, config: dict) -> dict:
    width, height = int(config["width"]), int(config["height"])
    start = tuple(int(v) for v in config["player_start"])
    biome_ids = [str(item["id"]) for item in config["biomes"]]
    biomes = [biome_at(seed, x, y, biome_ids) for y in range(height) for x in range(width)]
    rng = DeterministicRng(seed)
    occupied = {start}
    entities: list[dict] = [{
        "entity_id": "city_player_001", "kind": "CITY", "cell": list(start),
        "display_name": "Crownkeep", "owner_id": "player", "level": 1,
    }]

    resource_types = ["food", "wood", "stone", "gold"]
    for index in range(int(config["resource_nodes"])):
        cell = _free_cell(rng, occupied, width, height, start, 4.0)
        level = min(6, max(1, 1 + int(_distance(cell, start) // 8)))
        total = 900 * level + rng.range(0, 301)
        entities.append({
            "entity_id": f"resource_{index + 1:03d}", "kind": "RESOURCE", "cell": list(cell),
            "resource_type": resource_types[index % len(resource_types)], "level": level,
            "total_amount": total, "remaining": total, "depleted": False,
            "respawn_timestamp": 0,
        })

    pve_types = [
        "monster_forest_troll", "monster_stone_golem", "monster_titan_boar",
        "monster_armored_wyvern", "monster_cursed_knight",
    ]
    for index in range(int(config["pve_encounters"])):
        cell = _free_cell(rng, occupied, width, height, start, 6.0)
        level = min(12, max(1, 1 + int(_distance(cell, start) // 5)))
        entities.append({
            "entity_id": f"pve_{index + 1:03d}", "kind": "PVE", "cell": list(cell),
            "pve_id": pve_types[index % len(pve_types)], "level": level,
            "combat_power": 95 + level * 55, "defeated": False, "respawn_timestamp": 0,
            "reward": {"food": 90 * level, "wood": 70 * level, "stone": 45 * level, "gold": 18 * level},
        })

    neutral_counts = (
        ("RUINS", "ruins", 5.0), ("VILLAGE", "villages", 3.0),
        ("MONSTER_CAMP", "monster_camps", 7.0), ("FORTRESS", "fortresses", 10.0),
    )
    for kind, config_key, minimum_distance in neutral_counts:
        for index in range(int(config[config_key])):
            cell = _free_cell(rng, occupied, width, height, start, minimum_distance)
            level = min(10, max(1, 1 + int(_distance(cell, start) // 7)))
            entity = {
                "entity_id": f"{kind.lower()}_{index + 1:03d}", "kind": kind, "cell": list(cell),
                "level": level, "owner_id": "neutral", "resolved": False,
            }
            if kind == "MONSTER_CAMP":
                entity["combat_power"] = 140 + level * 70
                entity["reward"] = {"food": 120 * level, "wood": 100 * level, "stone": 80 * level, "gold": 30 * level}
            entities.append(entity)

    return {
        "seed": int(seed), "width": width, "height": height,
        "chunk_size": int(config["chunk_size"]), "region_size": int(config["region_size"]),
        "player_city_id": "city_player_001", "biomes": biomes, "entities": entities,
    }


def apply_gather(node: dict, wallet: dict, capacities: dict, requested: int, now: int) -> int:
    if node.get("kind") != "RESOURCE" or requested <= 0 or node.get("depleted", False):
        return 0
    resource_id = str(node["resource_type"])
    room = max(0, int(capacities.get(resource_id, 0)) - int(wallet.get(resource_id, 0)))
    claimed = min(max(0, int(requested)), max(0, int(node.get("remaining", 0))), room)
    if claimed <= 0:
        return 0
    wallet[resource_id] = int(wallet.get(resource_id, 0)) + claimed
    node["remaining"] = int(node.get("remaining", 0)) - claimed
    if node["remaining"] <= 0:
        node["remaining"] = 0
        node["depleted"] = True
        node["respawn_timestamp"] = int(now) + 900
    return claimed


def find_world_path(
    start: tuple[int, int], target: tuple[int, int], width: int, height: int,
    blocked: Iterable[tuple[int, int]],
) -> list[tuple[int, int]]:
    blocked_set = set(blocked)
    if target in blocked_set or not (0 <= target[0] < width and 0 <= target[1] < height):
        return []
    frontier: list[tuple[int, tuple[int, int]]] = [(0, start)]
    came_from: dict[tuple[int, int], tuple[int, int] | None] = {start: None}
    costs = {start: 0}
    while frontier:
        _, current = heappop(frontier)
        if current == target:
            break
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nxt = (current[0] + dx, current[1] + dy)
            if not (0 <= nxt[0] < width and 0 <= nxt[1] < height) or nxt in blocked_set:
                continue
            new_cost = costs[current] + 1
            if nxt not in costs or new_cost < costs[nxt]:
                costs[nxt] = new_cost
                priority = new_cost + abs(target[0] - nxt[0]) + abs(target[1] - nxt[1])
                heappush(frontier, (priority, nxt))
                came_from[nxt] = current
    if target not in came_from:
        return []
    path = []
    current: tuple[int, int] | None = target
    while current is not None:
        path.append(current)
        current = came_from[current]
    return list(reversed(path))


def resolve_battle(troops: dict, power_per_unit: dict, enemy_power: int, seed: int) -> dict:
    player_power = sum(max(0, int(count)) * max(0, int(power_per_unit.get(troop_id, 0))) for troop_id, count in troops.items())
    variance = 0.94 + (DeterministicRng(seed).range(0, 13) / 100.0)
    effective_power = round(player_power * variance)
    victory = effective_power >= int(enemy_power)
    ratio = min(0.9, max(0.08, (int(enemy_power) / max(1, effective_power)) * (0.28 if victory else 0.62)))
    remaining = {}
    casualties = {}
    for troop_id, count_value in troops.items():
        count = max(0, int(count_value))
        lost = min(count, round(count * ratio))
        casualties[troop_id] = lost
        remaining[troop_id] = count - lost
    return {
        "victory": victory, "player_power": player_power, "effective_power": effective_power,
        "enemy_power": int(enemy_power), "casualty_ratio": round(ratio, 4),
        "casualties": casualties, "remaining": remaining,
        "remaining_total": sum(remaining.values()),
    }
