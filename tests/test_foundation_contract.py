from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
required=[
 'scenes/boot/Boot.tscn','scenes/frontend/MainMenu.tscn','scenes/city/City.tscn','scenes/city/BuildingRuntime.tscn','scenes/ui/CityHUD.tscn',
 'scripts/boot/boot.gd','scripts/frontend/main_menu.gd','scripts/city/city_controller.gd','scripts/city/building_runtime.gd',
 'scripts/city/strategy_camera.gd','scripts/city/building_info_view_model.gd','scripts/assets/asset_service.gd','scripts/save/save_service.gd','scripts/data/data_registry.gd']
for rel in required: assert (ROOT/rel).exists(),rel
city=(ROOT/'scenes/city/City.tscn').read_text()
# DEVELOPMENT 04 intentionally replaced hardcoded GLB instances with persisted runtime views.
for token in ['BuildingRoot','DecorationRoot','PlacementRoot','BuildModeController','CityHUD']:
    assert token in city,token
for forbidden in ['assets/source/','assets/processed/','Meshy_AI_model','.glb"']:
    assert forbidden.lower() not in city.lower(),forbidden
controller=(ROOT/'scripts/city/city_controller.gd').read_text()
for token in ['DataRegistry.asset_service','spawn_building_view','create_building_state','refresh_derived_state','request_upgrade','request_train','request_research']:
    assert token in controller,token
boot=(ROOT/'scripts/boot/boot.gd').read_text()
for call in ['DataRegistry.initialize','SaveService.load_or_create','SaveService.validate','SceneRouter.goto_frontend']:
    assert call in boot,call
menu=(ROOT/'scenes/frontend/MainMenu.tscn').read_text()
for label in ['New Game','Continue','Settings','Quit','Graphics preset','Test resolution','Window mode','Camera sensitivity','UI scale']:
    assert label in menu,label
print('PASS foundation contract')
