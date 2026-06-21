extends Node

# Standalone child component for managing building workforce and candidate lists
var building: Node = null

var hired_employees: Array = []
var hireable_candidates: Array = []

signal employee_hired(employee_data: Dictionary)
signal employee_fired(employee_data: Dictionary)
signal candidates_replenished(candidates: Array)

func setup(p_building: Node) -> void:
	building = p_building
	if "hired_employees" in building:
		hired_employees = building.hired_employees
	if "hireable_candidates" in building:
		hireable_candidates = building.hireable_candidates

func populate_candidates() -> void:
	if not building: return
	hireable_candidates.clear()
	var province_name = GameState.get_province_of_node(building)
	var local_unemployed = []
	for npc in get_tree().get_nodes_in_group("NPCs"):
		if is_instance_valid(npc) and not npc.get("is_hired") and npc.get("province") == province_name:
			if npc.get("is_quest_npc") or npc.get("roams_interior_only") or npc.get("quest_npc_id") != "":
				continue
			local_unemployed.append(npc)
	while local_unemployed.size() < 3:
		var new_npc = spawn_dynamic_npc_in_province(province_name)
		if is_instance_valid(new_npc): local_unemployed.append(new_npc)
	hireable_candidates = local_unemployed
	ensure_spouse_candidate()
	candidates_replenished.emit(hireable_candidates)

func ensure_spouse_candidate() -> void:
	if not building: return
	var spouse_id = ""
	var owner_id = building.get("owner_id")
	var ownership_type = building.get("ownership_type")
	if owner_id == "Player" or ownership_type == "Player":
		if GameState and GameState.is_married: spouse_id = GameState.spouse_npc_id
	elif owner_id == "Rival":
		for r in get_tree().get_nodes_in_group("Rivals"):
			if is_instance_valid(r) and r.get("spouse_npc_id"):
				spouse_id = r.spouse_npc_id
				break
	if spouse_id != "":
		var spouse_node = null
		for npc in get_tree().get_nodes_in_group("NPCs"):
			if is_instance_valid(npc) and npc.get("quest_npc_id") == spouse_id:
				spouse_node = npc
				break
		if spouse_node and not spouse_node.get("is_hired") and not hireable_candidates.has(spouse_node):
			hireable_candidates.append(spouse_node)

func spawn_dynamic_npc_in_province(prov_name: String) -> CharacterBody2D:
	var npc_scene = load("res://entities/npc/npc.tscn")
	if not npc_scene: return null
	var target = null
	for city in get_tree().get_nodes_in_group("Cities"):
		if (city.city_name + " Province") == prov_name:
			target = city
			break
	if not target:
		for town in get_tree().get_nodes_in_group("Towns"):
			if town.ownership_province == prov_name:
				target = town
				break
	var spawn_pos = target.global_position if target else (building.global_position if building else Vector2.ZERO)
	var npc = npc_scene.instantiate() as CharacterBody2D
	npc.global_position = spawn_pos + Vector2(randf_range(-100, 100), randf_range(-100, 100))
	building.get_parent().add_child(npc)
	npc.province = prov_name
	return npc

func get_employee_craft_time(emp: Dictionary, recipe: Resource) -> float:
	var level = 1
	var npc = emp.get("npc_ref")
	if is_instance_valid(npc):
		level = npc.skills_data[recipe.required_career].get("level", 1) if "skills_data" in npc and npc.skills_data.has(recipe.required_career) else npc.get(recipe.required_career + "_level", 1)
	else:
		level = emp.get("levels", {}).get(recipe.required_career, 1)
	var craft_time = recipe.get_base_craft_time()
	var prod = npc.get("productivity") if is_instance_valid(npc) else 1.0
	if prod > 0.0: craft_time /= prod
	if level >= 8 and recipe.output_item.get("is_luxury_product"): craft_time *= 0.85
	var b_prov = GameState.get_province_of_node(building) if building else ""
	var pm = get_node_or_null("/root/PoliticsManager")
	if pm and b_prov != "":
		var faction = "Player" if building.ownership_type == "Player" else "Rival"
		if pm.is_faction_delinquent(faction, b_prov): craft_time *= 1.25
		if pm.is_law_active("labor_welfare_mandate", b_prov): craft_time *= 1.176
	return craft_time

