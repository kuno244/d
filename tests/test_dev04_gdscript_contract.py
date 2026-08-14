from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
required={
'scripts/city/city_grid_service.gd':['class_name CityGridService','world_to_grid','grid_to_world','can_place','reserve','begin_move','cancel_move'],
'scripts/economy/economy_service.gd':['class_name EconomyService','can_afford','spend_atomic','add_resource','set_capacity'],
'scripts/economy/production_service.gd':['class_name ProductionService','accrue','claim','offline_cap_sec'],
'scripts/economy/modifier_service.gd':['class_name ModifierService','aggregate','apply'],
'scripts/economy/population_service.gd':['class_name PopulationService','recalculate'],
'scripts/city/construction_service.gd':['class_name ConstructionService','start_upgrade','start_build','complete_if_due','cancel','speed_up','construction_queues','builder_slots','max_future_builder_slots'],
'scripts/city/city_power_service.gd':['class_name CityPowerService','calculate'],
'scripts/troops/training_service.gd':['class_name TrainingService','start_training','complete_due','training_queue','speed_up'],
'scripts/troops/troop_inventory.gd':['class_name TroopInventory','add','get_count'],
'scripts/research/research_service.gd':['class_name ResearchService','can_start','start_research','complete_if_due','research_queue','speed_up','citadel_requirement'],
'scripts/city/build_mode_controller.gd':['class_name BuildModeController','begin_build','confirm_build','cancel_build','begin_move','confirm_move','cancel_move','begin_move_decoration','confirm_move_decoration','cancel_move_decoration','grid.reserve','release_reservation'],
'scripts/city/building_runtime.gd':['class_name CityBuildingView','configure','update_lod'],
'scripts/ui/city_hud.gd':['class_name CityHUD','refresh_resources','open_build_menu','open_research','open_troops'],
}
for rel,tokens in required.items():
    p=ROOT/rel; assert p.exists(),rel
    s=p.read_text()
    for token in tokens: assert token in s,(rel,token)
# DataRegistry must include new datasets without new autoload proliferation.
dr=(ROOT/'scripts/data/data_registry.gd').read_text()
for key in ['city','economy']: assert f'"{key}"' in dr,key
proj=(ROOT/'project.godot').read_text()
for forbidden in ['EconomyService=','ConstructionService=','TrainingService=','ResearchService=','AssetService=']:
    assert forbidden not in proj,forbidden

# GDScript save normalization must filter malformed queue entries, matching the executable Python save contract.
save_gd=(ROOT/'scripts/save/save_service.gd').read_text()
for token in ['sanitized_construction_queues','sanitized_training_queues']:
    assert token in save_gd,token


city_script=(ROOT/'scripts/city/city_controller.gd').read_text()
for token in ['create_decoration_preview','set_decoration_placement_feedback','clear_decoration_placement_feedback']:
    assert token in city_script,token
build_mode=(ROOT/'scripts/city/build_mode_controller.gd').read_text()
assert 'decoration_preview = city.create_decoration_preview' in build_mode


# Production time must stop exactly at upgrade boundaries.
city_script=(ROOT/'scripts/city/city_controller.gd').read_text()
upgrade_segment=city_script.split('func request_upgrade',1)[1].split('func request_move',1)[0]
assert 'production.accrue(instance, definition, now)' in upgrade_segment
assert upgrade_segment.index('production.accrue(instance, definition, now)') < upgrade_segment.index('construction.start_upgrade')
cancel_segment=city_script.split('func request_cancel_construction',1)[1].split('func request_construction_speedup',1)[0]
assert 'construction.cancel(_instances_by_id(), now)' in cancel_segment


# CollisionShape3D must be a direct child of the CityBuildingView StaticBody3D.
runtime=(ROOT/'scripts/city/building_runtime.gd').read_text()
assert 'collision_root.add_child(node)' not in runtime
assert 'add_child(node)' in runtime
runtime_scene=(ROOT/'scenes/city/BuildingRuntime.tscn').read_text()
assert '[node name="CollisionRoot" type="Node3D" parent="."]' not in runtime_scene

print('PASS dev04 gdscript contract')
