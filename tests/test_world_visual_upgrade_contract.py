import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
config = json.loads((ROOT / "data/world/world.json").read_text())["world"]
controller = (ROOT / "scripts/world/world_map_controller.gd").read_text()
hud_scene = (ROOT / "scenes/ui/WorldHUD.tscn").read_text()
camera = (ROOT / "scripts/world/world_map_camera.gd").read_text()

assert config["width"] == 1024 and config["height"] == 1024
assert config["chunk_size"] == 32 and config["region_size"] == 128
assert config["player_start"] == [512, 512]
assert config["resource_nodes"] >= 500
assert config["pve_encounters"] >= 180
assert config["performance"]["max_active_chunks"] <= 25

for token in ["_terrain_height", "_surface_quad", "_create_water_material", "_spawn_multimesh_details"]:
    assert token in controller, token
for token in ["RealmBadge", "ResourceDock", "Minimap", "BottomDock", "WorldScale"]:
    assert token in hud_scene, token
assert "zoom_value = clampf" in camera and "3.6" in camera
print("PASS world visual upgrade contract")
