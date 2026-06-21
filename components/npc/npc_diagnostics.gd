class_name NPCDiagnostics
extends Object

static func log_employee(npc: CharacterBody2D, delta: float, debug_timer: float) -> float:
	var next_timer = debug_timer - delta
	if next_timer <= 0.0:
		next_timer = 5.0
		if not is_instance_valid(npc):
			return next_timer
			
		var emp_data = null
		if is_instance_valid(npc.hired_by_building):
			for emp in npc.hired_by_building.hired_employees:
				if emp.get("npc_ref") == npc:
					emp_data = emp
					break
					
		var building_name = npc.hired_by_building.name if is_instance_valid(npc.hired_by_building) else "None"
		var target_pos = Vector2.ZERO
		var target_dist = -1.0
		var nav_finished = false
		var path_pending = false
		var target_pos_str = "None"
		
		if npc.nav_motor and npc.nav_motor.nav_agent:
			target_pos = npc.nav_motor.nav_agent.target_position
			target_pos_str = str(target_pos)
			target_dist = npc.global_position.distance_to(target_pos)
			nav_finished = npc.nav_motor.nav_agent.is_navigation_finished()
			path_pending = npc.nav_motor.path_pending if "path_pending" in npc.nav_motor else false
			
		var eq = npc.get_node_or_null("EquipmentComponent")
		var equipped_tool = "None"
		if eq:
			var current_tool = eq.get_equipped_item("tool")
			if current_tool:
				equipped_tool = current_tool.id
				
		var is_paused = emp_data.get("is_paused", false) if emp_data else false
		var active_recipe = emp_data.get("active_recipe_path", "") if emp_data else ""
		var active_node = emp_data.get("active_gathering_node_path", "") if emp_data else ""
		
		var doorstep_pos = npc.hired_by_building.get_interaction_position() if is_instance_valid(npc.hired_by_building) else Vector2.ZERO
		var doorstep_dist = npc.global_position.distance_to(doorstep_pos) if is_instance_valid(npc.hired_by_building) else -1.0
		
		print("[Employee Diagnostics] Name: %s | State: %s | Pos: %s | Hired By: %s | Doorstep: %s (Dist: %.1f) | Nav Target: %s (Dist: %.1f, Finished: %s, Pending: %s) | Paused: %s | Recipe: %s | Node: %s | Tool: %s | Velocity: %s | Shift Active: %s" % [
			npc.npc_name,
			npc.worker_state,
			str(npc.global_position),
			building_name,
			str(doorstep_pos),
			doorstep_dist,
			target_pos_str,
			target_dist,
			str(nav_finished),
			str(path_pending),
			str(is_paused),
			active_recipe,
			active_node,
			equipped_tool,
			str(npc.velocity),
			str(npc.is_shift_active())
		])
	return next_timer
