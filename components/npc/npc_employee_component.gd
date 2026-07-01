extends Node

var npc: CharacterBody2D = null

func setup(p_npc: CharacterBody2D) -> void:
	npc = p_npc
	
	var pm = npc.get_node_or_null("/root/PoliticsManager")
	if pm:
		pm.law_changed.connect(_on_law_changed)

func gain_profession_xp(career_id: String, amount: int) -> void:
	if not npc.skills_data.has(career_id):
		return
		
	var data = npc.skills_data[career_id]
	var lvl = data["level"]
	if lvl in [3, 6, 9]:
		data["xp"] = 0
		return
		
	data["xp"] += amount
	var xp_to_next: int = int(round(100 * pow(1.5, data["level"] - 1)))
	
	while data["xp"] >= xp_to_next:
		data["xp"] -= xp_to_next
		data["level"] += 1
		print("[NPC] %s Leveled Up %s to Lvl %d!" % [npc.npc_name, career_id.capitalize(), data["level"]])
		
		var hud = npc.get_tree().get_first_node_in_group("PlayerHUD")
		if hud:
			if hud.has_method("_spawn_floating_text"):
				hud._spawn_floating_text("%s Leveled Up: Lvl %d!" % [career_id.capitalize(), data["level"]], npc.global_position)
			if hud.get("_building_ui_instance") != null and is_instance_valid(hud._building_ui_instance) and hud._building_ui_instance.has_method("refresh"):
				hud._building_ui_instance.refresh()
				
		lvl = data["level"]
		if lvl in [3, 6, 9]:
			data["xp"] = 0
			if hud and hud.has_method("_spawn_floating_text"):
				hud._spawn_floating_text("%s Locked at Lvl %d! Needs Breakthrough!" % [career_id.capitalize(), lvl], npc.global_position)
			break
			
		xp_to_next = int(round(100 * pow(1.5, data["level"] - 1)))

func go_to_workshop(building: Node2D) -> void:
	npc.npc_type = 0 # TYPE_EMPLOYEE
	npc.is_hired = true
	npc.hired_by_building = building
	npc.worker_state = "traveling_to_workshop"
	npc.limbo_timer = 0.0
	
	if npc.animated_sprite:
		if building.ownership_type == "Player":
			npc.animated_sprite.modulate = Color(0.6, 1.0, 0.6) # Greenish
		else:
			npc.animated_sprite.modulate = Color(1.0, 0.6, 0.6) # Reddish
			
	var target_pos = building.global_position
	if building.has_method("get_interaction_position"):
		target_pos = building.get_interaction_position()
	npc._generate_path(target_pos)

func resume_normal_behavior() -> void:
	if is_instance_valid(npc.hired_by_building):
		var eq = npc.get_node_or_null("EquipmentComponent")
		if eq:
			var current_tool = eq.get_equipped_item("tool")
			if current_tool != null:
				var target_storage = npc.hired_by_building.get("building_storage")
				if not target_storage:
					target_storage = npc.hired_by_building.get("inventory")
				if target_storage:
					target_storage.add_item(current_tool, 1)
				eq.unequip_item("tool")
	npc.is_hired = false
	npc.npc_type = 2 # TYPE_CONSUMER
	npc.hired_by_building = null
	npc.worker_state = "idle_at_workshop"
	npc.limbo_timer = 5.0
	npc.target_mega_node = null
	npc.is_gathering = false
	npc.current_mega_node = null
	
	if npc.animated_sprite:
		npc.animated_sprite.modulate = Color(0.6, 0.8, 1.0) # Reset to soft blue
		
	var lm = npc.get_node_or_null("/root/LogisticsManager")
	if lm:
		lm.erase_buffer(npc)

func _try_equip_tool_from_building(node_path: String) -> void:
	if is_instance_valid(npc.econ_brain) and npc.econ_brain.has_method("try_equip_tool_from_building"):
		npc.econ_brain.call("try_equip_tool_from_building", node_path)

