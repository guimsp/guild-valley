extends Node2D

# Placement State Variables
var _placement_active: bool = false
var _placement_mode: String = "" # "place", "move", "demolish"
var _placement_scene_path: String = ""
var _placement_gold_cost: int = 0
var _placement_build_time: float = 3.0
var _placement_building_name: String = ""
var _placement_ghost: Node2D = null
var _placement_ghost_shape: Shape2D = null
var _placement_original_pos: Vector2 = Vector2.ZERO
var _placement_moving_node: Node2D = null
var _hovered_workstation: Node2D = null
var _placement_position: Vector2 = Vector2.ZERO
var _original_camera_zoom: Vector2 = Vector2.ONE
var _camera_reference: Camera2D = null
var _placement_using_keyboard: bool = false
var _placement_foundation_fill: ColorRect = null
var _placement_foundation_outline: ReferenceRect = null
var _placement_active_lot: Node2D = null
var _placement_original_lot: Node2D = null
var _available_lots: Array = []
var _active_lot_index: int = 0
var _placement_building_db_item: BuildingData = null

var _active_player: Player = null
var _hud: CanvasLayer = null

func _ready() -> void:
	add_to_group("PlacementManager")
	# Find HUD and connect signals
	call_deferred("_connect_hud_signals")

func _connect_hud_signals() -> void:
	_hud = get_tree().get_first_node_in_group("PlayerHUD")
	if _hud:
		if not _hud.build_requested.is_connected(start_build):
			_hud.build_requested.connect(start_build)
		if not _hud.move_requested.is_connected(start_move):
			_hud.move_requested.connect(start_move)
		if not _hud.demolish_requested.is_connected(start_demolish):
			_hud.demolish_requested.connect(start_demolish)

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		_active_player = players[0] as Player

func is_placement_active() -> bool:
	return _placement_active

func start_build(building_data: BuildingData) -> void:
	_find_player()
	if building_data.tier > GameState.title_level:
		var req_title = GameState.get_title_name(building_data.tier)
		_spawn_floating_text("Requires Title: %s" % req_title, _active_player.global_position if _active_player else Vector2.ZERO)
		return
	_start_placement("place", building_data.scene_path, building_data.cost, building_data.time, building_data.name, building_data)

func start_move() -> void:
	_find_player()
	_start_placement("move", "", 0, 3.0, "")

func start_demolish() -> void:
	_find_player()
	_start_placement("demolish", "", 0, 3.0, "")

func start_move_building(building: Node2D) -> void:
	_find_player()
	_start_placement("move", "", 0, 3.0, "")
	_select_building_to_move(building)

func start_demolish_building(building: Node2D) -> void:
	_find_player()
	if not is_instance_valid(building):
		return
	_hovered_workstation = building
	
	if _hovered_workstation.is_in_group("Houses") and not _hovered_workstation.is_rental and _hovered_workstation.ownership_type == "Player":
		var personal_homes = 0
		for h in get_tree().get_nodes_in_group("Houses"):
			if is_instance_valid(h) and h.ownership_type == "Player" and not h.is_rental:
				personal_homes += 1
		if personal_homes <= 1:
			_spawn_floating_text("Cannot demolish your last personal home!", _hovered_workstation.global_position)
			_hovered_workstation = null
			return
			
	var distance = _active_player.global_position.distance_to(_hovered_workstation.global_position) if _active_player else 0.0
	if distance > 160.0:
		_spawn_floating_text("Too far!", _hovered_workstation.global_position)
		_hovered_workstation = null
		return
		
	var db_item = _hovered_workstation.building_data
	var refund = int(db_item.cost * 0.8) if db_item else 0
	
	GameState.next_change_reason = "Demolish Property"
	GameState.next_change_detail = db_item.name if db_item else "Workstation"
	GameState.gold += refund
	_spawn_floating_text("Demolished! +%d Gold" % refund, _hovered_workstation.global_position)
	
	for lot in get_tree().get_nodes_in_group("BuildingLots"):
		if lot.is_in_group("BuildingLots") and lot.occupied_node == _hovered_workstation:
			lot.is_occupied = false
			lot.occupied_node = null
			break
	
	if _active_player:
		_active_player.unregister_interactable(_hovered_workstation)
		
	var groups = ["CraftingBenches", "MarketStall", "WheatFields", "CottonPlants", "OreMines", "Beds", "Banks", "Inns", "Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Houses", "nav_carve_obstacles"]
	for grp in groups:
		if _hovered_workstation.is_in_group(grp):
			_hovered_workstation.remove_from_group(grp)
	_hovered_workstation.queue_free()
	_hovered_workstation = null
	
	if GameState.has_method("rebake_all_navigation_regions"):
		NavigationManager.rebake_all_navigation_regions()
	
	if _hud and _hud.has_method("update_hud_values"):
		_hud.update_hud_values()