func tick_employees(delta: float) -> void:
	if not building: return
	var valid_candidates = []
	for cand in hireable_candidates:
		if is_instance_valid(cand) and not cand.get("is_hired"):
			valid_candidates.append(cand)
	hireable_candidates = valid_candidates
	
	if hireable_candidates.size() < 3:
		populate_candidates()
		
	for emp in hired_employees:
		_tick_single_employee(emp, delta)
		
	var is_rival_run = building.ownership_type == "NPC" or (building.ownership_type == "Rented" and building.get("owner_id") == "Rival")
	if is_rival_run:
		_auto_transfer_npc_finished_goods()

func _tick_single_employee(emp: Dictionary, delta: float) -> void:
	var emp_slots = emp.get("service_slots", [])
	var new_emp_slots = []
	for cooldown in emp_slots:
		var next_cd = cooldown - delta
		if next_cd > 0.0:
			new_emp_slots.append(next_cd)
	emp["service_slots"] = new_emp_slots
	
	var worker = emp.get("npc_ref")
	var shift_active = true
	if is_instance_valid(worker) and worker.has_method("is_shift_active"):
		shift_active = worker.is_shift_active()
		
	if shift_active:
		var recipe_path = emp.get("active_recipe_path", "")
		if recipe_path != "":
			_process_crafting_step(emp, recipe_path, delta)
			
		var node_path = str(emp.get("active_gathering_node_path", ""))
		if node_path != "":
			_process_gathering_step(emp, node_path, delta)

func _check_inputs(recipe: Resource, storage: Node) -> bool:
	if not recipe or not storage: return false
	for item in recipe.inputs:
		if storage.get_item_amount(item.id) < recipe.inputs[item]:
			return false
	return true

func _consume_inputs(recipe: Resource, storage: Node) -> void:
	for item in recipe.inputs:
		storage.remove_item(item.id, recipe.inputs[item])

func _send_worker_to_bench(worker: CharacterBody2D) -> void:
	if not is_instance_valid(worker): return
	worker.set("worker_state", "traveling_to_workbench")
	var target_pos = building.get_interaction_position()
	if worker.global_position.y >= 9000.0 and is_instance_valid(building.instanced_interior) and is_instance_valid(building.instanced_interior.get_node_or_null("CraftingBench")):
		target_pos = building.instanced_interior.get_node("CraftingBench").global_position
	worker.call("_generate_path", target_pos)

func _try_start_auto_gathering(emp: Dictionary, recipe: Resource, worker: CharacterBody2D, storage: Node, b_prov: String) -> bool:
	if not recipe or not (building.improvements.get("auto_gathering", 0) > 0 if "improvements" in building else false): return false
	for item in recipe.inputs:
		if storage.get_item_amount(item.id) < recipe.inputs[item] and item.is_raw_material:
			var pm = get_node_or_null("/root/PoliticsManager")
			if pm and b_prov != "" and (
				(pm.is_law_active("crown_forestry_protection", b_prov) and item.id == "standard_timber") or
				(pm.is_law_active("noble_game_preservation", b_prov) and item.id == "venison")
			):
				return false
			var nearest = building.call("get_nearest_mega_node_for_resource", item.id) if building.has_method("get_nearest_mega_node_for_resource") else null
			if nearest and is_instance_valid(worker):
				var tool_id = ""
				var res_id = nearest.get("resource_type_id")
				match res_id:
					"wheat": tool_id = "bronze_scythe"
					"cotton": tool_id = "bronze_sickle"
					"iron_ore": tool_id = "bronze_pickaxe"
					
				var has_tool = false
				if tool_id != "":
					var eq = worker.get_node_or_null("EquipmentComponent")
					if eq:
						var current_tool = eq.get_equipped_item("tool")
						if current_tool != null and current_tool.id == tool_id:
							has_tool = true
					if not has_tool:
						var b_storage = building.building_storage
						if b_storage and b_storage.get_item_amount(tool_id) > 0:
							has_tool = true
				else:
					has_tool = true
					
				if not has_tool:
					if not emp.get("tool_alert_sent", false):
						emp["tool_alert_sent"] = true
						var msg = "%s cannot auto-gather for %s at %s: Required tool '%s' is missing from building storage." % [emp.get("name", "Employee"), recipe.recipe_name, building.name.replace("Interior_", ""), tool_id.capitalize().replace("_", " ")]
						AlertManager.add_alert("Tool Missing", msg, "warning", building)
					return false
					
				# Tool is available or equipped. Clear alert flag so it can fire next time if lost.
				emp["tool_alert_sent"] = false
				
				emp["is_paused"] = true
				emp["craft_timer"] = 0.0
				emp["craft_total_time"] = 0.0
				worker.start_gathering_shift(nearest)
				emp["active_gathering_node_path"] = nearest.get_path()
				emp["shift_worker_ref"] = worker
				emp["shift_status"] = "traveling"
				return true
	return false

