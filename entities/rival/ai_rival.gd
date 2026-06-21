class_name AIRival
extends CharacterBody2D

@export var speed: float = 80.0
@export var gold: int = 1500
@export var family_name: String = "Fugger Family"
@export var standing: String = "Competitor"
var productivity: float:
	get: return 1.0 + (level * 0.02)
	set(val): pass
var is_harvesting: bool = false
var is_gathering: bool = false
var current_mega_node: Node2D = null
var status_label: Label = null

var active_roads_count: int = 0
var speed_multiplier: float = 1.0

# Rival Career Stats
var profession: String = "patreon"
var level: int = 1
var xp: int = 0
var career_behavior: RivalCareerBehavior = null
var active_settlements: Array[Node2D] = []

var _default_gather_resource_id: String = ""
var _default_final_sell_item_id: String = ""

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var inventory: Node = $InventoryComponent

enum State {
	IDLE,
	WALKING_TO_RAW,
	GATHERING,
	WALKING_TO_REFINERY,
	REFINING,
	WALKING_TO_FINISHED,
	PRODUCING,
	WALKING_TO_STALL,
	SELLING
}

var current_state: State = State.WALKING_TO_RAW
var current_schedule: String = "work" # "sleep", "morning", "work", "lunch", "evening"

var _last_direction: String = "south"
var _state_timer: float = 0.0
var _break_next_state: State = State.IDLE

# Target nodes in the world
var _target_field: Node2D = null
var _target_bench: Node2D = null
var _target_finished_bench: Node2D = null
var _target_stall: Node2D = null

# Wander variables
var _wander_target: Vector2 = Vector2.ZERO
var _wander_wait_timer: float = 0.0
var _house_buy_check_timer: float = 5.0

# 10.0 seconds of game time check timer (for buildings and employees)
var _building_check_timer: float = 10.0

var _spawn_position: Vector2 = Vector2.ZERO
var nav_agent: NavigationAgent2D

func _ready() -> void:
	_spawn_position = global_position
	# Add rival to group
	add_to_group("Rivals")
	
	collision_layer = 8
	collision_mask = 0
	
	# Instantiate NavigationAgent2D dynamically and set to 16.0 pixel parameters
	nav_agent = NavigationAgent2D.new()
	nav_agent.path_desired_distance = 16.0
	nav_agent.target_desired_distance = 16.0
	add_child(nav_agent)
	
	# Force Patreon career as it is the most developed
	profession = "patreon"
	career_behavior = RivalCareerBehavior.get_behavior_for_career(profession)
	if career_behavior:
		_default_gather_resource_id = career_behavior.gather_resource_id
		_default_final_sell_item_id = career_behavior.final_sell_item_id
	
	# Tint sprite to distinguish from player (e.g. reddish tint)
	if animated_sprite:
		animated_sprite.modulate = Color(1.0, 0.6, 0.6)
		
	# Signal-driven Sandbox Pausing
	if GameState:
		if not GameState.rival_ai_active_changed.is_connected(_on_rival_ai_active_changed):
			GameState.rival_ai_active_changed.connect(_on_rival_ai_active_changed)
		_on_rival_ai_active_changed(GameState.rival_ai_active)
	
	_setup_status_label()
	
	# Delay finding targets slightly to ensure scenes are fully loaded
	await get_tree().process_frame
	
	# Initialize home settlement
	var start_sett = GameState.get_nearest_settlement(self)
	if start_sett:
		active_settlements.append(start_sett)
		
	_route_to_state_target()

func _on_rival_ai_active_changed(active: bool) -> void:
	set_physics_process(active)
	set_process(active)
	if not active:
		velocity = Vector2.ZERO
		if animated_sprite:
			animated_sprite.play("idle_" + _last_direction)

func add_xp(amount: int) -> void:
	xp += amount
	var xp_to_next: int = int(round(100 * pow(1.5, level - 1)))
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		_spawn_floating_text("%s Leveled Up to Lvl %d!" % [family_name, level])
		xp_to_next = int(round(100 * pow(1.5, level - 1)))

func gain_profession_xp(career_id: String, amount: int) -> void:
	add_xp(amount)

