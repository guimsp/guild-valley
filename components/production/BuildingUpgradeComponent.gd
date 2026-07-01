extends Node

# Standalone child component for managing building upgrades and improvements
var building: Node = null

var building_level: int = 1
var is_upgrading: bool = false
var upgrade_timer: float = 0.0
var improvements: Dictionary = {
	"storage_vault": 0,      # Max level 3
	"deep_shelving": 0,      # Max level 3
	"extra_workbench": 0,    # Max level 2
	"bunkhouse": 0,          # Max level 2
	"iron_reinforcements": 0,# Max level 3
	"ornate_facade": 0,      # Max level 3
	"strongbox_vault": 0,    # Max level 3
	"auto_gathering": 0,     # Max level 1
	"storefront": 0          # Max level 1
}

signal upgrade_started(next_level: int, time: float)
signal upgrade_completed(new_level: int)
signal improvement_purchased(improvement_id: String, new_level: int)

func setup(p_building: Node) -> void:
	building = p_building
	# Sync initial level if available
	if "building_level" in building:
		building_level = building.building_level

func initiate_level_upgrade() -> void:
	if not building:
		return
		
	var next_lvl = building_level + 1
	var requirements = building.get("UPGRADE_REQUIREMENTS") as Dictionary
	if not requirements or not requirements.has(next_lvl):
		GameState.spawn_ui_floating_text("Building is already at maximum level!")
		return
		
	var req = requirements[next_lvl]
	var career_id = "craftsman"
	var b_data = building.get("building_data")
	if b_data and b_data.career != "":
		career_id = b_data.career
		
	var player_career_level = GameState.career_levels.get(career_id, 1)
	if player_career_level < req.profession_level:
		GameState.spawn_ui_floating_text("Requires %s Level %d!" % [career_id.capitalize(), req.profession_level])
		return
		
	if GameState.gold < req.gold_cost:
		GameState.spawn_ui_floating_text("Requires %d Gold!" % req.gold_cost)
		return
		
	# Check architectural blueprint requirement for Level 3+
	var bp_in_player = false
	var bp_in_building = false
	if next_lvl >= 3:
		if GameState.player_inventory and GameState.player_inventory.has_item("architectural_blueprint", 1):
			bp_in_player = true
		else:
			var target_b_storage = building.get("building_storage") if "building_storage" in building else null
			if not target_b_storage and "inventory" in building:
				target_b_storage = building.inventory
			if target_b_storage and target_b_storage.has_item("architectural_blueprint", 1):
				bp_in_building = true
				
		if not bp_in_player and not bp_in_building:
			GameState.spawn_ui_floating_text("Upgrade requires 1x Architectural Blueprint!")
			return

	# Consume blueprint
	if bp_in_player:
		GameState.player_inventory.remove_item("architectural_blueprint", 1)
	elif bp_in_building:
		var target_b_storage = building.get("building_storage") if "building_storage" in building else null
		if not target_b_storage and "inventory" in building:
			target_b_storage = building.inventory
		if target_b_storage:
			target_b_storage.remove_item("architectural_blueprint", 1)

	GameState.next_change_reason = "Building Upgrade"
	GameState.next_change_detail = building.name if building else "Building"
	GameState.gold -= req.gold_cost
	is_upgrading = true
	upgrade_timer = req.time
	
	if building.has_method("reset_all_workers"):
		building.reset_all_workers()
		
	GameState.spawn_ui_floating_text("Renovation started: %d seconds!" % int(req.time))
	upgrade_started.emit(next_lvl, req.time)

func purchase_improvement(improvement_id: String) -> void:
	if not building:
		return
		
	var definitions = building.get("IMPROVEMENT_DEFINITIONS") as Dictionary
	if not definitions or not definitions.has(improvement_id):
		return
		
	var def = definitions[improvement_id]
	var current_lvl = improvements.get(improvement_id, 0)
	if current_lvl >= def.max_level:
		GameState.spawn_ui_floating_text("Improvement already at maximum level!")
		return
		
	var cost = def.cost
	if GameState.gold < cost:
		GameState.spawn_ui_floating_text("Not enough gold!")
		return
		
	GameState.next_change_reason = "Upgrade Improvement"
	GameState.next_change_detail = def.name if "name" in def else improvement_id
	GameState.gold -= cost
	improvements[improvement_id] = current_lvl + 1
	
	if building.has_method("recalculate_building_parameters"):
		building.recalculate_building_parameters()
		
	GameState.spawn_ui_floating_text("%s Purchased!" % def.name)
	
	if building and (building.ownership_type == "Player" or building.get("owner_id") == "Player"):
		var career_id = "craftsman"
		var b_data = building.get("building_data")
		if b_data and b_data.career != "":
			career_id = b_data.career
		GameState.add_xp(career_id, 10)
		
	improvement_purchased.emit(improvement_id, improvements[improvement_id])

func tick_upgrade(delta: float) -> void:
	if not building:
		return
		
	if is_upgrading:
		upgrade_timer -= delta
		if upgrade_timer <= 0.0:
			is_upgrading = false
			building_level += 1
			
			if building and (building.ownership_type == "Player" or building.get("owner_id") == "Player"):
				var career_id = "craftsman"
				var b_data = building.get("building_data")
				if b_data and b_data.career != "":
					career_id = b_data.career
				
				if building_level == 2:
					GameState.add_xp(career_id, 50)
				elif building_level == 3:
					GameState.add_xp(career_id, 100)
			
			if "building_data" in building and building.building_data:
				building.building_data.building_level = building_level
				
			if building.has_method("recalculate_building_parameters"):
				building.recalculate_building_parameters()
				
			var b_name = building.name.replace("Interior_", "")
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if not hud:
				hud = get_tree().get_first_node_in_group("game_hud")
			if hud:
				hud._spawn_floating_text("%s upgraded to Level %d!" % [b_name, building_level], building.global_position)
				
			GameState.spawn_ui_floating_text("%s upgraded to Level %d!" % [b_name, building_level])
			
			for ui in get_tree().get_nodes_in_group("BuildingUIs"):
				if ui.visible and ui.get("_building") == building:
					ui.call_deferred("refresh")
					
			upgrade_completed.emit(building_level)
