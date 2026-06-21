extends Node

const NPCDiagnostics = preload("res://components/npc/npc_diagnostics.gd")

var npc: CharacterBody2D = null
var debug_timer: float = 0.0

func process_hired_worker(delta: float) -> void:
	if not npc:
		return
	debug_timer = NPCDiagnostics.log_employee(npc, delta, debug_timer)
		
	if npc.active_commercial_route != null:
		if npc.active_commercial_route.get("route_stops") != null:
			npc.econ_brain.process_internal_trade_route(delta)
		else:
			npc.econ_brain.process_commercial_route(delta)
		return
		
	var active_recipe_path = ""
	var active_gathering_node_path = ""
	if is_instance_valid(npc.hired_by_building):
		for emp in npc.hired_by_building.hired_employees:
			if emp.get("npc_ref") == npc:
				active_recipe_path = emp.get("active_recipe_path", "")
				active_gathering_node_path = str(emp.get("active_gathering_node_path", ""))
				break
				
	if active_gathering_node_path != "":
		if not is_instance_valid(npc.target_mega_node):
			npc.target_mega_node = npc.get_node_or_null(active_gathering_node_path)
			
		var req_tool = npc.econ_brain.get_required_tool_id_for_node(active_gathering_node_path)
		var has_tool = false
		var eq = npc.get_node_or_null("EquipmentComponent")
		if req_tool != "":
			if eq:
				var current_tool = eq.get_equipped_item("tool")
				if current_tool != null and current_tool.id == req_tool:
					has_tool = true
			
			if not has_tool:
				var close_to_workshop = false
				if is_instance_valid(npc.hired_by_building):
					var doorstep = npc.hired_by_building.get_interaction_position()
					if npc.global_position.y >= 9000.0 or npc.global_position.distance_to(doorstep) <= 36.0:
						close_to_workshop = true
						
				if close_to_workshop:
					npc.econ_brain.try_equip_tool_from_building(active_gathering_node_path)
					if eq and not eq.get_equipped_item("tool"):
						npc._pause_employee_due_to_missing_tool()
						return
				else:
					if npc.worker_state != "traveling_to_workshop":
						npc.worker_state = "traveling_to_workshop"
					if is_instance_valid(npc.hired_by_building):
						var doorstep = npc.hired_by_building.get_interaction_position()
						if not npc.nav_motor or not npc.nav_motor.nav_agent or npc.nav_motor.nav_agent.target_position != doorstep:
							npc.navigation.generate_path(doorstep)
					return

		if req_tool == "" or has_tool:
			if npc.worker_state == "idle_at_workshop" or npc.worker_state == "traveling_to_workshop":
				npc.worker_state = "traveling_to_node"
				if is_instance_valid(npc.hired_by_building) and npc.global_position.y >= 9000.0:
					npc._teleport(npc.hired_by_building.get_interaction_position())
				if is_instance_valid(npc.target_mega_node):
					npc.navigation.generate_path(npc.target_mega_node.global_position)
			elif npc.worker_state == "traveling_to_node":
				if is_instance_valid(npc.hired_by_building) and npc.global_position.y >= 9000.0:
					npc._teleport(npc.hired_by_building.get_interaction_position())
					if is_instance_valid(npc.target_mega_node):
						npc.navigation.generate_path(npc.target_mega_node.global_position)
				
	if active_recipe_path != "" and active_gathering_node_path == "":
		if npc.worker_state not in ["traveling_to_workbench", "producing_goods"] or (npc.worker_state == "producing_goods" and npc.global_position.y < 9000.0):
			npc.worker_state = "traveling_to_workbench"
			
	if active_recipe_path == "" and active_gathering_node_path == "":
		if npc.global_position.y > 9000.0:
			if is_instance_valid(npc.hired_by_building):
				npc._teleport(npc.hired_by_building.get_interaction_position())
			npc.worker_state = "idle_at_workshop"
			
	match npc.worker_state:
		"traveling_to_workshop":
			if is_instance_valid(npc.hired_by_building):
				var target_pos = npc.hired_by_building.get_interaction_position()
				if npc.nav_motor and npc.nav_motor.nav_agent.target_position != target_pos:
					npc.navigation.generate_path(target_pos)
				var dist = npc.global_position.distance_to(target_pos)
				var nav_finished = false
				if npc.nav_motor and npc.nav_motor.nav_agent:
					nav_finished = npc.nav_motor.nav_agent.is_navigation_finished()
				if npc.global_position.y >= 9000.0 or dist <= 32.0 or (nav_finished and dist <= 48.0):
					npc.worker_state = "idle_at_workshop"
					npc.velocity = Vector2.ZERO
					npc.navigation.update_movement_animation(Vector2.ZERO)
		
		"idle_at_workshop":
			if npc.wait_timer > 0.0:
				npc.wait_timer -= delta
				npc.velocity = Vector2.ZERO
				npc.navigation.update_movement_animation(Vector2.ZERO)
				if npc.wait_timer <= 0.0:
					if is_instance_valid(npc.hired_by_building):
						var angle = randf() * TAU
						var dist = randf_range(30.0, 60.0)
						var wander_pos = npc.hired_by_building.get_interaction_position() + Vector2(cos(angle), sin(angle)) * dist
						npc.navigation.generate_path(wander_pos)
				return
				
			var nav_finished = true
			if npc.nav_motor and npc.nav_motor.nav_agent:
				nav_finished = npc.nav_motor.nav_agent.is_navigation_finished()
				
			if nav_finished:
				npc.wait_timer = randf_range(3.0, 7.0)
					
		"traveling_to_node":
			if is_instance_valid(npc.target_mega_node):
				var target_pos = npc.target_mega_node.global_position
				if npc.nav_motor and npc.nav_motor.nav_agent.target_position != target_pos:
					npc.navigation.generate_path(target_pos)
			var my_prov = npc.province
			if my_prov == "Unknown Province" or my_prov == "":
				my_prov = GameState.get_province_of_node(npc) if GameState else ""
			var pm = npc.get_node_or_null("/root/PoliticsManager")
			if pm and is_instance_valid(npc.target_mega_node) and my_prov != "":
				var res_id = npc.target_mega_node.resource_type_id
				var is_illegal = false
				if pm.is_law_active("crown_forestry_protection", my_prov) and res_id == "standard_timber":
					is_illegal = true
				elif pm.is_law_active("noble_game_preservation", my_prov) and res_id == "venison":
					is_illegal = true
					
				if is_illegal:
					npc._trigger_worker_strike("Illegal Action")
					return

			if npc.is_gathering:
				npc.worker_state = "gathering_at_node"
				npc.shift_timer = 120.0
				npc.velocity = Vector2.ZERO
				npc.navigation.update_movement_animation(Vector2.ZERO)
			else:
				if is_instance_valid(npc.target_mega_node):
					var dist = npc.global_position.distance_to(npc.target_mega_node.global_position)
					if dist <= 48.0:
						npc.target_mega_node._on_body_entered(npc)
		
		"gathering_at_node":
			npc.velocity = Vector2.ZERO
			npc.navigation.update_movement_animation(Vector2.ZERO)
				
			npc.shift_timer -= delta
			if npc.shift_timer <= 0.0:
				npc.is_gathering = false
				if is_instance_valid(npc.target_mega_node):
					npc.target_mega_node._on_body_exited(npc)
				npc.worker_state = "returning_to_workshop"
				if is_instance_valid(npc.hired_by_building):
					var target_pos = npc.hired_by_building.get_interaction_position()
					npc.navigation.generate_path(target_pos)
					
		"returning_to_workshop":
			if is_instance_valid(npc.hired_by_building):
				var target_pos = npc.hired_by_building.get_interaction_position()
				if npc.nav_motor and npc.nav_motor.nav_agent.target_position != target_pos:
					npc.navigation.generate_path(target_pos)
				var dist = npc.global_position.distance_to(target_pos)
				var nav_finished = false
				if npc.nav_motor and npc.nav_motor.nav_agent:
					nav_finished = npc.nav_motor.nav_agent.is_navigation_finished()
				if dist <= 32.0 or (nav_finished and dist <= 48.0):
					npc.econ_brain.deposit_cargo()
					npc.worker_state = "idle_at_workshop"
					npc.velocity = Vector2.ZERO
					npc.navigation.update_movement_animation(Vector2.ZERO)
						
		"traveling_to_workbench":
			var my_prov = npc.province
			if my_prov == "Unknown Province" or my_prov == "":
				my_prov = GameState.get_province_of_node(npc) if GameState else ""
			var pm = npc.get_node_or_null("/root/PoliticsManager")
			if pm and my_prov != "" and is_instance_valid(npc.hired_by_building) and npc.hired_by_building.is_in_group("Smelters"):
				if pm.is_law_active("metallurgical_monopoly", my_prov):
					var sett = GameState.get_nearest_settlement(npc.hired_by_building)
					if sett and not sett.is_in_group("Cities"):
						npc._trigger_worker_strike("Illegal Smelting")
						return

			if is_instance_valid(npc.hired_by_building):
				if npc.global_position.y < 9000.0:
					var doorstep = npc.hired_by_building.get_interaction_position()
					if npc.nav_motor and (npc.nav_motor.nav_agent.target_position.y >= 9000.0 or npc.nav_motor.nav_agent.target_position.distance_to(doorstep) > 4.0):
						npc.navigation.generate_path(doorstep)
						
					var dist = npc.global_position.distance_to(doorstep)
					var nav_finished = false
					if npc.nav_motor and npc.nav_motor.nav_agent:
						nav_finished = npc.nav_motor.nav_agent.is_navigation_finished()
					if dist <= 32.0 or (nav_finished and dist <= 48.0):
						if is_instance_valid(npc.hired_by_building.instanced_interior):
							npc._teleport(npc.hired_by_building.instanced_interior.global_position + Vector2(0, 60))
							if is_instance_valid(npc.hired_by_building.instanced_interior.crafting_bench):
								var bench_pos = npc.hired_by_building.instanced_interior.crafting_bench.global_position
								npc.navigation.generate_path(bench_pos)
				else:
					if is_instance_valid(npc.hired_by_building.instanced_interior) and is_instance_valid(npc.hired_by_building.instanced_interior.crafting_bench):
						var bench_pos = npc.hired_by_building.instanced_interior.crafting_bench.global_position
						if npc.nav_motor and npc.nav_motor.nav_agent.target_position != bench_pos:
							npc.navigation.generate_path(bench_pos)
							
						var dist = npc.global_position.distance_to(bench_pos)
						var nav_finished = false
						if npc.nav_motor and npc.nav_motor.nav_agent:
							nav_finished = npc.nav_motor.nav_agent.is_navigation_finished()
						
						if dist <= 55.0 or nav_finished:
							npc.worker_state = "producing_goods"
							npc.velocity = Vector2.ZERO
							npc.navigation.update_movement_animation(Vector2.ZERO)
								
		"producing_goods":
			var is_paused = false
			if is_instance_valid(npc.hired_by_building):
				for emp in npc.hired_by_building.hired_employees:
					if emp.get("npc_ref") == npc:
						is_paused = emp.get("is_paused", false)
						break
						
			if is_paused:
				if npc.wait_timer > 0.0:
					npc.wait_timer -= delta
					npc.velocity = Vector2.ZERO
					npc.navigation.update_movement_animation(Vector2.ZERO)
					if npc.wait_timer <= 0.0:
						if is_instance_valid(npc.hired_by_building):
							var center_pos = npc.hired_by_building.global_position
							if npc.global_position.y >= 9000.0:
								if is_instance_valid(npc.hired_by_building.instanced_interior):
									center_pos = npc.hired_by_building.instanced_interior.global_position
							else:
								center_pos = npc.hired_by_building.get_interaction_position()
								
							var angle = randf() * TAU
							var dist = randf_range(20.0, 50.0)
							var wander_pos = center_pos + Vector2(cos(angle), sin(angle)) * dist
							npc.navigation.generate_path(wander_pos)
					return
					
				var nav_finished = true
				if npc.nav_motor and npc.nav_motor.nav_agent:
					nav_finished = npc.nav_motor.nav_agent.is_navigation_finished()
					
				if nav_finished:
					npc.wait_timer = randf_range(3.0, 6.0)
			else:
				npc.velocity = Vector2.ZERO
				npc.navigation.update_movement_animation(Vector2.ZERO)