func is_accessible_by_rival(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	var target = node
	var grid = _get_grid_for_crop(node)
	if grid:
		target = grid
		
	if "ownership_type" in target:
		return target.ownership_type == "Public" or (target.ownership_type == "NPC" and target.get("owner_id") == "Rival")
	return true

func _get_grid_for_crop(crop_plot: Node2D) -> Node2D:
	if not is_instance_valid(crop_plot):
		return null
	for grid in get_tree().get_nodes_in_group("WheatFieldGrids"):
		if "crop_nodes" in grid and crop_plot in grid.crop_nodes:
			return grid
	for grid in get_tree().get_nodes_in_group("CottonPatchGrids"):
		if "crop_nodes" in grid and crop_plot in grid.crop_nodes:
			return grid
	return null

func _find_raw_resource() -> void:
	if is_instance_valid(_target_field) and _target_field.is_in_group("Fountains"):
		return
	if is_instance_valid(_target_field) and _target_field.is_in_group("MegaNodes") and _target_field.resource_type_id == career_behavior.gather_resource_id:
		return
		
	var nodes = get_tree().get_nodes_in_group("MegaNodes")
	for node in nodes:
		if node.resource_type_id == career_behavior.gather_resource_id:
			_target_field = node
			break

func _find_refinery() -> void:
	if is_instance_valid(_target_bench):
		return
		
	var stations = get_tree().get_nodes_in_group(career_behavior.refine_station_group)
	var best_station = null
	var min_dist = INF
	
	# 1. Search in active settlements
	for station in stations:
		if is_instance_valid(station) and is_accessible_by_rival(station):
			var sett = GameState.get_nearest_settlement(station)
			if sett in active_settlements:
				var dist = global_position.distance_to(station.global_position)
				if dist < min_dist:
					min_dist = dist
					best_station = station
					
	# 2. Fallback globally
	if not best_station:
		for station in stations:
			if is_instance_valid(station) and is_accessible_by_rival(station):
				var dist = global_position.distance_to(station.global_position)
				if dist < min_dist:
					min_dist = dist
					best_station = station
					
	_target_bench = best_station

func _find_finished_workshop() -> void:
	if is_instance_valid(_target_finished_bench):
		return
		
	var stations = get_tree().get_nodes_in_group(career_behavior.finish_station_group)
	var best_station = null
	var min_dist = INF
	
	# 1. Search in active settlements
	for station in stations:
		if is_instance_valid(station) and is_accessible_by_rival(station):
			var sett = GameState.get_nearest_settlement(station)
			if sett in active_settlements:
				var dist = global_position.distance_to(station.global_position)
				if dist < min_dist:
					min_dist = dist
					best_station = station
					
	# 2. Fallback globally
	if not best_station:
		for station in stations:
			if is_instance_valid(station) and is_accessible_by_rival(station):
				var dist = global_position.distance_to(station.global_position)
				if dist < min_dist:
					min_dist = dist
					best_station = station
					
	_target_finished_bench = best_station

func _find_stall() -> void:
	if is_instance_valid(_target_stall):
		return
		
	var stalls = get_tree().get_nodes_in_group("MarketStall")
	var best_stall = null
	var min_dist = INF
	
	# 1. Search owned stalls in active settlements
	for stall in stalls:
		if is_instance_valid(stall) and stall.ownership_type == "NPC" and stall.owner_id == "Rival":
			var sett = GameState.get_nearest_settlement(stall)
			if sett in active_settlements:
				var dist = global_position.distance_to(stall.global_position)
				if dist < min_dist:
					min_dist = dist
					best_stall = stall
					
	# 2. Fallback: Search owned stalls globally
	if not best_stall:
		for stall in stalls:
			if is_instance_valid(stall) and stall.ownership_type == "NPC" and stall.owner_id == "Rival":
				var dist = global_position.distance_to(stall.global_position)
				if dist < min_dist:
					min_dist = dist
					best_stall = stall
					
	# 3. Fallback: Search any accessible stall globally
	if not best_stall:
		for stall in stalls:
			if is_accessible_by_rival(stall):
				var dist = global_position.distance_to(stall.global_position)
				if dist < min_dist:
					min_dist = dist
					best_stall = stall
					
	_target_stall = best_stall

func _physics_process(delta: float) -> void:
	gold = max(gold, 150)
	_update_status_label()
	
	# Periodic check to buy vacant overworld rental houses
	_house_buy_check_timer -= delta
	if _house_buy_check_timer <= 0.0:
		_house_buy_check_timer = 5.0
		try_buy_available_house()

	# Periodic check to construct buildings or hire workers
	_building_check_timer -= delta * TimeManager.TIME_SPEED
	if _building_check_timer <= 0.0:
		_building_check_timer = 10.0
		try_construct_next_building()
		try_hire_employees()
		try_deploy_ai_worker()

	# 1. Update daily schedule
	_update_schedule()
	
	# 2. Process active delays / breaks
	if _state_timer > 0.0:
		_state_timer -= delta
		velocity = Vector2.ZERO
		if animated_sprite:
			animated_sprite.play("idle_" + _last_direction)
		move_and_slide()
		
		# If break timer finished, resume work
		if _state_timer <= 0.0 and current_state == State.IDLE and _break_next_state != State.IDLE:
			current_state = _break_next_state
			_break_next_state = State.IDLE
			_route_to_state_target()
		return

	# 3. Execute schedule behavior
	match current_schedule:
		"sleep":
			velocity = Vector2.ZERO
			if animated_sprite:
				animated_sprite.play("idle_" + _last_direction)
			move_and_slide()
			
		"lunch":
			_find_stall()
			var target = _target_stall.global_position + Vector2(0, 50) if _target_stall else _spawn_position
			if global_position.distance_to(target) > 20.0:
				_walk_towards(target, delta)
			else:
				velocity = Vector2.ZERO
				if animated_sprite:
					animated_sprite.play("idle_" + _last_direction)
				move_and_slide()
				
		"morning":
			_process_wandering(_spawn_position, 100.0, delta)
			
		"evening":
			_process_wandering(_spawn_position + Vector2(0, 50), 80.0, delta)
			
		"work":
			_process_work_state(delta)

func _process_work_state(delta: float) -> void:
	match current_state:
		State.WALKING_TO_RAW:
			if _check_opportunistic_selling():
				return
				
			if not is_instance_valid(_target_field) or not (_target_field.is_in_group("Fountains") or _target_field.is_in_group("MegaNodes")):
				_find_raw_resource()
				
			if _target_field:
				var is_fountain = _target_field.is_in_group("Fountains")
				if not is_fountain and not is_harvesting:
					if _target_field.active_gatherers.size() >= _target_field.max_slots:
						log_rival_decision("Raw resource %s is full. Waiting..." % _target_field.node_name)
						_break_next_state = State.WALKING_TO_RAW
						_start_work_state(State.IDLE, randf_range(3.0, 6.0))
						return
					
					var fee = _target_field.get_entry_fee()
					if gold >= fee:
						gold -= fee
						is_harvesting = true
						_spawn_floating_text("Paid Permit: -%d Gold!" % fee)
						log_rival_decision("Paid permit of %d gold for %s" % [fee, _target_field.node_name])
					else:
						log_rival_decision("Not enough gold to pay permit of %d gold for %s (current gold: %d). Waiting..." % [fee, _target_field.node_name, gold])
						_break_next_state = State.WALKING_TO_RAW
						_start_work_state(State.IDLE, randf_range(3.0, 6.0))
						return
				
				_walk_towards_target_node(_target_field, delta)
				var phys_pos = global_position
				if phys_pos.distance_to(_target_field.global_position) < 48.0 or nav_agent.is_navigation_finished():
					if is_fountain:
						var econ_mgr = get_node_or_null("/root/EconomyManager")
						var water_res = econ_mgr.item_database.get("water") if econ_mgr else null
						if water_res and inventory:
							inventory.add_item(water_res, 5)
						_spawn_floating_text("Gathered Water from Fountain!")
						log_rival_decision("Gathered 5 Water units from Fountain. Transitioning to WALKING_TO_STALL to sell.")
						_start_work_state(State.WALKING_TO_STALL, 0.5)
					else:
						log_rival_decision("Arrived at raw resource %s. Starting GATHERING" % _target_field.node_name)
						current_state = State.GATHERING
			else:
				log_rival_decision("No raw resource found. Transitioning to WALKING_TO_REFINERY")
				_start_work_state(State.WALKING_TO_REFINERY, 0.1)
				
		State.GATHERING:
			velocity = Vector2.ZERO
			if animated_sprite:
				animated_sprite.play("idle_" + _last_direction)
			move_and_slide()
			
			var lm = get_node_or_null("/root/LogisticsManager")
			if lm and _target_field:
				# Safety check: if target field is valid, and we are not in its active_gatherers,
				# try to join it, or if it is full, reset!
				if not _target_field.active_gatherers.has(self):
					if _target_field.active_gatherers.size() < _target_field.max_slots:
						_target_field.active_gatherers.append(self)
						is_gathering = true
						current_mega_node = _target_field
						lm.start_gathering(self, _target_field)
						_target_field._spawn_floating_text("%s began harvesting (safely)!" % family_name)
						log_rival_decision("Safely joined active gatherers list for %s" % _target_field.node_name)
					else:
						# Target field is full! We cannot gather here. Reset!
						log_rival_decision("Cannot gather at %s: Node is full. Resetting to WALKING_TO_RAW" % _target_field.node_name)
						is_harvesting = false
						_start_work_state(State.WALKING_TO_RAW, randf_range(3.0, 6.0))
						return

				var amt = lm.get_buffer_amount(self)
				var congestion = _target_field.get_congestion_factor()
				
				if amt >= 3 or (amt > 0 and congestion < 0.55):
					is_harvesting = false
					log_rival_decision("Collected harvest of %d %s from buffer. Transitioning to WALKING_TO_REFINERY" % [amt, _target_field.resource_type_id])
					lm.collect_rival_worker_yield(self)
					lm.erase_buffer(self)
					_target_field._on_body_exited(self)
					_start_work_state(State.WALKING_TO_REFINERY, 0.5)
			else:
				is_harvesting = false
				log_rival_decision("No LogisticsManager or target field found during GATHERING. Transitioning to WALKING_TO_REFINERY")
				_start_work_state(State.WALKING_TO_REFINERY, 0.5)
			
		State.WALKING_TO_REFINERY:
			var raw_owned = inventory.get_item_amount(career_behavior.gather_resource_id)
			if raw_owned < 1:
				log_rival_decision("No raw materials owned (%s). Heading back to WALKING_TO_RAW" % career_behavior.gather_resource_id)
				_start_work_state(State.WALKING_TO_RAW, 0.1)
				return
				
			_find_refinery()
			if _target_bench:
				_walk_towards_target_node(_target_bench, delta)
				var phys_pos = global_position + Vector2(0, -34)
				if phys_pos.distance_to(_target_bench.global_position) < 85.0 or nav_agent.is_navigation_finished():
					log_rival_decision("Arrived at refinery %s. Starting REFINING" % _target_bench.name)
					_start_work_state(State.REFINING, 2.5)
			else:
				log_rival_decision("No refinery station found. Transitioning directly to WALKING_TO_STALL")
				_start_work_state(State.WALKING_TO_STALL, 0.1)
				
		State.REFINING:
			var recipe = load(career_behavior.refining_recipe_path)
			if recipe:
				log_rival_decision("Executing refining recipe: %s" % recipe.resource_path.get_file())
				execute_recipe(recipe, career_behavior.gather_resource_id)
			
			if career_behavior.has_finished_product():
				log_rival_decision("Career has finished product. Transitioning to WALKING_TO_FINISHED")
				_start_work_state(State.WALKING_TO_FINISHED, 0.5)
			else:
				log_rival_decision("No finished product step. Transitioning directly to WALKING_TO_STALL")
				_start_work_state(State.WALKING_TO_STALL, 0.5)
				
		State.WALKING_TO_FINISHED:
			var refine_output_id = ""
			var refine_recipe = load(career_behavior.refining_recipe_path)
			if refine_recipe:
				refine_output_id = refine_recipe.output_item.id
			
			var ref_owned = inventory.get_item_amount(refine_output_id)
			if ref_owned < 1:
				log_rival_decision("No refined materials owned (%s). Heading back to WALKING_TO_RAW" % refine_output_id)
				_start_work_state(State.WALKING_TO_RAW, 0.1)
				return
				
			_find_finished_workshop()
			if _target_finished_bench:
				_walk_towards_target_node(_target_finished_bench, delta)
				var phys_pos = global_position + Vector2(0, -34)
				if phys_pos.distance_to(_target_finished_bench.global_position) < 85.0 or nav_agent.is_navigation_finished():
					log_rival_decision("Arrived at finished workshop %s. Starting PRODUCING" % _target_finished_bench.name)
					_start_work_state(State.PRODUCING, 2.5)
			else:
				log_rival_decision("No finished workshop found. Transitioning directly to WALKING_TO_STALL")
				_start_work_state(State.WALKING_TO_STALL, 0.1)
				
		State.PRODUCING:
			var refine_output_id = ""
			var refine_recipe = load(career_behavior.refining_recipe_path)
			if refine_recipe:
				refine_output_id = refine_recipe.output_item.id
				
			var recipe = load(career_behavior.finished_recipe_path)
			if recipe:
				log_rival_decision("Executing finished product recipe: %s" % recipe.resource_path.get_file())
				execute_recipe(recipe, refine_output_id)
			log_rival_decision("Finished production. Transitioning to WALKING_TO_STALL")
			_start_work_state(State.WALKING_TO_STALL, 0.5)
			
		State.WALKING_TO_STALL:
			var sell_owned = inventory.get_item_amount(career_behavior.final_sell_item_id)
			if sell_owned < 1:
				log_rival_decision("No sellable items owned (%s). Heading back to WALKING_TO_RAW" % career_behavior.final_sell_item_id)
				if career_behavior:
					if _default_gather_resource_id != "":
						career_behavior.gather_resource_id = _default_gather_resource_id
					if _default_final_sell_item_id != "":
						career_behavior.final_sell_item_id = _default_final_sell_item_id
				_target_stall = null
				_target_field = null
				_start_work_state(State.WALKING_TO_RAW, 0.1)
				return
				
			_find_stall()
			if _target_stall:
				_walk_towards_target_node(_target_stall, delta)
				var phys_pos = global_position + Vector2(0, -34)
				if phys_pos.distance_to(_target_stall.global_position) < 85.0 or nav_agent.is_navigation_finished():
					log_rival_decision("Arrived at market stall %s. Starting SELLING" % _target_stall.name)
					_start_work_state(State.SELLING, 2.0)
			else:
				log_rival_decision("No market stall found. Heading back to WALKING_TO_RAW")
				if career_behavior:
					if _default_gather_resource_id != "":
						career_behavior.gather_resource_id = _default_gather_resource_id
					if _default_final_sell_item_id != "":
						career_behavior.final_sell_item_id = _default_final_sell_item_id
				_target_stall = null
				_target_field = null
				_start_work_state(State.WALKING_TO_RAW, 0.1)
				
		State.SELLING:
			var sell_owned = inventory.get_item_amount(career_behavior.final_sell_item_id)
			if sell_owned > 0 and _target_stall:
				var stall = _target_stall
				var econ_mgr = get_node_or_null("/root/EconomyManager")
				var sell_item_res = econ_mgr.item_database.get(career_behavior.final_sell_item_id) if econ_mgr else null
				if sell_item_res:
					if "inventory" in stall and stall.inventory:
						stall.inventory.add_item(sell_item_res, sell_owned)
					inventory.remove_item(career_behavior.final_sell_item_id, sell_owned)
					
					var price = 0
					if stall.has_method("get_sell_price"):
						price = stall.get_sell_price(sell_item_res) * sell_owned
					else:
						price = sell_item_res.base_value * sell_owned
					gold += price
					_spawn_floating_text("Rival sold %s for %d Gold!" % [sell_item_res.name, price])
					log_rival_decision("Sold %d %s at %s for %d gold. Total gold now: %d" % [sell_owned, sell_item_res.name, stall.name, price, gold])
			
			if career_behavior:
				if _default_gather_resource_id != "":
					career_behavior.gather_resource_id = _default_gather_resource_id
				if _default_final_sell_item_id != "":
					career_behavior.final_sell_item_id = _default_final_sell_item_id
			_target_stall = null
			_target_field = null
			_start_work_state(State.WALKING_TO_RAW, 2.0)

func execute_recipe(recipe: Resource, primary_input_id: String) -> void:
	if not recipe:
		return
	var primary_item: ItemData = null
	var primary_req_qty = 1
	for input_res in recipe.inputs:
		if input_res.id == primary_input_id:
			primary_item = input_res
			primary_req_qty = recipe.inputs[input_res]
			break
	
	var primary_owned = inventory.get_item_amount(primary_input_id)
	var craft_count = primary_owned / primary_req_qty
	if craft_count > 0:
		inventory.remove_item(primary_input_id, craft_count * primary_req_qty)
		inventory.add_item(recipe.output_item, craft_count * recipe.output_amount)
		add_xp(recipe.xp_reward * craft_count)
		_spawn_floating_text("Rival crafted %s!" % recipe.output_item.name)

func _walk_towards_target_node(target_node: Node2D, _delta: float) -> void:
	if not is_instance_valid(target_node):
		return
		
	if nav_agent.target_position != target_node.global_position:
		nav_agent.target_position = target_node.global_position
	
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		if animated_sprite:
			animated_sprite.play("idle_" + _last_direction)
		move_and_slide()
		return
		
	var next_path_pos = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_path_pos)
	velocity = dir * speed * speed_multiplier
	
	if velocity != Vector2.ZERO:
		_last_direction = _get_cardinal_direction(velocity)
		if animated_sprite:
			animated_sprite.play("walk_" + _last_direction)
	else:
		if animated_sprite:
			animated_sprite.play("idle_" + _last_direction)
			
	move_and_slide()

