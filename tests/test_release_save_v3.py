import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from save_contract import default_save, migrate_save, validate_save  # noqa: E402


save = default_save(now=5_000)
assert save["save_version"] == 4
world = save["world_state"]
for key in [
    "seed", "generated", "width", "height", "chunk_size", "region_size",
    "player_city_id", "entities", "armies", "explored_chunks", "visible_chunks",
    "camera", "pending_battle", "last_world_timestamp", "objectives",
]:
    assert key in world, key
assert world["armies"][0]["army_id"] == "army_player_001"
assert world["armies"][0]["troops"]["troop_kingdom_swordsman"] > 0

legacy = default_save(now=4_000)
legacy["save_version"] = 2
legacy["world_state"] = {
    "discovered_chunks": [[3, 4]],
    "armies": [],
    "pve_states": [],
    "season_id": "preseason_01",
}
migrated = migrate_save(legacy, now=5_000)
assert migrated["save_version"] == 4
assert migrated["world_state"]["explored_chunks"] == [[16, 16]]
assert migrated["world_state"]["width"] == 1024
assert migrated["resources"] == legacy["resources"]
assert migrated["city_state"]["buildings"] == legacy["city_state"]["buildings"]
assert validate_save(migrated) == []

bad = default_save(now=5_000)
bad["world_state"]["camera"] = {"cell": [-999, 99999], "zoom": -20}
bad["world_state"]["last_world_timestamp"] = 999_999_999
clean = migrate_save(bad, now=6_000)
assert clean["world_state"]["camera"] == {"cell": [0, 1023], "zoom": 0.28}
assert clean["world_state"]["last_world_timestamp"] == 6_000
print("PASS release save v4")
