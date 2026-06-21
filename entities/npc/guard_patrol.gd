extends NPCAIController

@export var is_roaming_guard: bool = false

func _ready() -> void:
	npc_type = NPCType.TYPE_STATIC
	super._ready()
	scan_timer = 2.0
	add_to_group("Guards")
	# Soft blue/silver modulate to distinguish guards
	if animated_sprite:
		animated_sprite.modulate = Color(0.5, 0.75, 1.0)

func _physics_process(delta: float) -> void:
	if is_talking:
		velocity = Vector2.ZERO
		if has_method("update_animation"):
			update_animation(Vector2.ZERO)
		_update_action_label()
		return

	# Scanning check
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = 2.0
		_perform_guard_scan()

	# Roaming / Stationary movement
	if is_roaming_guard:
		if wait_timer > 0.0:
			wait_timer -= delta
			velocity = Vector2.ZERO
			if animated_sprite:
				animated_sprite.play("idle_" + last_direction)
			if wait_timer <= 0.0:
				# Wander around spawn position
				var angle = randf() * TAU
				var dist = randf_range(100.0, 350.0)
				var wander_pos = spawn_position + Vector2(cos(angle), sin(angle)) * dist
				_generate_path(wander_pos)
		else:
			if not nav_motor or nav_motor.nav_agent.is_navigation_finished():
				wait_timer = randf_range(4.0, 8.0)
	else:
		velocity = Vector2.ZERO
		if animated_sprite:
			animated_sprite.play("idle_" + last_direction)

	_update_action_label()

func _perform_guard_scan() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not is_instance_valid(player):
		return
		
	# Only scan if close enough (within 100 pixels) and player is outdoors
	if global_position.distance_to(player.global_position) > 100.0 or player.global_position.y > 9000.0:
		return
		
	var province = GameState.get_province_of_node(player)
	var pm = get_node_or_null("/root/PoliticsManager")
	if not pm:
		return
		
	# Garrison Allocation Bill affects scan detection probability
	var scan_chance = 0.50
	if pm.is_law_active("garrison_allocation_inc", province):
		scan_chance = 0.75
	elif pm.is_law_active("garrison_allocation_dec", province):
		scan_chance = 0.25
		
	if randf() > scan_chance:
		return # Noticed nothing
		
	# Check violations
	var violation_name = ""
	var violation_action = ""
	var contraband_id = ""
	
	# 1. Forestry Protection (illegal to harvest standard_timber)
	if pm.is_law_active("crown_forestry_protection", province):
		if player.get("is_harvesting") == true and player.has_meta("selected_gather_resource") and player.get_meta("selected_gather_resource") == "standard_timber":
			violation_name = "The Crown Forestry Protection Act"
			violation_action = "harvesting timber"
			contraband_id = "standard_timber"

	# 2. Noble Game Preservation (illegal to hunt venison)
	if violation_name == "" and pm.is_law_active("noble_game_preservation", province):
		if player.get("is_harvesting") == true and player.has_meta("selected_gather_resource") and player.get_meta("selected_gather_resource") == "venison":
			violation_name = "The Noble Game Preservation Edict"
			violation_action = "hunting wildlife"
			contraband_id = "venison"

	# 3. Metallurgical Monopoly (illegal to smelt outside cities)
	if violation_name == "" and pm.is_law_active("metallurgical_monopoly", province):
		if player.has_meta("crafting_building"):
			var bld = player.get_meta("crafting_building")
			if is_instance_valid(bld) and bld.is_in_group("Smelters"):
				var sett = GameState.get_nearest_settlement(bld)
				if sett and not sett.is_in_group("Cities"):
					violation_name = "The Metallurgical Monopoly Decree"
					violation_action = "smelting outside city walls"
					contraband_id = "iron_ore"

	# 4. Martial Carriage Ban (illegal to carry swords outdoors)
	if violation_name == "" and pm.is_law_active("martial_carriage_ban", province):
		if player.get("player_inventory") and player.player_inventory.has_item("iron_sword", 1):
			violation_name = "The Martial Carriage Ban"
			violation_action = "carrying military gear on roads"
			contraband_id = "iron_sword"

	if violation_name != "":
		_trigger_arrest_dialogue(player, violation_name, violation_action, contraband_id)

func _trigger_arrest_dialogue(player: CharacterBody2D, law_name: String, action: String, contraband: String) -> void:
	player.freeze()
	velocity = Vector2.ZERO
	if has_method("update_animation"):
		update_animation(Vector2.ZERO)
		
	# Face the player
	var diff = player.global_position - global_position
	if diff.length() > 5.0:
		last_direction = _get_cardinal_direction(diff)
		if has_method("update_animation"):
			update_animation(Vector2.ZERO)
			
	var msg = "Halt! You are violating %s by %s in this province! Pay a fine of 200 Gold or face immediate arrest and confiscation!" % [law_name, action]
	
	# Spawn dialogue bubble
	var bubble_scene = load("res://UI/npc_dialogue_bubble.tscn")
	var bubble = bubble_scene.instantiate()
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
	if hud:
		var parent_node = hud.get_node_or_null("Control")
		if parent_node:
			parent_node.add_child(bubble)
		else:
			hud.add_child(bubble)
			
		bubble.start_dialogue(self, npc_name, [msg], func():
			# This callback is called when bubble is closed manually. If closed, force unfreeze.
			if is_instance_valid(player):
				player.unfreeze()
		)
		
		# Show Yes/No options on the bubble
		bubble.show_choices(["Pay 200g Fine", "Face Arrest"], func(choice):
			if choice == 0:
				if GameState.gold >= 200:
					GameState.gold -= 200
					GameState.spawn_ui_floating_text("Paid Fine: -200 Gold!")
					# Stop player harvesting/smelting activity to prevent immediately re-triggering scan
					if player.get("is_harvesting") == true:
						player.set("is_harvesting", false)
						if player.has_meta("gather_time_left"):
							player.remove_meta("gather_time_left")
						var current_node = player.get("current_mega_node")
						if is_instance_valid(current_node):
							current_node._on_body_exited(player)
					# Clear dialogue
					bubble._on_close_pressed()
				else:
					GameState.spawn_ui_floating_text("Insufficient Gold! Arrested!")
					_arrest_player(player, contraband, bubble)
			else:
				_arrest_player(player, contraband, bubble)
		)

func _arrest_player(player: CharacterBody2D, contraband_id: String, bubble: Node) -> void:
	# Confiscate contraband
	if contraband_id != "" and player.get("player_inventory"):
		var amt = player.player_inventory.get_item_amount(contraband_id)
		if amt > 0:
			player.player_inventory.remove_item(contraband_id, amt)
			GameState.spawn_ui_floating_text("Confiscated %d %s!" % [amt, contraband_id.capitalize()])
			
	# Cancel current gathering
	if player.get("is_harvesting") == true:
		player.set("is_harvesting", false)
		if player.has_meta("gather_time_left"):
			player.remove_meta("gather_time_left")
		var current_node = player.get("current_mega_node")
		if is_instance_valid(current_node):
			current_node._on_body_exited(player)
			
	# Teleport to the province city center
	var province = GameState.get_province_of_node(player)
	var jail_pos = Vector2(1650, 480) # Valley City center
	if province == "Oakhaven Province":
		jail_pos = Vector2(5500, 480) # Oakhaven City center
		
	TransitionScreen.transition_teleport(jail_pos)
	
	# Close dialog
	bubble._on_close_pressed()