func _walk_towards(target_pos: Vector2, _delta: float) -> void:
	if nav_agent.target_position != target_pos:
		nav_agent.target_position = target_pos
	
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		if animated_sprite:
			animated_sprite.play("idle_" + _last_direction)
		move_and_slide()
		return
		
	var next_path_pos = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_path_pos)
	velocity = dir * speed * speed_multiplier
	
	if velocity != Vector2.ZERO:
		_last_direction = _get_cardinal_direction(velocity)
		if animated_sprite:
			animated_sprite.play("walk_" + _last_direction)
	else:
		if animated_sprite:
			animated_sprite.play("idle_" + _last_direction)
			
	move_and_slide()

func _start_work_state(new_state: State, duration: float) -> void:
	current_state = new_state
	_state_timer = duration
	
	# Chance of break
	if new_state in [State.WALKING_TO_RAW, State.WALKING_TO_REFINERY, State.WALKING_TO_FINISHED, State.WALKING_TO_STALL]:
		if randf() < 0.40:
			_break_next_state = new_state
			current_state = State.IDLE
			_state_timer = randf_range(3.0, 6.0)
			_spawn_floating_text("Rival resting...")
			log_rival_decision("Decided to rest for %.1fs before heading to %s" % [_state_timer, _get_state_name(_break_next_state)])
			return

	log_rival_decision("Changed state to %s (duration: %.1fs)" % [_get_state_name(current_state), duration])