func _select_building_to_move(building: Node2D) -> void:
	if not is_instance_valid(building):
		return
	_placement_moving_node = building
	_placement_original_pos = building.global_position
	_placement_original_lot = null
	
	for lot in get_tree().get_nodes_in_group("BuildingLots"):
		if lot.is_in_group("BuildingLots") and lot.occupied_node == _placement_moving_node:
			_placement_original_lot = lot
			break
			
	_available_lots.clear()
	_active_lot_index = 0
	_placement_active_lot = null
	
	var player_settlement = _get_current_settlement(_active_player.global_position) if _active_player else null
	if player_settlement:
		var player_pos = _active_player.global_position
		var all_lots = get_tree().get_nodes_in_group("BuildingLots")
		for lot in all_lots:
			if lot.has_method("calculate_lot_cost") and not lot.nearest_settlement:
				lot.calculate_lot_cost()
				
		for lot in all_lots:
			var is_vacant = not lot.is_occupied or lot == _placement_original_lot
			if is_vacant and lot.nearest_settlement == player_settlement:
				_available_lots.append(lot)
				
		_available_lots.sort_custom(func(a, b):
			return player_pos.distance_to(a.global_position) < player_pos.distance_to(b.global_position)
		)
		
		if _available_lots.size() > 0:
			var orig_idx = _available_lots.find(_placement_original_lot)
			if orig_idx != -1:
				_active_lot_index = orig_idx
			_placement_active_lot = _available_lots[_active_lot_index]
			_placement_position = _placement_active_lot.global_position
		else:
			_spawn_floating_text("No vacant lots in this settlement!", _active_player.global_position)
			exit_placement_mode()
			return
	else:
		_spawn_floating_text("Cant build here", _active_player.global_position)
		exit_placement_mode()
		return
	
	_disable_all_collisions(_placement_moving_node)
	var col = _placement_moving_node.get_node_or_null("CollisionShape2D")
	_placement_ghost_shape = col.shape.duplicate() if col else null
	_placement_moving_node.modulate = Color(0.3, 0.9, 0.3, 0.6)
	
	var rect_size = Vector2(64, 64)
	if _placement_ghost_shape is RectangleShape2D:
		rect_size = _placement_ghost_shape.size
	_attach_foundation(_placement_moving_node, rect_size)
	_hovered_workstation = null
	_spawn_floating_text("Moving...", _placement_position)

