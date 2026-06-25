# game_saver.gd
extends RefCounted

func save_game(manager: Node) -> void:
	var tree = manager.get_tree()
	var player = tree.get_first_node_in_group("Player")
	var player_pos = player.global_position if player else Vector2(500.0, 300.0)
	
	_update_relationship_db(tree)
	
	var save_dict = {
		"player": _serialize_player(player, player_pos),
		"time": {
			"minutes": TimeManager.time_minutes,
			"hours": TimeManager.time_hours,
			"days": TimeManager.time_days
		},
		"buildings": _serialize_buildings(tree),
		"doors": _serialize_doors(tree),
		"construction_sites": _serialize_construction_sites(tree),
		"npcs": _serialize_npcs(tree),
		"interiors": {
			"allocated": GameState.allocated_interiors,
			"next_index": GameState.next_interior_index
		},
		"quests": QuestManager.get_save_data(),
		"relationships": GameState.relationship_db,
		"is_married": GameState.is_married,
		"spouse_npc_id": GameState.spouse_npc_id,
		"completed_relation_quests": GameState.completed_relation_quests,
		"active_trial_recipes": GameState.active_trial_recipes,
		"shortage_days": manager.get_node("/root/EconomyManager").shortage_days if manager.has_node("/root/EconomyManager") else {},
		"province_prosperity": ProsperityManager.province_prosperity
	}
	
	var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict, "  "))
		file.close()
		print("[GameState] Game Saved to user://savegame.json")
		GameState.spawn_ui_floating_text("Game Saved!")

func _copy_props(from_obj: Object, to_dict: Dictionary, props: Array) -> void:
	for prop in props:
		if prop in from_obj:
			to_dict[prop] = from_obj.get(prop)

func _serialize_player(player: Node, player_pos: Vector2) -> Dictionary:
	var player_inv = []
	if GameState.player_inventory:
		for slot in GameState.player_inventory.slots:
			if slot.get("item") and slot["item"] is Resource:
				player_inv.append({
					"item_path": slot["item"].resource_path,
					"amount": slot["amount"]
				})
				
	return {
		"player_name": GameState.player_name,
		"rival_ai_active": GameState.rival_ai_active,
		"gold": GameState.gold,
		"bank_balance": GameState.bank_balance,
		"influence": GameState.influence,
		"permanent_influence": GameState.permanent_influence,
		"title_level": GameState.title_level,
		"position": [player_pos.x, player_pos.y],
		"careers": GameState.career_levels,
		"xp": GameState.career_xp,
		"inventory": player_inv,
		"equipment": player.get_node("EquipmentComponent").serialize() if player and player.has_node("EquipmentComponent") else {},
		"wealth_ledger": GameState.wealth_ledger,
		"character_resource": player.character_resource.to_dictionary() if player and "character_resource" in player and player.character_resource else {}
	}

func _serialize_buildings(tree: SceneTree) -> Array:
	var grid_spawned = {}
	for grid in tree.get_nodes_in_group("WheatFieldGrids") + tree.get_nodes_in_group("CottonPatchGrids"):
		if "crop_nodes" in grid:
			for crop in grid.crop_nodes:
				if is_instance_valid(crop):
					grid_spawned[crop] = true

	var saved_nodes = {}
	var buildings_data = []
	var groups = ["Beds", "MarketStall", "CraftingBenches", "WheatFieldGrids", "CottonPatchGrids", "OreMines", "Mills", "Smelters", "Looms", "WheatFields", "CottonPlants", "Houses", "Banks", "Inns", "PaperMakers", "PrintingPresses", "Bakeries", "Taverns", "Farmsteads", "Distilleries", "EventHalls", "Warehouses"]
	
	for group_name in groups:
		for node in tree.get_nodes_in_group(group_name):
			if not is_instance_valid(node) or node in saved_nodes:
				continue
			saved_nodes[node] = true
			if (group_name == "WheatFields" or group_name == "CottonPlants") and grid_spawned.has(node):
				continue
				
			var path = GameState.get_scene_path_for_node(node)
			if path == "":
				continue
				
			var parent_node = node.get_parent()
			var parent_path = String(tree.root.get_path_to(parent_node)) if parent_node else ""
				
			var data = {
				"scene_path": path,
				"position": [node.global_position.x, node.global_position.y],
				"parent_path": parent_path
			}
			
			_serialize_building_details(tree, node, data)
			buildings_data.append(data)
			
	return buildings_data

func _serialize_building_details(tree: SceneTree, node: Node, data: Dictionary) -> void:
	if "building_data" in node and node.building_data:
		data["building_data_path"] = node.building_data.resource_path
	
	_copy_props(node, data, [
		"ownership_type", "owner_id", "rent_days_remaining",
		"is_rental", "is_occupied", "rent_cost", "total_income_generated",
		"daily_production", "lifetime_production", "custom_prices",
		"building_level", "is_upgrading", "upgrade_timer",
		"improvements", "min_retained_stock",
		"unlocked_expansion_zones", "wall_tier", "security_rating"
	])
		
	if "hired_employees" in node:
		data["hired_employees"] = _serialize_employees(tree, node.hired_employees)
		
	if "hireable_candidates" in node:
		var serialized_cands = []
		for cand in node.hireable_candidates:
			if is_instance_valid(cand):
				serialized_cands.append(cand.npc_name)
		data["hireable_candidates"] = serialized_cands
		
	var sbox = GameState.ensure_strongbox(node)
	if sbox:
		data["strongbox_gold"] = sbox.strongbox_gold
		data["transaction_ledger"] = sbox.transaction_ledger
	
	if "inventory" in node and node.inventory:
		data["inventory"] = _serialize_inventory_slots(node.inventory.slots)
		
	if "building_storage" in node and node.building_storage:
		data["building_storage"] = _serialize_inventory_slots(node.building_storage.slots)

