# game_loader.gd
extends RefCounted

func load_game(manager: Node) -> void:
	if not FileAccess.file_exists("user://savegame.json"):
		print("[GameState] Save file user://savegame.json does not exist!")
		GameState.spawn_ui_floating_text("No Save File!")
		return
		
	var file = FileAccess.open("user://savegame.json", FileAccess.READ)
	if not file:
		return
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("[GameState] JSON parse error: ", json.get_error_message())
		return
		
	var save_dict = json.data
	manager.is_loading_game = true
	
	var tree = manager.get_tree()
	tree.paused = false
	var hud = tree.get_first_node_in_group("PlayerHUD")
	if hud:
		if hud.has_method("exit_placement_mode_external"):
			hud.exit_placement_mode_external()
		if "pause_menu" in hud and hud.pause_menu and hud.pause_menu.visible:
			hud.toggle_pause_menu()
		
	_deserialize_core_states(manager, save_dict)
	
	var player = tree.get_first_node_in_group("Player")
	_deserialize_player_instance(save_dict.get("player", {}), player)
	
	_clear_existing_instances(tree)
	
	_deserialize_buildings(tree, save_dict.get("buildings", []), player)
	_deserialize_doors(tree, save_dict.get("doors", []))
	_deserialize_construction_sites(tree, save_dict.get("construction_sites", []), player)
	
	var spawned_npcs = _deserialize_npcs(tree, save_dict.get("npcs", []), player)
	_restore_candidates_references(tree, spawned_npcs)
	
	if hud:
		if hud.has_method("update_hud_values"):
			hud.update_hud_values()
		if hud.has_method("update_inventory_panel"):
			hud.update_inventory_panel()
			
	GameState.recalculate_career_stats()
	
	# Auto reconnect lots to buildings after loading
	var world = tree.current_scene
	if world and world.has_method("reconnect_lots_to_buildings"):
		world.call("reconnect_lots_to_buildings")
		
	print("[GameState] Game Loaded from user://savegame.json")
	GameState.spawn_ui_floating_text("Game Loaded!")
	manager.is_loading_game = false

func _restore_props(to_obj: Object, from_dict: Dictionary, props: Array) -> void:
	for prop in props:
		if prop in to_obj and from_dict.has(prop):
			var val = from_dict[prop]
			var current_val = to_obj.get(prop)
			if current_val is int:
				to_obj.set(prop, int(val))
			elif current_val is float:
				to_obj.set(prop, float(val))
			else:
				to_obj.set(prop, val)

func _deserialize_core_states(manager: Node, save_dict: Dictionary) -> void:
	var p_data = save_dict.get("player", {})
	_restore_props(GameState, p_data, [
		"player_name", "rival_ai_active", "gold", "bank_balance",
		"influence", "permanent_influence", "title_level", "career_levels", "career_xp",
		"wealth_ledger"
	])
	GameState.active_trial_recipes = save_dict.get("active_trial_recipes", [])
	
	var int_data = save_dict.get("interiors", {})
	GameState.allocated_interiors = int_data.get("allocated", {})
	GameState.next_interior_index = int_data.get("next_index", 0)
	
	var t_data = save_dict.get("time", {})
	TimeManager.time_minutes = t_data.get("minutes", 0.0)
	TimeManager.time_hours = t_data.get("hours", 6)
	TimeManager.time_days = t_data.get("days", 1)
	TimeManager._last_emitted_minute = int(TimeManager.time_minutes)
	TimeManager.time_changed.emit(TimeManager.time_hours, TimeManager._last_emitted_minute, TimeManager.time_days)
	
	QuestManager.load_save_data(save_dict.get("quests", {}))
	GameState.relationship_db = save_dict.get("relationships", {})
	GameState.is_married = save_dict.get("is_married", false)
	GameState.spouse_npc_id = save_dict.get("spouse_npc_id", "")
	GameState.completed_relation_quests = save_dict.get("completed_relation_quests", [])
	
	var econ_mgr = manager.get_node_or_null("/root/EconomyManager")
	if econ_mgr:
		econ_mgr.shortage_days = save_dict.get("shortage_days", {})
		
	if save_dict.has("province_prosperity"):
		ProsperityManager.province_prosperity = save_dict["province_prosperity"]
		ProsperityManager.sync_settlements()

