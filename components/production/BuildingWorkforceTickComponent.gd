extends Node

var building: Node = null
var staff_component: Node = null

func setup(p_building: Node, p_staff: Node) -> void:
	building = p_building
	staff_component = p_staff

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
	if level >= 8 and recipe.output_item and recipe.output_item.get("is_luxury_product"):
		craft_time *= GameState.balance_config.get("artisan_luxury_craft_time_multiplier", 0.85)
	
	var trait_speed_mult = 1.0
	if is_instance_valid(npc) and npc.get("character_resource"):
		for trait_id in npc.character_resource.active_mods:
			var trait_data = WindowManager.get_trait_data(trait_id)
			if not trait_data.is_empty() and trait_data.has("speed_multiplier"):
				trait_speed_mult *= trait_data["speed_multiplier"]
	if trait_speed_mult > 0.0:
		craft_time /= trait_speed_mult
	var b_prov = GameState.get_province_of_node(building) if building else ""
	var pm = get_node_or_null("/root/PoliticsManager")
	if pm and b_prov != "":
		var faction = "Player" if building.ownership_type == "Player" else "Rival"
		if pm.is_faction_delinquent(faction, b_prov):
			craft_time *= GameState.balance_config.get("delinquent_faction_craft_time_multiplier", 1.25)
		if pm.is_law_active("labor_welfare_mandate", b_prov):
			var penalty = GameState.balance_config.get("labor_welfare_mandate_productivity_penalty", 0.15)
			if penalty < 1.0:
				craft_time *= 1.0 / (1.0 - penalty)
	if GameState and building:
		craft_time = GameState.apply_macro_modifier(building, "crafting_time", craft_time)
	return craft_time