func process_employee_leisure(delta: float) -> void:
	if not npc:
		return
	debug_timer = NPCDiagnostics.log_employee(npc, delta, debug_timer)
		
	if npc.global_position.y >= 9000.0:
		if is_instance_valid(npc.hired_by_building):
			npc._teleport(npc.hired_by_building.get_interaction_position())
			
	if npc.limbo_timer > 0.0:
		npc.limbo_timer -= delta
		npc.velocity = Vector2.ZERO
		npc.navigation.update_movement_animation(Vector2.ZERO)
		return
		
	if npc.wait_timer > 0.0:
		npc.wait_timer -= delta
		npc.velocity = Vector2.ZERO
		npc.navigation.update_movement_animation(Vector2.ZERO)
		if npc.wait_timer <= 0.0:
			var targets = []
			for grp in ["Taverns", "Inns"]:
				targets.append_array(npc.get_tree().get_nodes_in_group(grp))
			if targets.is_empty():
				npc.navigation.choose_new_wander_target()
		return

	if npc.is_leisure_consuming:
		npc.is_leisure_consuming = false
		execute_leisure_transaction()
		npc.wait_timer = randf_range(8.0, 15.0)
		return

	if not is_instance_valid(npc.leisure_spot_building):
		var targets = []
		for grp in ["Taverns", "Inns"]:
			targets.append_array(npc.get_tree().get_nodes_in_group(grp))
			
		if targets.is_empty():
			var nav_finished = true
			if npc.nav_motor and npc.nav_motor.nav_agent:
				nav_finished = npc.nav_motor.nav_agent.is_navigation_finished()
			if nav_finished:
				npc.wait_timer = randf_range(4.0, 8.0)
			return
			
		npc.leisure_spot_building = targets.pick_random()
		var target_pos = npc.leisure_spot_building.get_interaction_position() if npc.leisure_spot_building.has_method("get_interaction_position") else npc.leisure_spot_building.global_position
		npc.navigation.generate_path(target_pos)
	else:
		var target_pos = npc.leisure_spot_building.get_interaction_position() if npc.leisure_spot_building.has_method("get_interaction_position") else npc.leisure_spot_building.global_position
		var dist = npc.global_position.distance_to(target_pos)
		
		var nav_finished = false
		if npc.nav_motor and npc.nav_motor.nav_agent:
			nav_finished = npc.nav_motor.nav_agent.is_navigation_finished()
			
		if dist <= 32.0 or nav_finished:
			npc.is_leisure_consuming = true
			npc.velocity = Vector2.ZERO
			npc.navigation.update_movement_animation(Vector2.ZERO)