func _show_text(text: String) -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
	if hud and hud.has_method("_spawn_floating_text"):
		hud._spawn_floating_text(text, building.global_position)

func _process_crafting_step(emp: Dictionary, recipe_path: String, delta: float) -> void:
	var recipe = load(recipe_path)
	var worker = emp.get("npc_ref")
	var building_storage = building.building_storage
	var b_prov = GameState.get_province_of_node(building)
	
	if recipe and recipe.get("is_service") == true:
		if is_instance_valid(worker):
			var w_state = worker.get("worker_state")
			if w_state != "producing_goods" and w_state != "traveling_to_workbench":
				_send_worker_to_bench(worker)
		return
		
	if emp.get("is_paused", false):
		if str(emp.get("active_gathering_node_path", "")) == "":
			if _check_inputs(recipe, building_storage):
				_consume_inputs(recipe, building_storage)
				emp["is_paused"] = false
				var craft_time = get_employee_craft_time(emp, recipe)
				emp["craft_timer"] = craft_time
				emp["craft_total_time"] = craft_time
				_send_worker_to_bench(worker)
			else:
				if _try_start_auto_gathering(emp, recipe, worker, building_storage, b_prov): return
				emp["is_paused"] = true
				_send_worker_to_bench(worker)
				if not emp.get("shortage_alert_sent", false):
					emp["shortage_alert_sent"] = true
					var msg = "%s cannot produce %s at %s: Insufficient inputs." % [emp.get("name", "Employee"), recipe.recipe_name, building.name.replace("Interior_", "")]
					AlertManager.add_alert("Production Blocked", msg, "warning", building)
					
	var worker_at_bench = false
	if not emp.get("is_paused", false) and is_instance_valid(worker):
		var w_state = worker.get("worker_state")
		if w_state == "producing_goods":
			worker_at_bench = true
		elif w_state not in ["traveling_to_workbench", "traveling_to_node", "gathering_at_node", "returning_to_workshop"]:
			_send_worker_to_bench(worker)
				
	if worker_at_bench:
		var timer = emp.get("craft_timer", 0.0)
		if timer > 0.0:
			emp["craft_timer"] = max(0.0, timer - delta)
			
		if emp["craft_timer"] <= 0.0:
			recipe = load(recipe_path)
			if recipe and building_storage:
				var out_item = recipe.output_item
				var out_qty = recipe.output_amount
				var level = 1
				if is_instance_valid(worker):
					level = worker.skills_data[recipe.required_career].get("level", 1) if "skills_data" in worker and worker.skills_data.has(recipe.required_career) else worker.get(recipe.required_career + "_level", 1)
				else:
					level = emp.get("levels", {}).get(recipe.required_career, 1)
					
				var double_harvest_triggered = false
				if level >= 8 and randf() <= 0.35:
					out_qty *= 2
					double_harvest_triggered = true
				elif level >= 5 and randf() <= 0.20:
					out_qty *= 2
					double_harvest_triggered = true
						
				var artisan_efficiency_triggered = level >= 8 and out_item.get("is_luxury_product") == true
				
				if building_storage.get_free_space_for_item(out_item) >= out_qty:
					building_storage.add_item(out_item, out_qty)
					if double_harvest_triggered: _show_text("Double Harvest!")
					if artisan_efficiency_triggered: _show_text("Masterwork Efficiency!")
							
					building.lifetime_production[out_item.id] = building.lifetime_production.get(out_item.id, 0) + out_qty
					building.daily_production[out_item.id] = building.daily_production.get(out_item.id, 0) + out_qty
					
					var gc = get_node_or_null("/root/GuildController")
					if gc and b_prov != "":
						var holder = gc.call("get_office_holder", b_prov, "Materials Steward")
						var faction = "Player" if building.ownership_type == "Player" else ("Rival" if building.ownership_type == "NPC" and building.owner_id == "Rival" else "")
						if holder != "" and faction == holder and randf() < 0.10:
							for item in recipe.inputs:
								if item.get_item_category() in [0, 1]:
									building_storage.add_item(item, recipe.inputs[item])
							GameState.spawn_ui_floating_text("Materials Refunded! (Materials Steward)")
								
					if recipe.get("is_breakthrough_only") == true:
						var fee = recipe.get_meta("gold_fee")
						if fee == null: fee = 100
						GameState.gold = max(0, GameState.gold - fee)
						var is_p = recipe.get_meta("is_player")
						var char_n = recipe.get_meta("character_name")
						var car = recipe.get_meta("career")
						var locked_lvl = recipe.get_meta("level") or 3
						
						if is_p:
							GameState.career_levels[car] = locked_lvl + 1
							GameState._on_career_leveled_up(car, locked_lvl + 1)
						elif is_instance_valid(worker):
							worker.skills_data[car]["level"] = locked_lvl + 1
								
						GameState.active_trial_recipes.erase(recipe_path)
						var dir = DirAccess.open(recipe_path.get_base_dir())
						if dir:
							dir.remove(recipe_path.get_file())
						GameState.spawn_ui_floating_text("%s's Breakthrough Successful! Level up to %d!" % [char_n, locked_lvl + 1])
						emp["active_recipe_path"] = ""
						if is_instance_valid(worker): worker.set("worker_state", "idle_at_workshop")
						return
						
					if building.ownership_type == "Player" or (building.ownership_type == "Rented" and building.get("owner_id") == "Player"):
						GameState.add_xp(recipe.required_career, int(ceil(recipe.xp_reward * 0.35)))
					elif building.ownership_type == "NPC" or (building.ownership_type == "Rented" and building.get("owner_id") == "Rival"):
						var rivals = get_tree().get_nodes_in_group("Rivals")
						if rivals.size() > 0: rivals[0].add_xp(int(ceil(recipe.xp_reward * 0.35)))
							
					if is_instance_valid(worker) and worker.has_method("gain_profession_xp"):
						worker.gain_profession_xp(recipe.required_career, int(ceil(recipe.xp_reward * 0.35)))
						
					var should_repeat = emp.get("is_repeating", true)
					if not should_repeat:
						var limit = emp.get("production_amount_limit", 0)
						if limit > 1:
							emp["production_amount_limit"] = limit - 1
							should_repeat = true
						else:
							emp["production_amount_limit"] = 0
							
					if should_repeat:
						var next_has_space = building_storage.get_free_space_for_item(out_item) >= out_qty
						if _check_inputs(recipe, building_storage) and next_has_space:
							_consume_inputs(recipe, building_storage)
							var craft_time = get_employee_craft_time(emp, recipe)
							emp["craft_timer"] = craft_time
							emp["craft_total_time"] = craft_time
						else:
							if _check_inputs(recipe, building_storage) == false and _try_start_auto_gathering(emp, recipe, worker, building_storage, b_prov):
								return
							emp["active_recipe_path"] = recipe_path
							emp["is_paused"] = true
							if is_instance_valid(worker): worker.set("worker_state", "producing_goods")
							if not _check_inputs(recipe, building_storage):
								if not emp.get("shortage_alert_sent", false):
									emp["shortage_alert_sent"] = true
									var msg = "%s has stopped producing %s at %s: Insufficient inputs." % [emp.get("name", "Employee"), recipe.recipe_name, building.name.replace("Interior_", "")]
									AlertManager.add_alert("Production Stalled", msg, "warning", building)
							else:
								emp["active_recipe_path"] = ""
								var msg = "%s has stopped producing %s at %s: Storage full." % [emp.get("name", "Employee"), recipe.recipe_name, building.name.replace("Interior_", "")]
								AlertManager.add_alert("Storage Full", msg, "warning", building)
					else:
						emp["active_recipe_path"] = ""
						if is_instance_valid(worker): worker.set("worker_state", "producing_goods")
				else:
					emp["active_recipe_path"] = ""
					if is_instance_valid(worker): worker.set("worker_state", "producing_goods")
					var msg = "%s has stopped producing %s at %s: Storage full." % [emp.get("name", "Employee"), recipe.recipe_name, building.name.replace("Interior_", "")]
					AlertManager.add_alert("Storage Full", msg, "warning", building)