func _get_state_name(state: State) -> String:
	match state:
		State.IDLE: return "IDLE"
		State.WALKING_TO_RAW: return "WALKING_TO_RAW"
		State.GATHERING: return "GATHERING"
		State.WALKING_TO_REFINERY: return "WALKING_TO_REFINERY"
		State.REFINING: return "REFINING"
		State.WALKING_TO_FINISHED: return "WALKING_TO_FINISHED"
		State.PRODUCING: return "PRODUCING"
		State.WALKING_TO_STALL: return "WALKING_TO_STALL"
		State.SELLING: return "SELLING"
	return "UNKNOWN"

func _setup_status_label() -> void:
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5)) # Golden/yellowish
	status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	status_label.add_theme_constant_override("outline_size", 4)
	status_label.position = Vector2(-75, -55)
	status_label.size = Vector2(150, 40)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(status_label)

func _update_status_label() -> void:
	if not is_instance_valid(status_label):
		return
		
	var state_desc = "Idle"
	match current_state:
		State.IDLE:
			state_desc = "Idle / Resting"
			if _break_next_state != State.IDLE:
				state_desc = "Resting (Next: %s)" % _get_state_name(_break_next_state)
		State.WALKING_TO_RAW:
			state_desc = "Walking to Raw Node"
			if _target_field:
				state_desc += " (%s)" % _target_field.node_name
		State.GATHERING:
			state_desc = "Gathering"
			if _target_field:
				state_desc += " (%s)" % _target_field.node_name
		State.WALKING_TO_REFINERY:
			state_desc = "Walking to Refinery"
			if _target_bench:
				state_desc += " (%s)" % _target_bench.name
		State.REFINING:
			state_desc = "Refining Materials"
		State.WALKING_TO_FINISHED:
			state_desc = "Walking to Workshop"
			if _target_finished_bench:
				state_desc += " (%s)" % _target_finished_bench.name
		State.PRODUCING:
			state_desc = "Producing Finished Good"
		State.WALKING_TO_STALL:
			state_desc = "Walking to Market"
			if _target_stall:
				state_desc += " (%s)" % _target_stall.name
		State.SELLING:
			state_desc = "Selling Goods"

	var sched_desc = current_schedule.capitalize()
	status_label.text = "%s (Lvl %d)\nGold: %d\n[%s] %s" % [
		family_name,
		level,
		gold,
		sched_desc,
		state_desc
	]