func _serialize_inventory_slots(slots: Array) -> Array:
	var list = []
	for slot in slots:
		if slot.get("item"):
			list.append({
				"item_path": slot["item"].resource_path,
				"amount": slot["amount"]
			})
	return list

func _serialize_employees(tree: SceneTree, hired_employees: Array) -> Array:
	var serialized_emps = []
	for emp in hired_employees:
		var emp_copy = emp.duplicate(true)
		var npc = emp.get("npc_ref")
		if is_instance_valid(npc):
			emp_copy["npc_name"] = npc.npc_name
			_copy_props(npc, emp_copy, [
				"skills_data", "salary", "speed", "productivity", "province",
				"worker_state", "commercial_route_current_waypoint_index",
				"commercial_route_cargo_item_id", "commercial_route_cargo_amount",
				"commercial_route_gold_carried", "current_stop_index"
			])
			if npc.cargo_inventory:
				emp_copy["cargo_inventory"] = _serialize_inventory_slots(npc.cargo_inventory.slots)
			if "character_resource" in npc and npc.character_resource:
				emp_copy["character_resource"] = npc.character_resource.to_dictionary()
				
		if emp_copy.has("npc_ref"):
			emp_copy.erase("npc_ref")
		if emp_copy.has("shift_worker_ref"):
			emp_copy.erase("shift_worker_ref")
			
		var active_route = emp.get("active_commercial_route")
		if active_route != null:
			emp_copy["active_commercial_route"] = _serialize_trade_route(tree, active_route)
		serialized_emps.append(emp_copy)
	return serialized_emps

func _serialize_trade_route(tree: SceneTree, active_route: Resource) -> Dictionary:
	if active_route.get("route_stops") != null:
		var stops_data = []
		for stop in active_route.route_stops:
			if is_instance_valid(stop):
				stops_data.append({
					"target_building_path": String(tree.root.get_path_to(stop.target_building)) if is_instance_valid(stop.target_building) else "",
					"action_type": stop.action_type,
					"item_id": stop.item_id,
					"target_quantity": stop.target_quantity,
					"minimum_sell_price": stop.minimum_sell_price
				})
		return {
			"is_global_logistics": true,
			"route_name": active_route.route_name,
			"route_stops": stops_data
		}
	else:
		var serialized_route = {
			"route_name": active_route.route_name,
			"source_building_path": String(tree.root.get_path_to(active_route.source_building_ref)) if is_instance_valid(active_route.source_building_ref) else "",
			"target_item_id": active_route.target_item_id,
			"target_amount": active_route.target_amount,
			"minimum_sell_price": active_route.minimum_sell_price,
			"market_waypoints_paths": []
		}
		for wp in active_route.market_waypoints:
			if is_instance_valid(wp):
				serialized_route["market_waypoints_paths"].append(String(tree.root.get_path_to(wp)))
		return serialized_route

func _serialize_doors(tree: SceneTree) -> Array:
	var doors_data = []
	for node in tree.get_nodes_in_group("TeleportTriggers"):
		if is_instance_valid(node):
			var data = {"path": String(tree.root.get_path_to(node))}
			_copy_props(node, data, ["ownership_type", "owner_id", "rent_days_remaining"])
			doors_data.append(data)
	return doors_data

func _serialize_construction_sites(tree: SceneTree) -> Array:
	var construction_data = []
	for node in tree.get_nodes_in_group("ConstructionSites"):
		if not is_instance_valid(node):
			continue
		var parent_node = node.get_parent()
		var parent_path = String(tree.root.get_path_to(parent_node)) if parent_node else ""
		var data = {
			"position": [node.global_position.x, node.global_position.y],
			"parent_path": parent_path,
			"target_scene_path": node.target_scene_path,
			"build_time": node.build_time,
			"building_name": node.building_name,
			"elapsed_time": node.get("_elapsed_time") if "_elapsed_time" in node else 0.0,
			"is_rental": node.get("is_rental") if "is_rental" in node else false
		}
		construction_data.append(data)
	return construction_data

func _serialize_npcs(tree: SceneTree) -> Array:
	var npcs_data = []
	for npc in tree.get_nodes_in_group("NPCs"):
		if is_instance_valid(npc) and npc is CharacterBody2D:
			if npc.get("roams_interior_only") or npc.get("is_quest_npc"):
				continue
			var npc_dict = {
				"position": [npc.global_position.x, npc.global_position.y]
			}
			_copy_props(npc, npc_dict, [
				"npc_name", "province", "career", "skills_data", "salary",
				"speed", "productivity", "is_hired", "worker_state",
				"npc_type", "quest_npc_id"
			])
			if npc.has_node("EquipmentComponent"):
				npc_dict["equipment"] = npc.get_node("EquipmentComponent").serialize()
			if npc.is_hired and is_instance_valid(npc.hired_by_building):
				npc_dict["hired_by_building_path"] = String(tree.root.get_path_to(npc.hired_by_building))
			if "character_resource" in npc and npc.character_resource:
				npc_dict["character_resource"] = npc.character_resource.to_dictionary()
			npcs_data.append(npc_dict)
	return npcs_data

func _update_relationship_db(tree: SceneTree) -> void:
	for npc in tree.get_nodes_in_group("RelationNPCs"):
		if is_instance_valid(npc) and npc.has_node("RelationshipComponent"):
			var rel = npc.get_node("RelationshipComponent")
			GameState.relationship_db[npc.quest_npc_id] = rel.get_save_data()