func _process_gathering_step(emp: Dictionary, node_path: String, delta: float) -> void:
	var worker = emp.get("shift_worker_ref")
	if not is_instance_valid(worker) and emp.get("is_paused", false):
		worker = emp.get("npc_ref")
	var node = get_node_or_null(node_path)
	var building_storage = building.building_storage
	var b_prov = GameState.get_province_of_node(building)
	
	if is_instance_valid(worker):
		var w_state = worker.get("worker_state")
		if w_state == "returning_to_workshop": emp["shift_status"] = "returning"
		elif w_state == "gathering_at_node": emp["shift_status"] = "gathering"
		elif w_state == "traveling_to_node": emp["shift_status"] = "traveling"
		elif w_state == "idle_at_workshop":
			emp["shift_status"] = "idle"
			if emp.get("is_paused", false):
				emp["active_gathering_node_path"] = ""
				emp["shift_worker_ref"] = null
				_send_worker_to_bench(worker)
			else:
				emp["shift_worker_ref"] = null
				
				if emp.get("is_repeating", true) and node:
					var res_id = node.resource_type_id
					var pm = get_node_or_null("/root/PoliticsManager")
					if pm and b_prov != "" and (
						(pm.is_law_active("crown_forestry_protection", b_prov) and res_id == "standard_timber") or
						(pm.is_law_active("noble_game_preservation", b_prov) and res_id == "venison")
					):
						emp["active_gathering_node_path"] = ""
						emp["shift_status"] = "idle"
						emp["shift_worker_ref"] = null
						return
						
					var econ_mgr = get_node_or_null("/root/EconomyManager")
					var item_res = econ_mgr.item_database.get(res_id) if econ_mgr else null
					if item_res and building_storage:
						var fee = node.get_entry_fee()
						var player_has_gold = GameState.gold >= fee if building.ownership_type == "Player" else (get_tree().get_nodes_in_group("Rivals")[0].gold >= fee if get_tree().get_nodes_in_group("Rivals").size() > 0 else true)
						if building_storage.get_free_space_for_item(item_res) >= 20 and player_has_gold:
							if building.ownership_type == "Player":
								GameState.gold -= fee
								GameState.spawn_ui_floating_text("Paid Permit: -%d Gold!" % fee)
							elif get_tree().get_nodes_in_group("Rivals").size() > 0:
								get_tree().get_nodes_in_group("Rivals")[0].gold -= fee
							worker.start_gathering_shift(node)
							emp["shift_worker_ref"] = worker
							emp["shift_status"] = "traveling"
						else:
							emp["active_gathering_node_path"] = ""
							emp["shift_status"] = "idle"
							emp["shift_worker_ref"] = null
				else:
					emp["active_gathering_node_path"] = ""
					emp["shift_status"] = "idle"
					emp["shift_worker_ref"] = null
		elif emp.get("shift_status") in ["traveling", "gathering"]:
			emp["shift_status"] = "idle"
			emp["shift_worker_ref"] = null

