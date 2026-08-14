import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
required = {
    "scripts/world/world_generator.gd": ["class_name WorldGenerator", "generate", "RESOURCE", "PVE"],
    "scripts/world/world_service.gd": ["class_name WorldService", "ensure_generated", "gather", "prepare_battle", "process_offline"],
    "scripts/world/world_map_controller.gd": ["class_name WorldMapController", "refresh_visible_chunks", "select_entity"],
    "scripts/world/world_map_camera.gd": ["class_name WorldMapCameraController", "InputEventScreenDrag", "focus_cell"],
    "scripts/world/world_entity_view.gd": ["class_name WorldEntityView", "entity_id", "configure"],
    "scripts/ui/world_hud.gd": ["class_name WorldHUD", "show_entity", "set_resources"],
    "scripts/combat/battle_service.gd": ["class_name BattleService", "start", "step", "result"],
    "scripts/combat/tactical_battle_controller.gd": ["class_name TacticalBattleController", "finish_battle"],
    "scenes/world/WorldMap.tscn": ["WorldMapController", "WorldMapCameraController", "WorldHUD"],
    "scenes/battle/TacticalBattle.tscn": ["TacticalBattleController", "Commander Strike", "Return to World"],
}
for rel, tokens in required.items():
    path = ROOT / rel
    assert path.exists(), rel
    text = path.read_text()
    for token in tokens:
        assert token in text, (rel, token)

config = json.loads((ROOT / "data/world/world.json").read_text())["world"]
assert config["width"] == 64 and config["height"] == 64
assert config["chunk_size"] == 8 and len(config["biomes"]) == 6
assert config["performance"]["max_active_chunks"] <= 25

router = (ROOT / "scripts/core/scene_router.gd").read_text()
assert "BATTLE" in router and "goto_battle" in router
registry = (ROOT / "scripts/data/data_registry.gd").read_text()
assert '"world": "res://data/world/world.json"' in registry

runtime_text = "\n".join(
    path.read_text(errors="ignore")
    for folder in (ROOT / "scripts", ROOT / "scenes", ROOT / "data")
    for path in folder.rglob("*") if path.is_file()
)
for forbidden in ["assets/source/", "assets/processed/", "Meshy_AI_model.glb"]:
    assert forbidden not in runtime_text
print("PASS release project contract")