func _start_placement(mode: String, scene_path: String, cost: int, build_time: float = 3.0, building_name: String = "", db_item: BuildingData = null) -> void:
	_placement_active = true
	_placement_mode = mode
	_placement_scene_path = scene_path
	_placement_gold_cost = cost
	_placement_build_time = build_time
	_placement_building_name = building_name
	_placement_using_keyboard = true
	_placement_building_db_item = db_item
	
	_available_lots.clear()
	_active_lot_index = 0
	_placement_active_lot = null
	
	if _active_player:
		_active_player.freeze()
		_placement_position = _active_player.global_position
		
		var player_settlement = _get_current_settlement(_active_player.global_position)
		if player_settlement:
			if db_item and mode == "place":
				var is_city = player_settlement.is_in_group("Cities")
				var is_town = player_settlement.is_in_group("Towns")
				var allowed = db_item.allowed_settlement
				if (allowed == "city" and not is_city) or (allowed == "town" and not is_town):
					_spawn_floating_text("Cant build here", _active_player.global_position)
					exit_placement_mode()
					return
			
			var player_pos = _active_player.global_position
			var all_lots = get_tree().get_nodes_in_group("BuildingLots")
			
			for lot in all_lots:
				if lot.has_method("calculate_lot_cost") and not lot.nearest_settlement:
					lot.calculate_lot_cost()
					
			for lot in all_lots:
				var is_vacant = not lot.is_occupied or (mode == "move" and lot == _placement_original_lot)
				if is_vacant and lot.nearest_settlement == player_settlement:
					_available_lots.append(lot)
					
			_available_lots.sort_custom(func(a, b):
				return player_pos.distance_to(a.global_position) < player_pos.distance_to(b.global_position)
			)
			
			if _available_lots.size() > 0:
				_placement_active_lot = _available_lots[0]
				_placement_position = _placement_active_lot.global_position
			else:
				_spawn_floating_text("No vacant lots in this settlement!", _active_player.global_position)
				exit_placement_mode()
				return
		else:
			_spawn_floating_text("Cant build here", _active_player.global_position)
			exit_placement_mode()
			return
				
		var camera = _active_player.get_node_or_null("Camera2D")
		if camera and camera is Camera2D:
			_camera_reference = camera
			_original_camera_zoom = camera.zoom
			camera.set_as_top_level(true)
			
			var tween = create_tween()
			tween.tween_property(camera, "zoom", Vector2(0.7, 0.7), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			
	if mode == "place":
		var scene = load(scene_path)
		_placement_ghost = scene.instantiate()
		_placement_ghost.set_script(null)
		
		_disable_all_collisions(_placement_ghost)
		var interact = _placement_ghost.get_node_or_null("InteractionArea")
		if interact:
			interact.queue_free()
			
		_placement_ghost.modulate = Color(0.3, 0.9, 0.3, 0.6)
		_placement_ghost.global_position = _placement_position
		
		var temp_inst = scene.instantiate()
		var temp_col = temp_inst.get_node_or_null("CollisionShape2D")
		if temp_col:
			_placement_ghost_shape = temp_col.shape.duplicate()
		temp_inst.queue_free()
		
		get_parent().add_child(_placement_ghost)
		
		var rect_size = Vector2(64, 64)
		if _placement_ghost_shape is RectangleShape2D:
			rect_size = _placement_ghost_shape.size
		_attach_foundation(_placement_ghost, rect_size)

func exit_placement_mode() -> void:
	_placement_active = false
	_placement_active_lot = null
	_placement_original_lot = null
	_available_lots.clear()
	_active_lot_index = 0
	
	for lot in get_tree().get_nodes_in_group("BuildingLots"):
		if lot.is_in_group("BuildingLots"):
			lot.is_highlighted = false
			lot.is_selected = false
			
	_cleanup_foundation()
	
	if _camera_reference and is_instance_valid(_camera_reference):
		_camera_reference.set_as_top_level(false)
		_camera_reference.position = Vector2.ZERO
		_camera_reference.zoom = _original_camera_zoom
	_camera_reference = null
	
	if _active_player:
		_active_player.unfreeze()
		
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
		
	if _placement_ghost and _placement_mode == "place":
		_placement_ghost.queue_free()
	_placement_ghost = null
	_placement_ghost_shape = null
	
	if _placement_moving_node and is_instance_valid(_placement_moving_node):
		_placement_moving_node.global_position = _placement_original_pos
		_placement_moving_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_placement_moving_node.show()
		_enable_all_collisions(_placement_moving_node)
			
	_placement_moving_node = null
	
	if _hovered_workstation and is_instance_valid(_hovered_workstation):
		_hovered_workstation.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_hovered_workstation = null
		
	_placement_mode = ""
	_placement_scene_path = ""
	_placement_gold_cost = 0
	_placement_build_time = 3.0
	_placement_building_name = ""
	_placement_building_db_item = null
	
	if _hud:
		_hud.hide_placement_instruction()
		_hud.update_interaction_prompt()

func _process(delta: float) -> void:
	if not _placement_active or get_tree().paused:
		return
		
	var active_lot = _placement_active_lot
	if active_lot:
		_placement_position = active_lot.global_position
		
	var player_settlement = null
	if _active_player:
		player_settlement = _get_current_settlement(_active_player.global_position)
		
	for lot in get_tree().get_nodes_in_group("BuildingLots"):
		if lot.is_in_group("BuildingLots"):
			var belongs_to_current_settlement = player_settlement and lot.nearest_settlement == player_settlement
			var is_available = lot in _available_lots
			if is_available or belongs_to_current_settlement:
				lot.is_highlighted = true
				lot.is_selected = (lot == active_lot)
			else:
				lot.is_highlighted = false
				lot.is_selected = false
				
	var camera_target = _placement_position
	if _camera_reference and is_instance_valid(_camera_reference):
		_camera_reference.global_position = _camera_reference.global_position.lerp(camera_target, delta * 8.0)
		
	if _placement_mode == "place":
		if _placement_ghost and is_instance_valid(_placement_ghost):
			if active_lot:
				_placement_ghost.global_position = active_lot.global_position
				_placement_ghost.show()
			else:
				_placement_ghost.hide()
			
		var is_range_valid = true
		var has_enough_gold = true
		if active_lot:
			var lot_price = active_lot.calculate_lot_cost()
			var total_cost = lot_price + _placement_gold_cost
			if GameState.gold < total_cost:
				has_enough_gold = false
				
		var is_env_valid = true
		if active_lot:
			var is_target_indoors = _is_indoors(active_lot.global_position)
			var db_item = _placement_building_db_item
			if db_item:
				if db_item.env == "inside" and not is_target_indoors:
					is_env_valid = false
				elif db_item.env == "outside" and is_target_indoors:
					is_env_valid = false
				if db_item.type == "home":
					var province = GameState.get_province_of_node(active_lot)
					if GameState.has_private_house_in_province("Player", province):
						is_env_valid = false
		else:
			is_env_valid = false
				
		var is_collision_valid = true
		if active_lot and _placement_ghost_shape:
			is_collision_valid = _is_position_clear(active_lot.global_position, _placement_ghost_shape)
		else:
			is_collision_valid = false
			
		if active_lot and is_range_valid and is_env_valid and is_collision_valid and has_enough_gold:
			_placement_ghost.modulate = Color(0.3, 0.9, 0.3, 0.6)
			if _placement_foundation_fill:
				_placement_foundation_fill.color = Color(0.2, 0.8, 0.4, 0.35)
			if _placement_foundation_outline:
				_placement_foundation_outline.border_color = Color(0.3, 0.9, 0.5, 0.95)
		else:
			if _placement_ghost and is_instance_valid(_placement_ghost):
				_placement_ghost.modulate = Color(0.9, 0.3, 0.3, 0.6)
			if _placement_foundation_fill:
				_placement_foundation_fill.color = Color(0.9, 0.3, 0.3, 0.35)
			if _placement_foundation_outline:
				_placement_foundation_outline.border_color = Color(0.9, 0.4, 0.4, 0.95)

			
	elif _placement_mode == "move":
		if _placement_moving_node and is_instance_valid(_placement_moving_node):
			if active_lot:
				_placement_moving_node.global_position = active_lot.global_position
				_placement_moving_node.show()
			else:
				_placement_moving_node.hide()
			
			var is_range_valid = true
			var has_enough_gold = true
			if active_lot:
				var db_item = _placement_moving_node.building_data
				var relocate_cost = int(db_item.cost * 0.75) if db_item else 0
				var lot_price = 0
				if active_lot != _placement_original_lot:
					lot_price = active_lot.calculate_lot_cost()
				var total_cost = relocate_cost + lot_price
				if GameState.gold < total_cost:
					has_enough_gold = false
					
			var is_env_valid = true
			if active_lot:
				var is_target_indoors = _is_indoors(active_lot.global_position)
				var db_item = _placement_moving_node.building_data
				if db_item:
					if db_item.env == "inside" and not is_target_indoors:
						is_env_valid = false
					elif db_item.env == "outside" and is_target_indoors:
						is_env_valid = false
			else:
				is_env_valid = false
					
			var is_collision_valid = true
			if active_lot and _placement_ghost_shape:
				is_collision_valid = _is_position_clear(active_lot.global_position, _placement_ghost_shape)
			else:
				is_collision_valid = false
				
			if active_lot and is_range_valid and is_env_valid and is_collision_valid and has_enough_gold:
				_placement_moving_node.modulate = Color(0.3, 0.9, 0.3, 0.6)
				if _placement_foundation_fill:
					_placement_foundation_fill.color = Color(0.2, 0.8, 0.4, 0.35)
				if _placement_foundation_outline:
					_placement_foundation_outline.border_color = Color(0.3, 0.9, 0.5, 0.95)
			else:
				if _placement_moving_node and is_instance_valid(_placement_moving_node):
					_placement_moving_node.modulate = Color(0.9, 0.3, 0.3, 0.6)
				if _placement_foundation_fill:
					_placement_foundation_fill.color = Color(0.9, 0.3, 0.3, 0.35)
				if _placement_foundation_outline:
					_placement_foundation_outline.border_color = Color(0.9, 0.4, 0.4, 0.95)

		else:
			_process_workstation_hover()
			
	elif _placement_mode == "demolish":
		_process_workstation_hover()

	# Update HUD instruction prompt
	if _hud:
		match _placement_mode:
			"place":
				var lot_cost = active_lot.calculate_lot_cost() if active_lot else 0
				var total_cost = lot_cost + _placement_gold_cost
				_hud.set_placement_instruction("Press [F] or Left Click to Build %s (Lot %d + Workstation %d = %d Gold) | [ESC] or Right Click to Cancel" % [_placement_building_name, lot_cost, _placement_gold_cost, total_cost])
			"move":
				if _placement_moving_node and is_instance_valid(_placement_moving_node):
					var db_item = _placement_moving_node.building_data
					var relocate_cost = int(db_item.cost * 0.75) if db_item else 0
					var lot_cost = 0
					if active_lot and active_lot != _placement_original_lot:
						lot_cost = active_lot.calculate_lot_cost()
					var total_cost = lot_cost + relocate_cost
					_hud.set_placement_instruction("Press [F] or Left Click to Place (Lot %d + Move %d = %d Gold) | [ESC] or Right Click to Cancel" % [lot_cost, relocate_cost, total_cost])
				else:
					_hud.set_placement_instruction("Click on a workstation to move it | [ESC] to Cancel")
			"demolish":
				_hud.set_placement_instruction("Click on a workstation to demolish it (80% refund) | [ESC] to Cancel")

func _unhandled_input(event: InputEvent) -> void:
	if not _placement_active:
		return
		
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		_spawn_floating_text("Cancel", _active_player.global_position if _active_player else Vector2.ZERO)
		exit_placement_mode()
		get_viewport().set_input_as_handled()
		return
		
	if _available_lots.size() > 0:
		var target_lot: Node2D = null
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode == KEY_1:
				target_lot = _find_extreme_lot(true)
			elif event.keycode == KEY_2:
				target_lot = _find_extreme_lot(false)
				
		if target_lot:
			_placement_active_lot = target_lot
			_active_lot_index = _available_lots.find(target_lot)
			_placement_position = _placement_active_lot.global_position
			_spawn_floating_text("Selected: " + ("Most Expensive" if event.keycode == KEY_1 else "Cheapest"), _placement_position)
			get_viewport().set_input_as_handled()
			return
			
		var dir_vector = Vector2.ZERO
		if event.is_action_pressed("move_left") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_A):
			dir_vector = Vector2.LEFT
		elif event.is_action_pressed("move_right") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_D):
			dir_vector = Vector2.RIGHT
		elif event.is_action_pressed("move_up") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_W):
			dir_vector = Vector2.UP
		elif event.is_action_pressed("move_down") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_S):
			dir_vector = Vector2.DOWN
			
		if dir_vector != Vector2.ZERO:
			var best_lot = _find_best_lot_in_direction(dir_vector)
			if best_lot:
				_placement_active_lot = best_lot
				_active_lot_index = _available_lots.find(best_lot)
				_placement_position = _placement_active_lot.global_position
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		if _placement_mode == "place":
			if not _placement_active_lot:
				_spawn_floating_text("No Lot Selected!", _placement_position)
				get_viewport().set_input_as_handled()
				return
				
			var target_pos = _placement_active_lot.global_position
			var is_range_valid = _placement_active_lot in _available_lots
			var is_env_valid = true
			var is_target_indoors = _is_indoors(target_pos)
			
			var db_item = _placement_building_db_item
			if db_item:
				if db_item.env == "inside" and not is_target_indoors:
					is_env_valid = false
				elif db_item.env == "outside" and is_target_indoors:
					is_env_valid = false
				if db_item.type == "home":
					var province = GameState.get_province_of_node(_placement_active_lot)
					if GameState.has_private_house_in_province("Player", province):
						_spawn_floating_text("Already have a home here!", target_pos)
						get_viewport().set_input_as_handled()
						return
					
			var is_collision_valid = true
			if _placement_ghost_shape:
				is_collision_valid = _is_position_clear(target_pos, _placement_ghost_shape)
				
			if is_range_valid and is_env_valid and is_collision_valid:
				# Construction check overrides
				if _placement_building_db_item and _placement_building_db_item.id == "craftsman_spire_l1":
					if GameState.career_levels.get("craftsman", 0) < 10:
						_spawn_floating_text("Requires Craftsman Lvl 10!", target_pos)
						get_viewport().set_input_as_handled()
						return
				elif _placement_building_db_item and _placement_building_db_item.id == "woodworker_spire_l1":
					if GameState.career_levels.get("woodworker", 0) < 10:
						_spawn_floating_text("Requires Woodworker Lvl 10!", target_pos)
						get_viewport().set_input_as_handled()
						return
				elif _placement_building_db_item and _placement_building_db_item.id == "herbalist_spire_l1":
					if GameState.career_levels.get("herbalist", 0) < 10:
						_spawn_floating_text("Requires Herbalist Lvl 10!", target_pos)
						get_viewport().set_input_as_handled()
						return
				elif _placement_building_db_item and _placement_building_db_item.id == "scholar_bank_l1":
					if not GameState.player_inventory or GameState.player_inventory.get_item_amount("advanced_structural_beam") < 2:
						_spawn_floating_text("Requires 2x Advanced Structural Beam!", target_pos)
						get_viewport().set_input_as_handled()
						return
				elif _placement_building_db_item and _placement_building_db_item.id == "scholar_mint_l1":
					if GameState.career_levels.get("scholar", 0) < 10:
						_spawn_floating_text("Requires Scholar Lvl 10!", target_pos)
						get_viewport().set_input_as_handled()
						return
				elif _placement_building_db_item and _placement_building_db_item.id == "rogue_palace_spire_l1":
					if GameState.career_levels.get("rogue", 0) < 10:
						_spawn_floating_text("Requires Rogue Lvl 10!", target_pos)
						get_viewport().set_input_as_handled()
						return
					if not GameState.is_married:
						_spawn_floating_text("Requires a Spouse with an active career!", target_pos)
						get_viewport().set_input_as_handled()
						return
					var spouse_valid = false
					var spouse_career = ""
					for npc in get_tree().get_nodes_in_group("NPCs"):
						if is_instance_valid(npc) and npc.get("quest_npc_id") == GameState.spouse_npc_id:
							spouse_valid = true
							spouse_career = npc.get("career")
							break
					if not spouse_valid or spouse_career == "patreon" or spouse_career == "":
						_spawn_floating_text("Spouse must hold active non-Patreon career!", target_pos)
						get_viewport().set_input_as_handled()
						return
				elif _placement_building_db_item and _placement_building_db_item.id == "showman_royal_opera_house_l1":
					if GameState.career_levels.get("showman", 0) < 10:
						_spawn_floating_text("Requires Showman Lvl 10!", target_pos)
						get_viewport().set_input_as_handled()
						return
					if not GameState.player_inventory or GameState.player_inventory.get_item_amount("monumental_truss") < 1:
						_spawn_floating_text("Requires 1x Monumental Truss!", target_pos)
						get_viewport().set_input_as_handled()
						return


				var lot_price = _placement_active_lot.calculate_lot_cost()
				var total_cost = lot_price + _placement_gold_cost
				if GameState.gold < total_cost:
					_spawn_floating_text("Need %d Gold!" % total_cost, target_pos)
					return
					
				GameState.next_change_reason = "Construct Building"
				GameState.next_change_detail = _placement_building_name
				GameState.gold -= total_cost

				if _placement_building_db_item and _placement_building_db_item.id == "scholar_bank_l1":
					if GameState.player_inventory:
						GameState.player_inventory.remove_item("advanced_structural_beam", 2)
				elif _placement_building_db_item and _placement_building_db_item.id == "showman_royal_opera_house_l1":
					if GameState.player_inventory:
						GameState.player_inventory.remove_item("monumental_truss", 1)
				
				var const_site_scene = load("res://components/placement/construction_site.tscn")
				var const_site = const_site_scene.instantiate()
				const_site.global_position = target_pos
				const_site.building_data = _placement_building_db_item
				const_site.target_scene_path = _placement_scene_path
				const_site.build_time = _placement_build_time
				const_site.building_name = _placement_building_name
				if "is_rental" in const_site:
					const_site.is_rental = _placement_building_db_item.type == "renting" if _placement_building_db_item else false
				
				_placement_active_lot.is_occupied = true
				_placement_active_lot.occupied_node = const_site
				
				get_parent().add_child(const_site)
				_spawn_floating_text("Building started! -%d Gold" % total_cost, target_pos)
				
				if _hud and _hud.has_method("update_hud_values"):
					_hud.update_hud_values()
				exit_placement_mode()
			else:
				_spawn_floating_text("Invalid Position!", target_pos)
			get_viewport().set_input_as_handled()
			
		elif _placement_mode == "move":
			if _placement_moving_node and is_instance_valid(_placement_moving_node):
				if not _placement_active_lot:
					_spawn_floating_text("No Lot Selected!", _placement_position)
					get_viewport().set_input_as_handled()
					return
					
				var target_pos = _placement_active_lot.global_position
				var is_range_valid = _placement_active_lot in _available_lots
				var is_env_valid = true
				var is_target_indoors = _is_indoors(target_pos)
				
				var db_item = _placement_moving_node.building_data
				if db_item:
					if db_item.env == "inside" and not is_target_indoors:
						is_env_valid = false
					elif db_item.env == "outside" and is_target_indoors:
						is_env_valid = false
						
				var is_collision_valid = true
				if _placement_ghost_shape:
					is_collision_valid = _is_position_clear(target_pos, _placement_ghost_shape)
					
				if is_range_valid and is_env_valid and is_collision_valid:
					var relocate_cost = int(db_item.cost * 0.75) if db_item else 0
					var lot_price = 0
					if _placement_active_lot != _placement_original_lot:
						lot_price = _placement_active_lot.calculate_lot_cost()
					var total_cost = relocate_cost + lot_price
					
					if GameState.gold < total_cost:
						_spawn_floating_text("Need %d Gold!" % total_cost, target_pos)
						return
						
					GameState.next_change_reason = "Relocate Building"
					GameState.next_change_detail = db_item.name if db_item else "Workstation"
					GameState.gold -= total_cost
					
					var const_site_scene = load("res://components/placement/construction_site.tscn")
					var const_site = const_site_scene.instantiate()
					const_site.global_position = target_pos
					const_site.building_data = db_item
					const_site.target_scene_path = db_item.scene_path
					const_site.build_time = db_item.time
					const_site.building_name = db_item.name
					
					if _placement_original_lot and _placement_original_lot != _placement_active_lot:
						_placement_original_lot.is_occupied = false
						_placement_original_lot.occupied_node = null
						
					_placement_active_lot.is_occupied = true
					_placement_active_lot.occupied_node = const_site
					
					get_parent().add_child(const_site)
					_spawn_floating_text("Relocating! -%d Gold" % total_cost, target_pos)
					
					if _active_player:
						_active_player.unregister_interactable(_placement_moving_node)
						
					var groups = ["CraftingBenches", "MarketStall", "WheatFields", "CottonPlants", "OreMines", "Beds", "Banks", "Inns", "Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Houses", "Warehouses", "nav_carve_obstacles"]
					for grp in groups:
						if _placement_moving_node.is_in_group(grp):
							_placement_moving_node.remove_from_group(grp)
					_placement_moving_node.queue_free()
					_placement_moving_node = null
					
					if GameState.has_method("rebake_all_navigation_regions"):
						NavigationManager.rebake_all_navigation_regions()
					
					if _hud and _hud.has_method("update_hud_values"):
						_hud.update_hud_values()
					exit_placement_mode()
				else:
					_spawn_floating_text("Invalid Position!", target_pos)
				get_viewport().set_input_as_handled()
			else:
				if _hovered_workstation and is_instance_valid(_hovered_workstation):
					var distance = _active_player.global_position.distance_to(_hovered_workstation.global_position) if _active_player else 0.0
					if distance > 160.0:
						_spawn_floating_text("Too far!", _hovered_workstation.global_position)
						return
						
					_placement_moving_node = _hovered_workstation
					_placement_original_pos = _hovered_workstation.global_position
					_placement_original_lot = null
					
					for lot in get_tree().get_nodes_in_group("BuildingLots"):
						if lot.is_in_group("BuildingLots") and lot.occupied_node == _placement_moving_node:
							_placement_original_lot = lot
							break
							
					_available_lots.clear()
					_active_lot_index = 0
					_placement_active_lot = null
					
					var player_settlement = _get_current_settlement(_active_player.global_position)
					if player_settlement:
						var player_pos = _active_player.global_position
						var all_lots = get_tree().get_nodes_in_group("BuildingLots")
						for lot in all_lots:
							if lot.has_method("calculate_lot_cost") and not lot.nearest_settlement:
								lot.calculate_lot_cost()
								
						for lot in all_lots:
							var is_vacant = not lot.is_occupied or lot == _placement_original_lot
							if is_vacant and lot.nearest_settlement == player_settlement:
								_available_lots.append(lot)
								
						_available_lots.sort_custom(func(a, b):
							return player_pos.distance_to(a.global_position) < player_pos.distance_to(b.global_position)
						)
						
						if _available_lots.size() > 0:
							var orig_idx = _available_lots.find(_placement_original_lot)
							if orig_idx != -1:
								_active_lot_index = orig_idx
							_placement_active_lot = _available_lots[_active_lot_index]
							_placement_position = _placement_active_lot.global_position
						else:
							_spawn_floating_text("No vacant lots in this settlement!", _active_player.global_position)
							exit_placement_mode()
							return
					else:
						_spawn_floating_text("Cant build here", _active_player.global_position)
						exit_placement_mode()
						return
					
					_disable_all_collisions(_placement_moving_node)
					var col = _placement_moving_node.get_node_or_null("CollisionShape2D")
					_placement_ghost_shape = col.shape.duplicate() if col else null
					_placement_moving_node.modulate = Color(0.3, 0.9, 0.3, 0.6)
					
					var rect_size = Vector2(64, 64)
					if _placement_ghost_shape is RectangleShape2D:
						rect_size = _placement_ghost_shape.size
					_attach_foundation(_placement_moving_node, rect_size)
					_hovered_workstation = null
					_spawn_floating_text("Moving...", _placement_position)
					get_viewport().set_input_as_handled()
					
		elif _placement_mode == "demolish":
			if _hovered_workstation and is_instance_valid(_hovered_workstation):
				var distance = _active_player.global_position.distance_to(_hovered_workstation.global_position) if _active_player else 0.0
				if distance > 160.0:
					_spawn_floating_text("Too far!", _hovered_workstation.global_position)
					return
					
				if _hovered_workstation.is_in_group("Houses") and not _hovered_workstation.is_rental and _hovered_workstation.ownership_type == "Player":
					var personal_homes = 0
					for h in get_tree().get_nodes_in_group("Houses"):
						if is_instance_valid(h) and h.ownership_type == "Player" and not h.is_rental:
							personal_homes += 1
					if personal_homes <= 1:
						_spawn_floating_text("Cannot demolish your last personal home!", _hovered_workstation.global_position)
						return
					
				var db_item = _hovered_workstation.building_data
				var refund = int(db_item.cost * 0.8) if db_item else 0
				
				GameState.next_change_reason = "Demolish Property"
				GameState.next_change_detail = db_item.name if db_item else "Workstation"
				GameState.gold += refund
				_spawn_floating_text("Demolished! +%d Gold" % refund, _hovered_workstation.global_position)
				
				for lot in get_tree().get_nodes_in_group("BuildingLots"):
					if lot.is_in_group("BuildingLots") and lot.occupied_node == _hovered_workstation:
						lot.is_occupied = false
						lot.occupied_node = null
						break
				
				if _active_player:
					_active_player.unregister_interactable(_hovered_workstation)
					
				var groups = ["CraftingBenches", "MarketStall", "WheatFields", "CottonPlants", "OreMines", "Beds", "Banks", "Inns", "Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Houses", "Warehouses", "nav_carve_obstacles"]
				for grp in groups:
					if _hovered_workstation.is_in_group(grp):
						_hovered_workstation.remove_from_group(grp)
				_hovered_workstation.queue_free()
				_hovered_workstation = null
				
				if GameState.has_method("rebake_all_navigation_regions"):
					NavigationManager.rebake_all_navigation_regions()
				
				if _hud and _hud.has_method("update_hud_values"):
					_hud.update_hud_values()
				exit_placement_mode()
				get_viewport().set_input_as_handled()