func execute_leisure_transaction() -> void:
	if not npc or not is_instance_valid(npc.leisure_spot_building):
		return
		
	var is_player_owned = npc.leisure_spot_building.ownership_type == "Player" or (npc.leisure_spot_building.ownership_type == "Rented" and npc.leisure_spot_building.owner_id == "Player")
	var is_service_building = npc.leisure_spot_building.is_in_group("Taverns") or npc.leisure_spot_building.is_in_group("Inns")
	
	var cost = 12
	var item_name = "Tavern Service"
	if npc.leisure_spot_building.is_in_group("Inns"):
		item_name = "Room Rental"
		
	var active_service = null
	if is_player_owned and is_service_building:
		if npc.leisure_spot_building.has_method("get_any_active_service_provider"):
			active_service = npc.leisure_spot_building.call("get_any_active_service_provider")
			
		if not active_service or not active_service.get("offered", false):
			npc.spawn_debug_emote("No Service!", Color.RED)
			npc.leisure_spot_building = null
			return
			
		var is_player = active_service["is_player"]
		var provider_level = active_service["level"]
		var recipe = active_service["recipe"]
		
		var slots = npc.leisure_spot_building.player_service_slots if is_player else active_service["employee"].get("service_slots", [])
		if slots.size() >= 3:
			npc.spawn_debug_emote("Busy!", Color.ORANGE)
			npc.leisure_spot_building = null
			return
			
		cost = npc.leisure_spot_building.call("get_service_price", recipe)
		item_name = recipe.recipe_name
		
		var is_tipped = false
		if provider_level >= 3:
			var tip_chance = float(provider_level) * 0.05
			if randf() < tip_chance:
				is_tipped = true
				cost = int(float(cost) * 1.5)
				
		if is_tipped:
			item_name += " (Tipped)"
			
		var storage = npc.leisure_spot_building.get("building_storage")
		if not storage:
			storage = npc.leisure_spot_building.get("inventory")
		if storage and recipe.inputs.size() > 0:
			var inputs_ok = true
			for item in recipe.inputs:
				if storage.get_item_amount(item.id) < recipe.inputs[item]:
					inputs_ok = false
					break
			if inputs_ok:
				for item in recipe.inputs:
					storage.remove_item(item.id, recipe.inputs[item])
			else:
				npc.spawn_debug_emote("No Materials!", Color.RED)
				npc.leisure_spot_building = null
				return

		if npc.npc_gold < cost:
			npc.spawn_debug_emote("No Gold!", Color.RED)
			npc.leisure_spot_building = null
			return
			
		if is_player:
			npc.leisure_spot_building.player_service_slots.append(60.0)
		else:
			var emp = active_service["employee"]
			var emp_slots = emp.get("service_slots", [])
			emp_slots.append(60.0)
			emp["service_slots"] = emp_slots
			
		var xp = recipe.xp_reward
		if is_player:
			if GameState:
				GameState.add_xp(recipe.required_career, xp)
		else:
			var emp = active_service["employee"]
			var emp_worker = emp.get("npc_ref")
			if is_instance_valid(emp_worker) and emp_worker.has_method("gain_profession_xp"):
				emp_worker.gain_profession_xp(recipe.required_career, int(ceil(xp * 0.35)))
				
		npc.npc_gold -= cost
		npc.spawn_debug_emote("Served: %s (-%d G)" % [item_name, cost], Color.GREEN)
		
		var strongbox = npc.leisure_spot_building.get_node_or_null("StrongboxComponent")
		if strongbox:
			strongbox.strongbox_gold += cost
			strongbox.add_transaction(item_name, 1, cost, "Off-Duty", npc.npc_name)
		else:
			GameState.gold += cost
			
	else:
		if npc.npc_gold < cost:
			npc.spawn_debug_emote("No Gold!", Color.RED)
			npc.leisure_spot_building = null
			return
			
		npc.npc_gold -= cost
		npc.spawn_debug_emote("Consumed %s (-%d G)" % [item_name, cost], Color.GREEN)
		
		if is_player_owned:
			var strongbox = npc.leisure_spot_building.get_node_or_null("StrongboxComponent")
			if strongbox:
				strongbox.strongbox_gold += cost
				strongbox.add_transaction(item_name, 1, cost, "Off-Duty", npc.npc_name)
			else:
				GameState.gold += cost
		elif npc.leisure_spot_building.ownership_type == "NPC" and npc.leisure_spot_building.owner_id == "Rival":
			var rivals = npc.get_tree().get_nodes_in_group("Rivals")
			if rivals.size() > 0:
				rivals[0].gold += cost
				
	npc.leisure_spot_building = null
