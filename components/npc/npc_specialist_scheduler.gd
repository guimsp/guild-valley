extends Node

var npc: CharacterBody2D = null

func process_relation_target_behavior(delta: float) -> void:
	if not npc:
		return
		
	if npc.roams_interior_only:
		process_interior_roam(delta)
		return
		
	if npc.wait_timer > 0.0:
		npc.wait_timer -= delta
		npc.velocity = Vector2.ZERO
		npc.navigation.update_movement_animation(Vector2.ZERO)
		if npc.wait_timer <= 0.0:
			npc.navigation.choose_new_wander_target()
		return
		
	var nav_finished = true
	if npc.nav_motor and npc.nav_motor.nav_agent:
		nav_finished = npc.nav_motor.nav_agent.is_navigation_finished()
		
	if nav_finished:
		npc.wait_timer = randf_range(5.0, 10.0)

func process_static_scan(delta: float) -> void:
	if not npc:
		return
		
	npc.velocity = Vector2.ZERO
	npc.navigation.update_movement_animation(Vector2.ZERO)
		
	npc.scan_timer -= delta
	if npc.scan_timer <= 0.0:
		npc.scan_timer = randf_range(4.0, 8.0)
		var player = npc.get_tree().get_first_node_in_group("Player")
		if player and npc.global_position.distance_to(player.global_position) <= 80.0:
			npc.spawn_debug_emote("Guarding...", Color.SKY_BLUE)
			var diff = player.global_position - npc.global_position
			npc.last_direction = npc.navigation.get_cardinal_direction(diff)
			npc.navigation.update_movement_animation(Vector2.ZERO)

func process_inspector_logic(delta: float) -> void:
	if not npc:
		return
		
	var target = npc.get_meta("target_building")
	if not is_instance_valid(target):
		npc.queue_free()
		return
		
	var target_pos = target.global_position
	if target.has_method("get_interaction_position"):
		target_pos = target.get_interaction_position()
		
	var dist = npc.global_position.distance_to(target_pos)
	if dist < 48.0:
		target.is_under_audit = true
		target.audit_timer = 12.0
		
		if target.has_method("reset_all_workers"):
			target.reset_all_workers()
			
		for stall in npc.get_tree().get_nodes_in_group("MarketStall"):
			if is_instance_valid(stall) and (stall == target or stall.get("parent_building") == target):
				stall.is_under_audit = true
				if stall.inventory:
					stall.inventory.clear_inventory()
					
		if "inventory" in target and target.inventory:
			target.inventory.clear_inventory()
			
		if GameState:
			GameState.spawn_ui_floating_text("Audit started: halts production & clears stall!")
		npc.spawn_debug_emote("⚖️ Audit", Color.RED)
		npc.queue_free()
		return
		
	if npc.nav_motor and npc.nav_motor.nav_agent:
		if npc.nav_motor.nav_agent.target_position != target_pos:
			npc.navigation.generate_path(target_pos)

func process_interior_roam(delta: float) -> void:
	if not npc:
		return
		
	if npc.wait_timer > 0.0:
		npc.wait_timer -= delta
		npc.velocity = Vector2.ZERO
		npc.navigation.update_movement_animation(Vector2.ZERO)
		if npc.wait_timer <= 0.0:
			var rx = randf_range(-120.0, 120.0)
			var ry = randf_range(-70.0, 70.0)
			var target_pos = npc.anchor_position + Vector2(rx, ry)
			npc.navigation.generate_path(target_pos)
		return
		
	var nav_finished = true
	if npc.nav_motor and npc.nav_motor.nav_agent:
		nav_finished = npc.nav_motor.nav_agent.is_navigation_finished()
		
	if nav_finished:
		npc.wait_timer = randf_range(3.0, 8.0)