func _is_indoors(pos: Vector2) -> bool:
	return pos.x >= 3100.0 and pos.x <= 3400.0 and pos.y >= 3100.0 and pos.y <= 3300.0

func _attach_foundation(parent_node: Node2D, size: Vector2) -> void:
	_cleanup_foundation()
	var foundation = Node2D.new()
	foundation.name = "FoundationHelper"
	
	_placement_foundation_fill = ColorRect.new()
	_placement_foundation_fill.size = size
	_placement_foundation_fill.position = -size / 2.0
	_placement_foundation_fill.color = Color(0.2, 0.8, 0.4, 0.3)
	_placement_foundation_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foundation.add_child(_placement_foundation_fill)
	
	_placement_foundation_outline = ReferenceRect.new()
	_placement_foundation_outline.size = size
	_placement_foundation_outline.position = -size / 2.0
	_placement_foundation_outline.border_color = Color(0.3, 0.9, 0.5, 0.95)
	_placement_foundation_outline.border_width = 2.0
	_placement_foundation_outline.editor_only = false
	_placement_foundation_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foundation.add_child(_placement_foundation_outline)
	
	parent_node.add_child(foundation)

func _cleanup_foundation() -> void:
	if _placement_foundation_fill and is_instance_valid(_placement_foundation_fill):
		var parent = _placement_foundation_fill.get_parent()
		if parent:
			parent.queue_free()
	_placement_foundation_fill = null
	_placement_foundation_outline = null