func spawn_shift_worker(emp: Dictionary, node: Area2D) -> void:
	var worker = emp.get("npc_ref")
	if is_instance_valid(worker):
		worker.start_gathering_shift(node)
		emp["shift_worker_ref"] = worker
		emp["shift_status"] = "traveling"

func cancel_employee_gathering(emp: Dictionary, law_reason: String) -> void:
	emp["active_gathering_node_path"] = ""
	emp["shift_status"] = "idle"
	emp["is_paused"] = true
	var worker = emp.get("shift_worker_ref")
	if is_instance_valid(worker):
		if worker.get("is_gathering"):
			worker.set("is_gathering", false)
			if is_instance_valid(worker.get("target_mega_node")):
				worker.target_mega_node._on_body_exited(worker)
		worker.set("worker_state", "idle_at_workshop")
		if worker.has_method("_generate_path"):
			worker.call("_generate_path", building.get_interaction_position())
		emp["shift_worker_ref"] = null
		
	var npc = emp.get("npc_ref")
	if is_instance_valid(npc):
		npc.set("worker_state", "idle_at_workshop")
		if npc.has_method("_generate_path"):
			npc.call("_generate_path", building.get_interaction_position())
	_show_text("%s: On Strike! (%s)" % [emp.get("name", "Worker"), law_reason])

