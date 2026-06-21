class_name NPCNavigationComponent
extends Node

var npc: CharacterBody2D = null

func _ready() -> void:
	npc = get_parent() as CharacterBody2D

func get_speed_multiplier() -> float:
	if not npc:
		return 1.0
		
	var eq_speed = 0.0
	if npc.has_node("EquipmentComponent"):
		eq_speed = npc.get_node("EquipmentComponent").get_total_speed_bonus()
	var base_mult = npc._road_speed_multiplier + eq_speed
	
	# Martial Carriage Ban penalty for carts/couriers
	var pm = get_node_or_null("/root/PoliticsManager")
	if pm and npc.active_commercial_route != null:
		var npc_prov = npc.province
		if npc_prov == "Unknown Province" or npc_prov == "":
			npc_prov = GameState.get_province_of_node(npc) if GameState else ""
		if pm.is_law_active("martial_carriage_ban", npc_prov):
			base_mult *= 0.60 # -40% speed
			
	# Logistics Overseer speed bonus (+5% speed)
	var gc = get_node_or_null("/root/GuildController")
	if gc and npc.active_commercial_route != null:
		var npc_prov = npc.province
		if npc_prov == "Unknown Province" or npc_prov == "":
			npc_prov = GameState.get_province_of_node(npc) if GameState else ""
		var holder = gc.call("get_office_holder", npc_prov, "Logistics Overseer")
		if holder != "":
			var npc_faction = ""
			if npc.hired_by_building != null and is_instance_valid(npc.hired_by_building):
				if npc.hired_by_building.ownership_type == "Player":
					npc_faction = "Player"
				elif npc.hired_by_building.ownership_type == "NPC" and npc.hired_by_building.owner_id == "Rival":
					npc_faction = "Rival"
			if npc_faction == holder:
				base_mult *= 1.05
				
	return base_mult

func set_speed_multiplier(val: float) -> void:
	if npc:
		npc._road_speed_multiplier = val

func generate_path(destination: Vector2) -> void:
	if npc:
		if "wait_timer" in npc:
			npc.wait_timer = 0.0
		if npc.nav_motor:
			npc.nav_motor.move_to_target(destination, true)

func teleport(target_pos: Vector2) -> void:
	if not npc:
		return
	if npc.nav_motor and npc.nav_motor.has_method("teleport_to"):
		npc.nav_motor.teleport_to(target_pos)
	else:
		npc.global_position = target_pos
		npc.velocity = Vector2.ZERO

func choose_new_wander_target() -> void:
	if not npc:
		return
		
	var roads = npc.get_tree().get_nodes_in_group("Roads")
	var plazas = npc.get_tree().get_nodes_in_group("Plazas")
	
	var nearby_walkables = []
	var home_pos = npc.get_home_position()
	for road in roads:
		if road.global_position.distance_to(home_pos) < 300.0:
			nearby_walkables.append(road)
	for plaza in plazas:
		if plaza.global_position.distance_to(home_pos) < 300.0:
			nearby_walkables.append(plaza)
			
	if nearby_walkables.is_empty():
		var angle = randf() * TAU
		var dist = randf() * 100.0
		var fallback_pos = home_pos + Vector2(cos(angle), sin(angle)) * dist
		generate_path(fallback_pos)
		return
		
	var selected = nearby_walkables.pick_random()
	var size = selected.size if "size" in selected else Vector2(64, 64)
	var half_size = size / 2.0
	var offset = Vector2(
		randf_range(-half_size.x + 8.0, half_size.x - 8.0),
		randf_range(-half_size.y + 8.0, half_size.y - 8.0)
	)
	var next_target = selected.global_position + offset
	generate_path(next_target)

func update_movement_animation(vel: Vector2) -> void:
	if not npc:
		return
	if vel.length() > 5.0:
		npc.last_direction = get_cardinal_direction(vel)
		if npc.animated_sprite:
			npc.animated_sprite.play("walk_" + npc.last_direction)
	else:
		if npc.animated_sprite:
			npc.animated_sprite.play("idle_" + npc.last_direction)

func get_cardinal_direction(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "east" if direction.x > 0 else "west"
	else:
		return "south" if direction.y > 0 else "north"