func tick_employees(delta: float) -> void:
	if not building or not staff_component: return
	
	for emp in staff_component.hired_employees:
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
	var w_state = worker.get("worker_state")
	
	var target_pos = building.get_interaction_position()
	if worker.global_position.y >= 9000.0 and is_instance_valid(building.instanced_interior) and is_instance_valid(building.instanced_interior.get_node_or_null("CraftingBench")):
		target_pos = building.instanced_interior.get_node("CraftingBench").global_position
		
	if w_state == "traveling_to_workbench":
		return
	if w_state == "producing_goods":
		var dist = worker.global_position.distance_to(target_pos)
		if dist <= 60.0:
			return
			
	worker.set("worker_state", "traveling_to_workbench")
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
				var required_type = GameState.get_required_tool_type_for_resource(item.id)
				var item_level = 1
				var econ = Engine.get_main_loop().root.get_node_or_null("EconomyManager")
				if econ and econ.item_database.has(item.id):
					item_level = econ.item_database[item.id].item_level
					
				var has_tool = false
				var tool_needed_name = required_type.capitalize()
				if item_level >= 4:
					tool_needed_name = "Iron/Steel " + required_type.capitalize()
				else:
					tool_needed_name = "Copper/Iron/Steel " + required_type.capitalize()
					
				if required_type != "":
					var eq = worker.get_node_or_null("EquipmentComponent")
					if eq:
						var current_tool = eq.get_equipped_item("tool")
						if current_tool != null and GameState.is_tool_sufficient(current_tool.id, required_type, item_level):
							has_tool = true
					
					if not has_tool:
						var b_storage = building.building_storage
						if b_storage:
							var found_tool = GameState.find_sufficient_tool(b_storage, required_type, item_level)
							if found_tool != "":
								has_tool = true
				else:
					has_tool = true
					
				if not has_tool:
					if not emp.get("tool_alert_sent", false):
						emp["tool_alert_sent"] = true
						var msg = "%s cannot auto-gather for %s at %s: Required tool type '%s' is missing from building storage." % [emp.get("name", "Employee"), recipe.recipe_name, building.name.replace("Interior_", "")]
						AlertManager.add_alert("Tool Missing", msg, "warning", building)
					return false
					
				emp["tool_alert_sent"] = false
				emp["is_paused"] = true
				emp["craft_timer"] = 0.0
				emp["craft_total_time"] = 0.0
				worker.set_meta("selected_gather_resource", item.id)
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
				if recipe.is_event:
					building._resolve_completed_event(recipe)
					if building.ownership_type == "Player" or (building.ownership_type == "Rented" and building.get("owner_id") == "Player"):
						GameState.add_xp(recipe.required_career, int(ceil(recipe.xp_reward * 0.35)))
					elif building.ownership_type == "NPC" or (building.ownership_type == "Rented" and building.get("owner_id") == "Rival"):
						var rivals = get_tree().get_nodes_in_group("Rivals")
						if rivals.size() > 0: rivals[0].add_xp(int(ceil(recipe.xp_reward * 0.35)))
					if is_instance_valid(worker) and worker.has_method("gain_profession_xp"):
						worker.gain_profession_xp(recipe.required_career, int(ceil(recipe.xp_reward * 0.35)))
					emp["active_recipe_path"] = ""
					if is_instance_valid(worker): worker.set("worker_state", "idle_at_workshop")
					return
				var out_item = recipe.output_item
				var out_qty = recipe.output_amount
				var level = 1
				if is_instance_valid(worker):
					level = worker.skills_data[recipe.required_career].get("level", 1) if "skills_data" in worker and worker.skills_data.has(recipe.required_career) else worker.get(recipe.required_career + "_level", 1)
				else:
					level = emp.get("levels", {}).get(recipe.required_career, 1)
					
				var double_harvest_triggered = false
				if level >= 8 and randf() <= GameState.balance_config.get("double_harvest_chance_lvl8", 0.35):
					out_qty *= 2
					double_harvest_triggered = true
				elif level >= 5 and randf() <= GameState.balance_config.get("double_harvest_chance_lvl5", 0.20):
					out_qty *= 2
					double_harvest_triggered = true
						
				var miracle_artisan_triggered = false
				if is_instance_valid(worker) and "character_resource" in worker and worker.character_resource != null:
					var ma_lvl = 0
					for trait_id in worker.character_resource.active_mods:
						if trait_id.begins_with("Miracle Artisan_Lvl"):
							ma_lvl = int(trait_id.replace("Miracle Artisan_Lvl", ""))
							break
					if ma_lvl > 0:
						var ma_chance = 0.0
						if ma_lvl == 1: ma_chance = 0.03
						elif ma_lvl == 2: ma_chance = 0.07
						elif ma_lvl == 3: ma_chance = 0.15
						
						if randf() <= ma_chance:
							out_qty *= 2
							miracle_artisan_triggered = true

				var artisan_efficiency_triggered = level >= 8 and out_item.get("is_luxury_product") == true
				
				if building_storage.get_free_space_for_item(out_item) >= out_qty:
					building_storage.add_item(out_item, out_qty)
					if double_harvest_triggered: _show_text("Double Harvest!")
					if miracle_artisan_triggered: _show_text("Miracle Artisan!")
					if artisan_efficiency_triggered: _show_text("Masterwork Efficiency!")
							
					building.lifetime_production[out_item.id] = building.lifetime_production.get(out_item.id, 0) + out_qty
					building.daily_production[out_item.id] = building.daily_production.get(out_item.id, 0) + out_qty
					
					var gc = get_node_or_null("/root/GuildController")
					if gc and b_prov != "":
						var holder = gc.call("get_office_holder", b_prov, "Materials Steward")
						var faction = "Player" if building.ownership_type == "Player" else ("Rival" if building.ownership_type == "NPC" and building.owner_id == "Rival" else "")
						if holder != "" and faction == holder and randf() < GameState.balance_config.get("materials_steward_refund_chance", 0.10):
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
						
					var gather_res_id = res_id
					if is_instance_valid(worker) and worker.has_meta("selected_gather_resource"):
						gather_res_id = worker.get_meta("selected_gather_resource")
					var econ_mgr = get_node_or_null("/root/EconomyManager")
					var item_res = econ_mgr.item_database.get(gather_res_id) if econ_mgr else null
					if item_res and building_storage:
						var fee = node.get_entry_fee()
						if item_res.item_level >= 4:
							fee *= 3
						var player_has_gold = GameState.gold >= fee if building.ownership_type == "Player" else (get_tree().get_nodes_in_group("Rivals")[0].gold >= fee if get_tree().get_nodes_in_group("Rivals").size() > 0 else true)
						if building_storage.get_free_space_for_item(item_res) >= 20 and player_has_gold:
							if building.ownership_type == "Player":
								GameState.gold -= fee
								GameState.spawn_ui_floating_text("Paid Permit: -%d Gold!" % fee)
							elif get_tree().get_nodes_in_group("Rivals").size() > 0:
								get_tree().get_nodes_in_group("Rivals")[0].gold -= fee
							worker.set_meta("selected_gather_resource", item_res.id)
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
		
	var remainder := 0
	var is_rival = (building.get("owner_id") == "Rival")
	if is_rival:
		var rivals = get_tree().get_nodes_in_group("Rivals")
		if not rivals.is_empty():
			var rival = rivals[0]
			if "inventory" in rival and rival.inventory:
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
								
				for slot in storage.slots:
					var item = slot.get("item")
					var qty = slot.get("amount", 0)
					if item and qty > 0 and produced_item_ids.has(item.id):
						var free_space = rival.inventory.get_free_space_for_item(item)
						var to_move = min(qty, free_space)
						if to_move > 0:
							remainder = rival.inventory.add_item(item, to_move)
							var moved = to_move - remainder
							if moved > 0:
								storage.remove_item(item.id, moved)
								
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
							remainder = storefront.add_item(item, to_distribute)
							var actual_moved = to_distribute - remainder
							if actual_moved > 0:
								rival.inventory.remove_item(item_id, actual_moved)
	else:
		for slot in storage.slots:
			var item = slot.get("item")
			var qty = slot.get("amount", 0)
			if item and qty > 0 and produced_item_ids.has(item.id):
				var free_space = storefront.get_free_space_for_item(item)
				var to_move = min(qty, free_space)
				if to_move > 0:
					remainder = storefront.add_item(item, to_move)
					var moved = to_move - remainder
					if moved > 0:
						storage.remove_item(item.id, moved)