func _deserialize_player_instance(p_data: Dictionary, player: Node) -> void:
	if player:
		var pos_arr = p_data.get("position", [500.0, 300.0])
		player.global_position = Vector2(pos_arr[0], pos_arr[1])
		if player.has_node("EquipmentComponent") and p_data.has("equipment"):
			player.get_node("EquipmentComponent").deserialize(p_data["equipment"])
			player.recalculate_equipment_stats()
		if "character_resource" in player and p_data.has("character_resource") and not p_data["character_resource"].is_empty():
			if not player.character_resource:
				player.character_resource = CharacterResource.new()
			player.character_resource.from_dictionary(p_data["character_resource"])
		if "interactables_in_range" in player:
			player.interactables_in_range.clear()
			player.interactables_changed.emit()
		
		var camera = player.get_node_or_null("Camera2D")
		if camera and camera is Camera2D:
			camera.reset_smoothing()
			
	if GameState.player_inventory:
		GameState.player_inventory.clear()
		for slot in p_data.get("inventory", []):
			var path = slot.get("item_path", "")
			var amount = slot.get("amount", 0)
			if path != "" and amount > 0:
				var item = load(path)
				if item:
					GameState.player_inventory.add_item(item, amount)

func _clear_existing_instances(tree: SceneTree) -> void:
	for npc in tree.get_nodes_in_group("NPCs"):
		if is_instance_valid(npc):
			npc.queue_free()
			
	var groups_to_clear = ["Beds", "MarketStall", "CraftingBenches", "WheatFieldGrids", "CottonPatchGrids", "OreMines", "Mills", "Smelters", "Looms", "WheatFields", "CottonPlants", "ConstructionSites", "Houses", "Banks", "Inns", "PaperMakers", "PrintingPresses", "Bakeries", "Taverns", "Farmsteads", "Distilleries", "EventHalls", "Warehouses"]
	for group_name in groups_to_clear:
		for node in tree.get_nodes_in_group(group_name):
			if is_instance_valid(node):
				node.queue_free()

func _deserialize_buildings(tree: SceneTree, buildings_list: Array, player: Node) -> void:
	for b_data in buildings_list:
		var path = b_data.get("scene_path", "")
		var pos_arr = b_data.get("position", [0.0, 0.0])
		var parent_path = b_data.get("parent_path", "")
		
		if path == "":
			continue
			
		var parent_node = tree.root.get_node_or_null(parent_path) if parent_path != "" else null
		if not parent_node and player:
			parent_node = player.get_parent()
			
		var node = null
		var is_new = false
		if path == "res://components/market/market_stall.tscn" and parent_node:
			if parent_node.has_node("StorefrontStall"):
				node = parent_node.get_node("StorefrontStall")
			elif parent_node.has_node("StorageChest"):
				node = parent_node.get_node("StorageChest")
			else:
				if parent_node.is_in_group("Interiors") or parent_node.name.contains("Interior"):
					continue
				var scene = load(path)
				if not scene:
					continue
				node = scene.instantiate() as Node2D
				is_new = true
		elif path == "res://components/crafting/crafting_bench.tscn" and parent_node:
			if parent_node.has_node("CraftingBench"):
				node = parent_node.get_node("CraftingBench")
			else:
				var scene = load(path)
				if not scene:
					continue
				node = scene.instantiate() as Node2D
				is_new = true
		else:
			var scene = load(path)
			if not scene:
				continue
			node = scene.instantiate() as Node2D
			is_new = true
			
		_configure_deserialized_building(tree, node, b_data, is_new, parent_node)

func _configure_deserialized_building(tree: SceneTree, node: Node2D, b_data: Dictionary, is_new: bool, parent_node: Node) -> void:
	if "building_data" in node and b_data.has("building_data_path") and b_data["building_data_path"] != "":
		var res = load(b_data["building_data_path"])
		if res and res is BuildingData:
			node.building_data = res
		
	node.global_position = Vector2(b_data.get("position", [0.0, 0.0])[0], b_data.get("position", [0.0, 0.0])[1])
	
	_restore_props(node, b_data, [
		"ownership_type", "owner_id", "rent_days_remaining",
		"is_rental", "is_occupied", "rent_cost", "total_income_generated",
		"daily_production", "lifetime_production", "custom_prices",
		"building_level", "is_upgrading", "upgrade_timer",
		"improvements", "min_retained_stock",
		"unlocked_expansion_zones", "wall_tier", "security_rating"
	])
	
	if node.has_method("restore_expansion_zones"):
		node.restore_expansion_zones()
	
	if node.has_method("_update_door_state"):
		node._update_door_state()
			
	if "hired_employees" in node and b_data.has("hired_employees"):
		var emps = b_data["hired_employees"]
		for emp in emps:
			if emp.has("active_commercial_route") and emp["active_commercial_route"] != null:
				emp["active_commercial_route"] = _deserialize_trade_route(tree, emp["active_commercial_route"])
		node.hired_employees = emps
		
	if "hireable_candidates" in node and b_data.has("hireable_candidates"):
		node.hireable_candidates = b_data["hireable_candidates"]
		
	var sbox = GameState.ensure_strongbox(node)
	if sbox:
		sbox.strongbox_gold = int(b_data.get("strongbox_gold", 0))
		sbox.transaction_ledger = b_data.get("transaction_ledger", [])
	
	if is_new:
		if parent_node:
			parent_node.add_child(node)
		else:
			tree.root.add_child(node)
		
	if "inventory" in node and node.inventory:
		_deserialize_inventory_slots(node.inventory, b_data.get("inventory", []))
		
	if "building_storage" in node and node.building_storage:
		_deserialize_inventory_slots(node.building_storage, b_data.get("building_storage", []))
		
	if "improvements" in node and node.has_method("recalculate_building_parameters"):
		node.recalculate_building_parameters()