func log_rival_decision(msg: String) -> void:
	var timestamp = ""
	if GameState:
		timestamp = "[Day %d - %02d:%02d]" % [TimeManager.time_days, TimeManager.time_hours, TimeManager.time_minutes]
	var log_line = "%s %s: %s" % [timestamp, family_name, msg]
	print("[Rival AI Log] ", log_line)
	
	var file = FileAccess.open("res://rival_log.txt", FileAccess.READ_WRITE)
	if not file:
		file = FileAccess.open("res://rival_log.txt", FileAccess.WRITE)
	else:
		file.seek_end()
	if file:
		file.store_line(log_line)
		file.flush()

func on_mega_node_full(node: Area2D) -> void:
	log_rival_decision("Received on_mega_node_full from %s. Resetting state." % node.node_name)
	is_harvesting = false
	current_state = State.WALKING_TO_RAW
	_start_work_state(State.WALKING_TO_RAW, randf_range(3.0, 6.0))

func _route_to_state_target() -> void:
	match current_state:
		State.WALKING_TO_RAW:
			_find_raw_resource()
			if _target_field:
				nav_agent.target_position = _target_field.global_position
		State.WALKING_TO_REFINERY:
			_find_refinery()
			if _target_bench:
				nav_agent.target_position = _target_bench.global_position
		State.WALKING_TO_FINISHED:
			_find_finished_workshop()
			if _target_finished_bench:
				nav_agent.target_position = _target_finished_bench.global_position
		State.WALKING_TO_STALL:
			_find_stall()
			if _target_stall:
				nav_agent.target_position = _target_stall.global_position

