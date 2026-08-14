from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
city=(ROOT/'scenes/city/City.tscn').read_text()
for token in ['CityHUD','BuildingRoot','DecorationRoot','PlacementRoot','SelectionLayer','UIRoot','BuildModeController']:
    assert token in city,token
# City scene no longer hardcodes production GLBs; runtime resolves asset_id via AssetService.
for bad in ['.glb"','assets/source/','assets/processed/','Meshy_AI_model']:
    assert bad not in city,bad
hud=(ROOT/'scenes/ui/CityHUD.tscn').read_text()
for label in ['Food','Wood','Stone','Gold','Build','Research','Troops','Heroes','World','Upgrade','Move','Info','Construction','Training','Research Tree','Placement','Confirm','Rotate','Cancel','Placed Decorations']:
    assert label in hud,label
for bad in ['Music','SFX','Voice']:
    assert bad not in hud,bad
# Touch targets should be mobile-sized.
assert 'custom_minimum_size = Vector2(120, 52)' in hud or 'custom_minimum_size = Vector2(120.0, 52.0)' in hud
city_script=(ROOT/'scripts/city/city_controller.gd').read_text()
for token in ['confirm_placement','cancel_placement','rotate_placement','request_move_decoration','request_remove_decoration']:
    assert token in city_script,token
hud_script=(ROOT/'scripts/ui/city_hud.gd').read_text()
for token in ['refresh_placement_mode','_on_placement_confirm_pressed','_on_placement_cancel_pressed','_on_placement_rotate_pressed','_request_move_decoration','_request_remove_decoration']:
    assert token in hud_script,token
print('PASS dev04 UI scene contract')

# Building panel must expose real upgrade eligibility/stat deltas instead of a mock preview.
for token in ['get_upgrade_status','upgrade_available','upgrade_status','requirements','can_collect']:
    assert token in city_script,token
for token in ['_stat_delta_text','upgrade_button.disabled','move_button.disabled','collect_button.disabled','Requirements:']:
    assert token in hud_script,token
print('PASS dev04 building panel status contract')