func cancel_all_smelting_recipes(law_reason: String) -> void:
	for emp in hired_employees:
		if emp.get("active_recipe_path", "") != "":
			emp["active_recipe_path"] = ""
			emp["craft_timer"] = 0.0
			emp["craft_total_time"] = 0.0
			emp["is_paused"] = true
			var worker = emp.get("npc_ref")
			if is_instance_valid(worker):
				worker.set("worker_state", "idle_at_workshop")
				if worker.has_method("_generate_path"):
					worker.call("_generate_path", building.get_interaction_position())
			_show_text("%s: Smelting Banned! (%s)" % [emp.get("name", "Worker"), law_reason])

func _auto_transfer_npc_finished_goods() -> void:
	if not building or not building.get("building_storage") or not building.get("inventory"):
		return
		
	var storage = building.building_storage
	var storefront = building.inventory
	
	var produced_item_ids = {}
	var needed_inputs = {}
	var bench = building.get_node_or_null("CraftingBench")
	if not bench and is_instance_valid(building.get("instanced_interior")):
		bench = building.instanced_interior.get_node_or_null("CraftingBench")
	if bench and "recipes" in bench:
		for recipe in bench.recipes:
			if recipe and recipe.output_item:
				produced_item_ids[recipe.output_item.id] = recipe.output_item
			if recipe and recipe.inputs:
				for input_item in recipe.inputs:
					needed_inputs[input_item.id] = input_item
					
	if produced_item_ids.is_empty():
		return
		
	var is_rival = (building.get("owner_id") == "Rival")
	if is_rival:
		var rivals = get_tree().get_nodes_in_group("Rivals")
		if not rivals.is_empty():
			var rival = rivals[0]
			if "inventory" in rival and rival.inventory:
				# 1. Pull raw materials / intermediate inputs from rival.inventory to building_storage
				for item_id in needed_inputs:
					var item = needed_inputs[item_id]
					var current_stored = storage.get_item_amount(item_id)
					var needed = 20 - current_stored
					if needed > 0:
						var available = rival.inventory.get_item_amount(item_id)
						var to_pull = min(needed, available)
						if to_pull > 0:
							var free_space = storage.get_free_space_for_item(item)
							var fit = min(to_pull, free_space)
							if fit > 0:
								rival.inventory.remove_item(item_id, fit)
								storage.add_item(item, fit)
								
				# 2. Transfer produced items from building_storage to rival.inventory
				for slot in storage.slots:
					var item = slot.get("item")
					var qty = slot.get("amount", 0)
					if item and qty > 0 and produced_item_ids.has(item.id):
						var free_space = rival.inventory.get_free_space_for_item(item)
						var to_move = min(qty, free_space)
						if to_move > 0:
							var remainder = rival.inventory.add_item(item, to_move)
							var moved = to_move - remainder
							if moved > 0:
								storage.remove_item(item.id, moved)
								
				# 3. Distribute final items from rival.inventory to the storefront inventory
				var final_sell_id = ""
				if "career_behavior" in rival and rival.career_behavior:
					final_sell_id = rival.career_behavior.final_sell_item_id
					
				for item_id in produced_item_ids:
					var item = produced_item_ids[item_id]
					var total_in_rival = rival.inventory.get_item_amount(item_id)
					var reserve = 10 if item_id != final_sell_id else 0
					var distributable = total_in_rival - reserve
					if distributable > 0:
						var free_space = storefront.get_free_space_for_item(item)
						var to_distribute = min(distributable, free_space)
						if to_distribute > 0:
							var remainder = storefront.add_item(item, to_distribute)
							var actual_moved = to_distribute - remainder
							if actual_moved > 0:
								rival.inventory.remove_item(item_id, actual_moved)
	else:
		# Original logic for non-rival NPC buildings
		for slot in storage.slots:
			var item = slot.get("item")
			var qty = slot.get("amount", 0)
			if item and qty > 0 and produced_item_ids.has(item.id):
				var free_space = storefront.get_free_space_for_item(item)
				var to_move = min(qty, free_space)
				if to_move > 0:
					var remainder = storefront.add_item(item, to_move)
					var moved = to_move - remainder
					if moved > 0:
						storage.remove_item(item.id, moved)