func _find_closest_settlement(pos: Vector2) -> Node2D:
	var min_dist: float = INF
	var closest: Node2D = null
	for city in get_tree().get_nodes_in_group("Cities"):
		var dist = pos.distance_to(city.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = city
	for town in get_tree().get_nodes_in_group("Towns"):
		var dist = pos.distance_to(town.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = town
	return closest

func _get_current_settlement(pos: Vector2) -> Node2D:
	var closest = _find_closest_settlement(pos)
	if closest:
		var radius = 600.0
		if "radius_of_influence" in closest:
			radius = closest.radius_of_influence
		if pos.distance_to(closest.global_position) <= radius:
			return closest
	return null

func _disable_all_collisions(node: Node) -> void:
	if node is CollisionObject2D:
		node.set_meta("orig_layer", node.collision_layer)
		node.set_meta("orig_mask", node.collision_mask)
		node.collision_layer = 0
		node.collision_mask = 0
	if node is CollisionShape2D:
		node.disabled = true
	for child in node.get_children():
		_disable_all_collisions(child)

func _enable_all_collisions(node: Node) -> void:
	if node is CollisionObject2D:
		if node.has_meta("orig_layer"):
			node.collision_layer = node.get_meta("orig_layer")
		else:
			node.collision_layer = 1
		if node.has_meta("orig_mask"):
			node.collision_mask = node.get_meta("orig_mask")
		else:
			node.collision_mask = 1
	if node is CollisionShape2D:
		var p_name = node.get_parent().name.to_lower()
		if node.name == "CollisionShape2D" and p_name.contains("grid"):
			node.disabled = true
		else:
			node.disabled = false
	for child in node.get_children():
		_enable_all_collisions(child)

func _collect_collision_rids(node: Node, rids: Array) -> void:
	if node is CollisionObject2D:
		rids.append(node.get_rid())
	for child in node.get_children():
		_collect_collision_rids(child, rids)

func _is_position_clear(pos: Vector2, shape: Shape2D) -> bool:
	var space_state = get_viewport().world_2d.direct_space_state
	if not space_state:
		return true
		
	var query_shape = shape
	if shape is RectangleShape2D:
		var dup = shape.duplicate() as RectangleShape2D
		dup.size -= Vector2(4.0, 4.0)
		query_shape = dup
	elif shape is CircleShape2D:
		var dup = shape.duplicate() as CircleShape2D
		dup.radius -= 2.0
		query_shape = dup
	elif shape is CapsuleShape2D:
		var dup = shape.duplicate() as CapsuleShape2D
		dup.radius -= 2.0
		dup.height -= 4.0
		query_shape = dup

		
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = query_shape
	query.transform = Transform2D(0, pos)
	query.collision_mask = 1
	
	var exclude_list = []
	if _placement_moving_node and is_instance_valid(_placement_moving_node):
		_collect_collision_rids(_placement_moving_node, exclude_list)
	if _placement_ghost and is_instance_valid(_placement_ghost):
		_collect_collision_rids(_placement_ghost, exclude_list)
		
	# Exclude all BuildingLots so they do not block placement collision queries
	for lot in get_tree().get_nodes_in_group("BuildingLots"):
		if lot is CollisionObject2D:
			exclude_list.append(lot.get_rid())
			
	query.exclude = exclude_list
	var results = space_state.intersect_shape(query)
	return results.is_empty()

func _process_workstation_hover() -> void:
	var global_mouse = get_parent().get_global_mouse_position()
	var found_workstation: Node2D = null
	var groups = ["CraftingBenches", "MarketStall", "WheatFields", "CottonPlants", "OreMines", "Beds", "Banks", "Inns", "Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Houses", "Warehouses"]
	for grp in groups:
		var nodes = get_tree().get_nodes_in_group(grp)
		for node in nodes:
			if node is CollisionObject2D:
				var col = node.get_node_or_null("CollisionShape2D")
				if col and col.shape is RectangleShape2D:
					var size = col.shape.size
					var rect = Rect2(node.global_position - size / 2.0, size)
					if rect.has_point(global_mouse):
						found_workstation = node
						break
		if found_workstation:
			break
			
	if found_workstation != _hovered_workstation:
		if _hovered_workstation and is_instance_valid(_hovered_workstation):
			_hovered_workstation.modulate = Color(1, 1, 1, 1)
		_hovered_workstation = found_workstation
		if _hovered_workstation:
			_hovered_workstation.modulate = Color(1.5, 1.5, 0.8, 1)

func _spawn_floating_text(sn_text: String, pos: Vector2) -> void:
	if _hud and _hud.has_method("_spawn_floating_text"):
		_hud._spawn_floating_text(sn_text, pos)

func _find_best_lot_in_direction(dir_vector: Vector2) -> Node2D:
	if not _placement_active_lot or _available_lots.size() <= 1:
		return null
		
	var current_pos = _placement_active_lot.global_position
	var best_candidate: Node2D = null
	var min_cost: float = INF
	
	for lot in _available_lots:
		if lot == _placement_active_lot:
			continue
			
		var diff = lot.global_position - current_pos
		var proj = diff.dot(dir_vector)
		if proj <= 5.0: # Candidate must be in the forward direction
			continue
			
		# Scalar projection perpendicular distance:
		# |diff x dir_vector| for normalized dir_vector
		var perp = abs(diff.x * dir_vector.y - diff.y * dir_vector.x)
		
		# cost = projection distance + perpendicular penalty
		var cost = proj + 2.0 * perp
		if cost < min_cost:
			min_cost = cost
			best_candidate = lot
			
	return best_candidate

func _find_extreme_lot(find_most_expensive: bool) -> Node2D:
	if _available_lots.is_empty():
		return null
		
	var best_lot: Node2D = _available_lots[0]
	var extreme_cost = best_lot.calculate_lot_cost()
	
	for lot in _available_lots:
		var cost = lot.calculate_lot_cost()
		if find_most_expensive:
			if cost > extreme_cost:
				extreme_cost = cost
				best_lot = lot
		else:
			if cost < extreme_cost:
				extreme_cost = cost
				best_lot = lot
				
	return best_lot