func _update_schedule() -> void:
	var hours = TimeManager.time_hours
	var next_sched = "work"
	
	if hours >= 22 or hours < 6:
		next_sched = "sleep"
	elif hours >= 6 and hours < 8:
		next_sched = "morning"
	elif hours >= 12 and hours < 14:
		next_sched = "lunch"
	elif hours >= 18 and hours < 22:
		next_sched = "evening"
		
	if current_schedule != next_sched:
		var prev_sched = current_schedule
		current_schedule = next_sched
		_state_timer = 0.0
		_break_next_state = State.IDLE
		log_rival_decision("Schedule transitioned from %s to %s" % [prev_sched, next_sched])
		
		if next_sched != "work":
			if career_behavior:
				if _default_gather_resource_id != "":
					career_behavior.gather_resource_id = _default_gather_resource_id
				if _default_final_sell_item_id != "":
					career_behavior.final_sell_item_id = _default_final_sell_item_id
			_target_stall = null
			log_rival_decision("Schedule shifted away from work. Restored career behavior overrides.")
		
		match current_schedule:
			"sleep":
				current_state = State.IDLE
			"morning":
				_wander_target = global_position
				_wander_wait_timer = 0.0
			"lunch":
				_find_stall()
				if _target_stall:
					nav_agent.target_position = _target_stall.global_position + Vector2(0, 50)
			"evening":
				_wander_target = global_position
				_wander_wait_timer = 0.0
			"work":
				current_state = State.WALKING_TO_RAW
				_route_to_state_target()

func _process_wandering(center: Vector2, radius: float, delta: float) -> void:
	if _wander_wait_timer > 0.0:
		_wander_wait_timer -= delta
		velocity = Vector2.ZERO
		if animated_sprite:
			animated_sprite.play("idle_" + _last_direction)
		move_and_slide()
		return
		
	if global_position.distance_to(_wander_target) < 15.0 or _wander_target == Vector2.ZERO:
		var angle = randf() * TAU
		var dist = randf() * radius
		_wander_target = center + Vector2(cos(angle), sin(angle)) * dist
		_wander_wait_timer = randf_range(2.0, 5.0)
	else:
		_walk_towards(_wander_target, delta)