func start_gathering_shift(node: Area2D) -> void:
	npc.target_mega_node = node
	npc.is_gathering = false
	npc.shift_timer = 120.0
	
	if is_instance_valid(node):
		var res_id = node.resource_type_id
		if npc.has_meta("selected_gather_resource"):
			res_id = npc.get_meta("selected_gather_resource")
			
		var required_type = GameState.get_required_tool_type_for_resource(res_id)
		var item_level = 1
		var econ = Engine.get_main_loop().root.get_node_or_null("EconomyManager")
		if econ and econ.item_database.has(res_id):
			item_level = econ.item_database[res_id].item_level
			
		var has_tool = false
		var eq = npc.get_node_or_null("EquipmentComponent")
		if eq and required_type != "":
			var current_tool = eq.get_equipped_item("tool")
			if current_tool != null and GameState.is_tool_sufficient(current_tool.id, required_type, item_level):
				has_tool = true
				
		var close_to_workshop = false
		if is_instance_valid(npc.hired_by_building):
			var doorstep = npc.hired_by_building.get_interaction_position()
			if npc.global_position.y >= 9000.0 or npc.global_position.distance_to(doorstep) <= 30.0:
				close_to_workshop = true
				
		if required_type != "" and not has_tool and not close_to_workshop:
			npc.worker_state = "traveling_to_workshop"
			if is_instance_valid(npc.hired_by_building):
				var target_pos = npc.hired_by_building.get_interaction_position()
				npc._generate_path(target_pos)
		else:
			npc.worker_state = "traveling_to_node"
			if required_type != "" and not has_tool:
				_try_equip_tool_from_building(node.get_path())
			# If inside, teleport outside first
			if npc.global_position.y > 9000.0 and is_instance_valid(npc.hired_by_building):
				npc._teleport(npc.hired_by_building.get_interaction_position())
			var target_pos = node.global_position
			npc._generate_path(target_pos)

func deposit_cargo() -> void:
	if is_instance_valid(npc.econ_brain) and npc.econ_brain.has_method("deposit_cargo"):
		npc.econ_brain.call("deposit_cargo")

func on_tool_broken() -> void:
	npc.is_gathering = false
	if is_instance_valid(npc.target_mega_node):
		npc.target_mega_node._on_body_exited(npc)
	npc.worker_state = "returning_to_workshop"
	if is_instance_valid(npc.hired_by_building):
		var target_pos = npc.hired_by_building.get_interaction_position()
		npc._generate_path(target_pos)

func _pause_employee_due_to_missing_tool() -> void:
	npc.is_gathering = false
	if is_instance_valid(npc.target_mega_node):
		npc.target_mega_node._on_body_exited(npc)
	npc.worker_state = "idle_at_workshop"
	if is_instance_valid(npc.hired_by_building):
		var target_pos = npc.hired_by_building.get_interaction_position()
		if npc.global_position.distance_to(target_pos) > 50.0:
			npc._generate_path(target_pos)
			
		for emp in npc.hired_by_building.hired_employees:
			if emp.get("npc_ref") == npc:
				emp["is_paused"] = true
				emp["active_gathering_node_path"] = ""
				break
				
	if GameState.has_method("add_alert"):
		var b_name = npc.hired_by_building.name.replace("Interior_", "") if is_instance_valid(npc.hired_by_building) else "Workshop"
		var msg = "%s cannot gather: No Tool equipped. Please open building management, click Equipment, and equip a tool." % npc.npc_name
		AlertManager.add_alert("Tool Missing", msg, "warning", npc.hired_by_building)
		
	var hud = npc.get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("_spawn_floating_text"):
		hud._spawn_floating_text("%s: Missing Tool!" % npc.npc_name, npc.global_position)