func _deserialize_trade_route(tree: SceneTree, route_dict: Dictionary) -> Resource:
	if route_dict.get("is_global_logistics", false) == true:
		var route = load("res://components/production/global_logistics_route.gd").new()
		route.route_name = route_dict.get("route_name", "Route")
		var stops: Array[Resource] = []
		for stop_data in route_dict.get("route_stops", []):
			var stop = load("res://components/production/trade_route_stop.gd").new()
			var b_path = stop_data.get("target_building_path", "")
			if b_path != "":
				stop.target_building = tree.root.get_node_or_null(b_path)
			stop.action_type = stop_data.get("action_type", "LOAD")
			stop.item_id = stop_data.get("item_id", "")
			stop.target_quantity = int(stop_data.get("target_quantity", 20))
			stop.minimum_sell_price = int(stop_data.get("minimum_sell_price", 0))
			stops.append(stop)
		route.route_stops = stops
		return route
	else:
		print("[GameState] Skipping legacy commercial route deserialization (deleted file).")
		return null

func _deserialize_inventory_slots(inventory_component: Node, slot_data_list: Array) -> void:
	inventory_component.clear()
	for slot in slot_data_list:
		var item_path = slot.get("item_path", "")
		var amount = slot.get("amount", 0)
		if item_path != "" and amount > 0:
			var item = load(item_path)
			if item:
				inventory_component.add_item(item, amount)

func _deserialize_doors(tree: SceneTree, doors_list: Array) -> void:
	for d_data in doors_list:
		var path = d_data.get("path", "")
		if path != "":
			var node = tree.root.get_node_or_null(path)
			if is_instance_valid(node):
				_restore_props(node, d_data, ["ownership_type", "owner_id", "rent_days_remaining"])

func _deserialize_construction_sites(tree: SceneTree, construction_list: Array, player: Node) -> void:
	for c_data in construction_list:
		var pos_arr = c_data.get("position", [0.0, 0.0])
		var parent_path = c_data.get("parent_path", "")
		
		var scene = load("res://components/placement/construction_site.tscn")
		if not scene:
			continue
			
		var node = scene.instantiate() as Node2D
		node.global_position = Vector2(pos_arr[0], pos_arr[1])
		_restore_props(node, c_data, ["target_scene_path", "build_time", "building_name", "is_rental"])
		if c_data.has("elapsed_time") and "_elapsed_time" in node:
			node._elapsed_time = float(c_data["elapsed_time"])
		
		var parent_node = tree.root.get_node_or_null(parent_path) if parent_path != "" else null
		if not parent_node and player:
			parent_node = player.get_parent()
			
		if parent_node:
			parent_node.add_child(node)
		else:
			tree.root.add_child(node)

func _deserialize_npcs(tree: SceneTree, npcs_list: Array, player: Node) -> Dictionary:
	var npc_scene = load("res://entities/npc/npc.tscn")
	var spawned_npcs = {}
	
	for n_data in npcs_list:
		if not npc_scene:
			continue
		var npc = npc_scene.instantiate() as CharacterBody2D
		npc.set("is_loaded", true)
		
		var pos_arr = n_data.get("position", [0.0, 0.0])
		npc.global_position = Vector2(pos_arr[0], pos_arr[1])
		
		_restore_props(npc, n_data, [
			"npc_name", "province", "career", "skills_data",
			"salary", "speed", "is_hired", "worker_state",
			"npc_type", "quest_npc_id"
		])
		if n_data.has("productivity") and "productivity" in npc:
			npc.productivity = n_data["productivity"]
		
		if player:
			player.get_parent().add_child(npc)
		else:
			tree.root.add_child(npc)
			
		if npc.has_node("EquipmentComponent") and n_data.has("equipment"):
			npc.get_node("EquipmentComponent").deserialize(n_data["equipment"])
			npc.recalculate_equipment_stats()
			
		if "character_resource" in npc and n_data.has("character_resource") and not n_data["character_resource"].is_empty():
			if not npc.character_resource:
				npc.character_resource = CharacterResource.new()
			npc.character_resource.from_dictionary(n_data["character_resource"])
			
		spawned_npcs[npc.npc_name] = npc
		_wire_hired_npc(tree, npc, n_data)
		
	return spawned_npcs