func _get_cardinal_direction(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "east" if direction.x > 0 else "west"
	else:
		return "south" if direction.y > 0 else "north"

func _spawn_floating_text(txt: String) -> void:
	var label = Label.new()
	label.text = txt
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(-30, -40)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 32.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	
	await tween.finished
	label.queue_free()

func try_buy_available_house() -> void:
	if gold <= 800:
		return
		
	var houses = get_tree().get_nodes_in_group("Houses")
	for house in houses:
		if is_instance_valid(house) and house.get("is_rental") and house.ownership_type == "NPC" and house.owner_id == "":
			var is_highlighted = false
			for lot in get_tree().get_nodes_in_group("BuildingLots"):
				if lot.occupied_node == house and lot.is_selected:
					is_highlighted = true
					break
			if is_highlighted:
				continue
				
			var cost = house.buy_cost * 3
			if gold >= cost:
				gold -= cost
				house.ownership_type = "NPC"
				house.owner_id = "Rival"
				if house.has_method("_update_door_state"):
					house._update_door_state()
				_spawn_floating_text("Rival bought house for %d G!" % cost)
				log_rival_decision("Bought house %s for %d gold (remaining: %d)" % [house.name if "name" in house else house.get_path(), cost, gold])
				break

func _get_settlement_name(settlement: Node2D) -> String:
	if not is_instance_valid(settlement):
		return "Unknown Settlement"
	if "city_name" in settlement and settlement.city_name != "":
		return settlement.city_name
	if "town_name" in settlement and settlement.town_name != "":
		return settlement.town_name
	return settlement.name

func _sync_active_settlements_with_buildings() -> void:
	var production_groups = ["Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Banks", "Inns", "Taverns", "Farmsteads", "Distilleries", "EventHalls"]
	for grp in production_groups:
		for b_node in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(b_node) and b_node.ownership_type == "NPC" and b_node.owner_id == "Rival":
				var nearest_sett = GameState.get_nearest_settlement(b_node)
				if nearest_sett and not active_settlements.has(nearest_sett):
					active_settlements.append(nearest_sett)

func _check_settlement_expansion() -> void:
	var max_allowed = 1
	if level >= 6:
		max_allowed = 3
	elif level >= 3:
		max_allowed = 2
		
	if active_settlements.size() >= max_allowed:
		return
		
	var settlements_with_lots = []
	for lot in get_tree().get_nodes_in_group("BuildingLots"):
		if is_instance_valid(lot):
			var s = GameState.get_nearest_settlement(lot)
			if s and not settlements_with_lots.has(s):
				settlements_with_lots.append(s)
				
	var possible_settlements = []
	for city in get_tree().get_nodes_in_group("Cities"):
		if not active_settlements.has(city) and settlements_with_lots.has(city):
			possible_settlements.append(city)
	for town in get_tree().get_nodes_in_group("Towns"):
		if not active_settlements.has(town) and settlements_with_lots.has(town):
			possible_settlements.append(town)
			
	if possible_settlements.is_empty():
		return
		
	var home = active_settlements[0]
	var best_sett = null
	var min_dist = INF
	for sett in possible_settlements:
		var dist = home.global_position.distance_to(sett.global_position)
		if dist < min_dist:
			min_dist = dist
			best_sett = sett
			
	if best_sett:
		var expansion_fee = 500
		if gold >= expansion_fee:
			gold -= expansion_fee
			active_settlements.append(best_sett)
			var s_name = _get_settlement_name(best_sett)
			_spawn_floating_text("Rival expanded to %s!" % s_name)
			log_rival_decision("Expanded operations to new settlement: %s (Expansion Fee: %d, remaining gold: %d)" % [s_name, expansion_fee, gold])

func try_construct_next_building() -> void:
	if active_settlements.is_empty():
		var start_sett = GameState.get_nearest_settlement(self)
		if start_sett:
			active_settlements.append(start_sett)
		else:
			return
			
	_sync_active_settlements_with_buildings()
	_check_settlement_expansion()
	
	for current_settlement in active_settlements:
		if not is_instance_valid(current_settlement):
			continue
			
		var target_province = GameState.get_province_of_node(current_settlement)
			
		for lvl in career_behavior.building_unlocks_by_level:
			if lvl <= level:
				var paths = career_behavior.building_unlocks_by_level[lvl]
				for path in paths:
					var b_data = load(path) as BuildingData
					if not b_data:
						continue
						
					var already_built = false
					var is_manufacturing = b_data.family in [
						"patreon_mill", "patreon_bakery", "patreon_distillery",
						"craftsman_smelter", "craftsman_forge", "craftsman_workshop", "craftsman_tinker",
						"tailor_loom", "scholar_paper_maker", "scholar_press"
					]
					
					var production_groups = ["Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Banks", "Inns", "Taverns", "Farmsteads", "Distilleries", "EventHalls"]
					for grp in production_groups:
						for b_node in get_tree().get_nodes_in_group(grp):
							if is_instance_valid(b_node) and b_node.ownership_type == "NPC" and b_node.owner_id == "Rival":
								if is_manufacturing:
									if GameState.get_province_of_node(b_node) == target_province:
										if b_node.building_data and b_node.building_data.family == b_data.family:
											already_built = true
											break
								else:
									var nearest_sett = GameState.get_nearest_settlement(b_node)
									if nearest_sett == current_settlement:
										if b_node.building_data and b_node.building_data.family == b_data.family:
											already_built = true
											break
						if already_built:
							break
							
					# Check construction sites
					for site in get_tree().get_nodes_in_group("ConstructionSites"):
						if is_instance_valid(site) and site.builder_owner_id == "Rival":
							if is_manufacturing:
								if GameState.get_province_of_node(site) == target_province:
									if site.building_data and site.building_data.family == b_data.family:
										already_built = true
										break
							else:
								var site_sett = GameState.get_nearest_settlement(site)
								if site_sett == current_settlement:
									if site.building_data and site.building_data.family == b_data.family:
										already_built = true
										break

					if not already_built:
						var vacant_lot: BuildingLot = null
						for lot in get_tree().get_nodes_in_group("BuildingLots"):
							if is_instance_valid(lot) and not lot.is_occupied:
								if lot.nearest_settlement == current_settlement:
									vacant_lot = lot
									break
									
						if vacant_lot:
							var total_cost = vacant_lot.calculate_lot_cost() + b_data.cost
							if gold >= total_cost:
								gold -= total_cost
								
								var const_site_scene = load("res://components/placement/construction_site.tscn")
								var const_site = const_site_scene.instantiate()
								const_site.global_position = vacant_lot.global_position
								const_site.building_data = b_data
								const_site.target_scene_path = b_data.scene_path
								const_site.build_time = b_data.time
								const_site.building_name = b_data.name
								const_site.builder_ownership_type = "NPC"
								const_site.builder_owner_id = "Rival"
								
								vacant_lot.is_occupied = true
								vacant_lot.occupied_node = const_site
								
								get_parent().add_child(const_site)
								
								var s_name = _get_settlement_name(current_settlement)
								_spawn_floating_text("Rival building %s in %s!" % [b_data.name, s_name])
								log_rival_decision("Initiated construction of %s on vacant lot in %s (Total Cost: %d, remaining gold: %d)" % [b_data.name, s_name, total_cost, gold])
								return # Build one at a time
							else:
								var s_name = _get_settlement_name(current_settlement)
								log_rival_decision("Wanted to construct %s in %s but lacked gold (Needed: %d, current gold: %d)" % [b_data.name, s_name, total_cost, gold])

func try_hire_employees() -> void:
	if gold < 500:
		return
		
	var production_groups = ["Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Banks", "Inns", "Taverns", "Farmsteads", "Distilleries", "EventHalls"]
	for grp in production_groups:
		for b_node in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(b_node) and b_node.ownership_type == "NPC" and b_node.owner_id == "Rival":
				var nearest_sett = GameState.get_nearest_settlement(b_node)
				if nearest_sett in active_settlements:
					if "hired_employees" in b_node and "max_employees" in b_node:
						if b_node.hired_employees.size() < b_node.max_employees:
							if b_node.hireable_candidates.is_empty():
								b_node._populate_candidates()
							
							if not b_node.hireable_candidates.is_empty():
								var candidate = b_node.hireable_candidates.pop_front()
								var fee = candidate.salary * 10
								if gold >= fee:
									gold -= fee
									
									var recipe_path = ""
									if grp == career_behavior.refine_station_group:
										recipe_path = career_behavior.refining_recipe_path
									elif grp == career_behavior.finish_station_group:
										recipe_path = career_behavior.finished_recipe_path
										
									var emp_dict = {
										"npc_ref": candidate,
										"name": candidate.npc_name if "npc_name" in candidate else candidate.name,
										"salary": candidate.salary if "salary" in candidate else 15,
										"career": candidate.career if "career" in candidate else "patreon",
										"levels": {
											"patreon": candidate.patreon_level if "patreon_level" in candidate else 1,
											"scholar": candidate.scholar_level if "scholar_level" in candidate else 1,
											"craftsman": candidate.craftsman_level if "craftsman_level" in candidate else 1,
											"tailor": candidate.tailor_level if "tailor_level" in candidate else 1
										},
										"active_recipe_path": recipe_path,
										"craft_timer": 5.0,
										"craft_total_time": 5.0,
										"is_repeating": true,
										"auto_gather_on_shortage": false,
										"is_paused": false
									}
									
									b_node.hired_employees.append(emp_dict)
									candidate.go_to_workshop(b_node)
									
									_spawn_floating_text("Rival hired %s!" % emp_dict.name)
									log_rival_decision("Hired employee %s for building %s (Fee: %d, remaining gold: %d)" % [emp_dict.name, b_node.name, fee, gold])
									return
								else:
									log_rival_decision("Wanted to hire employee %s for %s but lacked gold (Needed: %d, current gold: %d)" % [candidate.name, b_node.name, fee, gold])

func try_deploy_ai_worker() -> void:
	if gold < 500:
		return
		
	var target_node = null
	var nodes = get_tree().get_nodes_in_group("MegaNodes")
	for node in nodes:
		if node.resource_type_id == career_behavior.gather_resource_id:
			target_node = node
			break
			
	if not target_node:
		return
		
	if target_node.active_gatherers.size() >= target_node.max_slots:
		return
		
	var fee = target_node.get_entry_fee()
	if gold >= fee:
		gold -= fee
		_spawn_rival_worker_npc(target_node)
		_spawn_floating_text("Deployed Worker to %s!" % target_node.node_name)
		log_rival_decision("Deployed gatherer worker to %s (Permit Fee: %d, remaining gold: %d)" % [target_node.node_name, fee, gold])
	else:
		log_rival_decision("Wanted to deploy gatherer worker to %s but lacked gold (Needed: %d, current gold: %d)" % [target_node.node_name, fee, gold])

func _spawn_rival_worker_npc(node: Area2D) -> void:
	var npc_scene = load("res://entities/npc/npc.tscn")
	if not npc_scene:
		return
		
	var worker = npc_scene.instantiate() as CharacterBody2D
	worker.set_script(load("res://components/gathering/gathering_worker.gd"))
	
	worker.owner_id = "Rival"
	worker.worker_name = "Rival Gatherer"
	worker.target_mega_node = node
	
	var spawn_pos = _spawn_position
	
	var production_groups = ["Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Banks", "Inns", "Taverns", "Farmsteads", "Distilleries", "EventHalls"]
	for grp in production_groups:
		for b_node in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(b_node) and b_node.ownership_type == "NPC" and b_node.get("owner_id") == "Rival":
				worker.home_workshop = b_node
				spawn_pos = b_node.global_position
				break
		if worker.home_workshop:
			break
			
	worker.global_position = spawn_pos
	get_parent().add_child(worker)

func _check_opportunistic_selling() -> bool:
	if not career_behavior:
		return false
		
	# If we are already doing an opportunistic task, don't override again
	if career_behavior.gather_resource_id == "water" or career_behavior.final_sell_item_id != _default_final_sell_item_id:
		return false
		
	var stalls = get_tree().get_nodes_in_group("MarketStall")
	var econ_mgr = get_node_or_null("/root/EconomyManager")
	if not econ_mgr:
		return false
		
	# Find items that are at 0 stock in public markets
	var zero_stock_items = [] # Array of dictionaries: {"stall": stall, "item": item}
	for stall in stalls:
		if is_instance_valid(stall) and stall.ownership_type == "Public" and stall.inventory:
			for item in stall.target_stock:
				if stall.inventory.get_item_amount(item.id) == 0:
					zero_stock_items.append({"stall": stall, "item": item})
					
	if zero_stock_items.is_empty():
		return false
		
	# 1. Check if we already have any of these out-of-stock items in our inventory
	for entry in zero_stock_items:
		var item = entry["item"]
		var stall = entry["stall"]
		if inventory.get_item_amount(item.id) > 0:
			# Opportunistic Sell: Walk to stall and sell it
			_target_stall = stall
			career_behavior.final_sell_item_id = item.id
			log_rival_decision("Opportunity detected: %s is out of stock at %s. We have %d in inventory. Walking to sell for premium profit!" % [item.id, stall.name, inventory.get_item_amount(item.id)])
			_start_work_state(State.WALKING_TO_STALL, 0.1)
			return true
			
	# 2. Check if Water is at 0 stock, and we can fetch it from a Fountain
	for entry in zero_stock_items:
		var item = entry["item"]
		var stall = entry["stall"]
		if item.id == "water":
			# Locate the nearest Fountain
			var fountains = get_tree().get_nodes_in_group("Fountains")
			if not fountains.is_empty():
				var nearest_fountain = null
				var min_dist = INF
				for f in fountains:
					if is_instance_valid(f):
						var dist = global_position.distance_to(f.global_position)
						if dist < min_dist:
							min_dist = dist
							nearest_fountain = f
				if nearest_fountain:
					_target_field = nearest_fountain
					_target_stall = stall
					career_behavior.gather_resource_id = "water"
					career_behavior.final_sell_item_id = "water"
					log_rival_decision("Opportunity detected: Water is out of stock at %s. Walking to Fountain %s to gather water!" % [stall.name, nearest_fountain.name])
					_start_work_state(State.WALKING_TO_RAW, 0.1)
					return true
					
	return false