func transfer_to_building(new_building: Node2D) -> void:
	if not npc.is_hired or npc.hired_by_building == new_building:
		return
		
	var old_building = npc.hired_by_building
	npc.hired_by_building = new_building
	
	# Find employee dictionary in old building's hired_employees
	var emp_dict = {}
	if old_building and "hired_employees" in old_building:
		for i in range(old_building.hired_employees.size()):
			var emp = old_building.hired_employees[i]
			if emp.get("npc_ref") == npc or emp.get("name") == npc.npc_name:
				emp_dict = emp
				old_building.hired_employees.remove_at(i)
				break
				
	if emp_dict.is_empty():
		emp_dict = {
			"npc_ref": npc,
			"name": npc.npc_name,
			"salary": npc.salary,
			"career": npc.career,
			"levels": {
				"patreon": npc.patreon_level,
				"scholar": npc.scholar_level,
				"craftsman": npc.craftsman_level,
				"tailor": npc.tailor_level,
				"woodworker": npc.woodworker_level,
				"herbalist": npc.herbalist_level,
				"rogue": npc.rogue_level,
				"showman": npc.showman_level
			},
			"active_recipe_path": "",
			"craft_timer": 0.0,
			"craft_total_time": 0.0,
			"is_repeating": true,
			"auto_gather_on_shortage": false,
			"is_paused": false
		}
	
	emp_dict["active_recipe_path"] = ""
	emp_dict["active_gathering_node_path"] = ""
	emp_dict["is_paused"] = false
	if emp_dict.has("active_commercial_route"):
		emp_dict.erase("active_commercial_route")
	npc.active_commercial_route = null
	
	if "hired_employees" in new_building:
		new_building.hired_employees.append(emp_dict)
		
	npc.worker_state = "traveling_to_workshop"
	var target_pos = new_building.get_interaction_position() if new_building.has_method("get_interaction_position") else new_building.global_position
	npc._generate_path(target_pos)
		
	if npc.animated_sprite:
		if new_building.ownership_type == "Player":
			npc.animated_sprite.modulate = Color(0.6, 1.0, 0.6)
		else:
			npc.animated_sprite.modulate = Color(1.0, 0.6, 0.6)

func _on_law_changed(prov: String, law_id: String, is_active: bool) -> void:
	if not is_active:
		return
	if not npc.is_hired or not is_instance_valid(npc.hired_by_building):
		return
		
	var my_prov = npc.province
	if my_prov == "Unknown Province" or my_prov == "":
		my_prov = GameState.get_province_of_node(npc) if GameState else ""
		
	if my_prov != prov:
		return
		
	if is_instance_valid(npc.target_mega_node):
		var res_id = npc.target_mega_node.resource_type_id
		if law_id == "crown_forestry_protection" and res_id == "standard_timber":
			_trigger_worker_strike("Forestry Protection")
		elif law_id == "noble_game_preservation" and res_id == "venison":
			_trigger_worker_strike("Game Preservation")
			
	if law_id == "metallurgical_monopoly" and npc.hired_by_building.is_in_group("Smelters"):
		var sett = GameState.get_nearest_settlement(npc.hired_by_building)
		if sett and not sett.is_in_group("Cities"):
			_trigger_worker_strike("Metallurgical Monopoly")

func _trigger_worker_strike(reason: String) -> void:
	npc.is_gathering = false
	if is_instance_valid(npc.target_mega_node):
		npc.target_mega_node._on_body_exited(npc)
	npc.worker_state = "returning_to_workshop"
	if is_instance_valid(npc.hired_by_building):
		var target_pos = npc.hired_by_building.get_interaction_position()
		npc._generate_path(target_pos)
		
		for emp in npc.hired_by_building.hired_employees:
			if emp.get("npc_ref") == npc:
				emp["active_gathering_node_path"] = ""
				emp["active_recipe_path"] = ""
				emp["shift_status"] = "idle"
				emp["is_paused"] = true
				break
				
	var hud = npc.get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = npc.get_tree().get_first_node_in_group("game_hud")
	if hud and hud.has_method("_spawn_floating_text"):
		hud._spawn_floating_text("%s: On Strike! (%s)" % [npc.npc_name, reason], npc.global_position)

func _exit_tree() -> void:
	if is_instance_valid(npc) and is_instance_valid(npc.hired_by_building):
		var eq = npc.get_node_or_null("EquipmentComponent")
		if eq:
			var current_tool = eq.get_equipped_item("tool")
			if current_tool != null:
				var target_storage = npc.hired_by_building.get("building_storage")
				if not target_storage:
					target_storage = npc.hired_by_building.get("inventory")
				if target_storage:
					target_storage.add_item(current_tool, 1)
				eq.unequip_item("tool")
	if is_instance_valid(npc):
		var lm = npc.get_node_or_null("/root/LogisticsManager")
		if lm:
			lm.erase_buffer(npc)