func _wire_hired_npc(tree: SceneTree, npc: CharacterBody2D, n_data: Dictionary) -> void:
	if npc.is_hired and n_data.has("hired_by_building_path"):
		var b_path = n_data["hired_by_building_path"]
		var building = tree.root.get_node_or_null(b_path)
		if is_instance_valid(building):
			npc.hired_by_building = building
			
			if "hired_employees" in building:
				for emp in building.hired_employees:
					if emp.get("name") == npc.npc_name:
						emp["npc_ref"] = npc
						if "character_resource" in npc:
							if not npc.character_resource:
								npc.character_resource = CharacterResource.new()
							if emp.has("character_resource") and not emp["character_resource"].is_empty():
								npc.character_resource.from_dictionary(emp["character_resource"])
						if emp.get("active_commercial_route") != null:
							var route = emp["active_commercial_route"]
							npc.active_commercial_route = route
							_restore_route_state(tree, npc, emp, route)
						break

func _restore_route_state(tree: SceneTree, npc: CharacterBody2D, emp: Dictionary, route: Resource) -> void:
	if route.get("route_stops") != null:
		npc.current_stop_index = int(emp.get("current_stop_index", 0))
		if npc.cargo_inventory:
			npc.cargo_inventory.clear()
			if emp.has("cargo_inventory"):
				for slot_data in emp["cargo_inventory"]:
					var res = load(slot_data["item_path"])
					if res:
						npc.cargo_inventory.add_item(res, int(slot_data["amount"]))
		
		if npc.worker_state == "internal_route_transit":
			var idx = npc.current_stop_index
			if idx < route.route_stops.size():
				var stop = route.route_stops[idx]
				if stop and is_instance_valid(stop.target_building):
					var target_pos = stop.target_building.get_interaction_position() if stop.target_building.has_method("get_interaction_position") else stop.target_building.global_position
					_set_npc_navigation_target(npc, target_pos)
	else:
		npc.commercial_route_current_waypoint_index = int(emp.get("commercial_route_current_waypoint_index", 0))
		npc.commercial_route_cargo_item_id = emp.get("commercial_route_cargo_item_id", "")
		npc.commercial_route_cargo_amount = int(emp.get("commercial_route_cargo_amount", 0))
		npc.commercial_route_gold_carried = int(emp.get("commercial_route_gold_carried", 0))
		
		if npc.worker_state == "commercial_route_transit":
			var idx = npc.commercial_route_current_waypoint_index
			if npc.active_commercial_route and idx < npc.active_commercial_route.market_waypoints.size():
				var wp = npc.active_commercial_route.market_waypoints[idx]
				if is_instance_valid(wp):
					var target_pos = wp.get_interaction_position() if wp.has_method("get_interaction_position") else wp.global_position
					_set_npc_navigation_target(npc, target_pos)
		elif npc.worker_state in ["commercial_route_returning", "commercial_route_loading"]:
			if is_instance_valid(npc.hired_by_building):
				var target_pos = npc.hired_by_building.get_interaction_position()
				_set_npc_navigation_target(npc, target_pos)

func _set_npc_navigation_target(npc: CharacterBody2D, target_pos: Vector2) -> void:
	if npc.nav_motor and is_instance_valid(npc.nav_motor.nav_agent):
		npc.nav_motor.nav_agent.target_position = target_pos
	else:
		npc.call("_generate_path", target_pos)

func _restore_candidates_references(tree: SceneTree, spawned_npcs: Dictionary) -> void:
	var groups_to_clear = ["Beds", "MarketStall", "CraftingBenches", "WheatFieldGrids", "CottonPatchGrids", "OreMines", "Mills", "Smelters", "Looms", "WheatFields", "CottonPlants", "ConstructionSites", "Houses", "Banks", "Inns", "PaperMakers", "PrintingPresses", "Bakeries", "Taverns", "Farmsteads", "Distilleries", "EventHalls", "Warehouses"]
	for group_name in groups_to_clear:
		for building in tree.get_nodes_in_group(group_name):
			if is_instance_valid(building) and "hireable_candidates" in building:
				var restored_cands = []
				for cand_item in building.hireable_candidates:
					if cand_item is String:
						if spawned_npcs.has(cand_item):
							restored_cands.append(spawned_npcs[cand_item])
					elif is_instance_valid(cand_item):
						restored_cands.append(cand_item)
				building.hireable_candidates = restored_cands
