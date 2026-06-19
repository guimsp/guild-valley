class_name AIRival
extends CharacterBody2D

@export var speed: float = 80.0
@export var gold: int = 1000
@export var family_name: String = "Fugger Family"
@export var standing: String = "Competitor"
var productivity: float:
	get: return 1.0 + (level * 0.02)
	set(val): pass
var is_harvesting: bool = false
var is_gathering: bool = false
var current_mega_node: Node2D = null

var active_roads_count: int = 0
var speed_multiplier: float = 1.0

# Rival Career Stats
var profession: String = "patreon"
var level: int = 1
var xp: int = 0
var career_behavior: RivalCareerBehavior = null

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
	
	# Select a random starting career
	var careers = ["patreon", "craftsman", "tailor", "scholar"]
	profession = careers[randi() % careers.size()]
	career_behavior = RivalCareerBehavior.get_behavior_for_career(profession)
	
	# Tint sprite to distinguish from player (e.g. reddish tint)
	if animated_sprite:
		animated_sprite.modulate = Color(1.0, 0.6, 0.6)
		
	# Signal-driven Sandbox Pausing
	if GameState:
		if not GameState.rival_ai_active_changed.is_connected(_on_rival_ai_active_changed):
			GameState.rival_ai_active_changed.connect(_on_rival_ai_active_changed)
		_on_rival_ai_active_changed(GameState.rival_ai_active)
	
	# Delay finding targets slightly to ensure scenes are fully loaded
	await get_tree().process_frame
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
	if is_instance_valid(_target_field) and _target_field.is_in_group("MegaNodes"):
		return
		
	var nodes = get_tree().get_nodes_in_group("MegaNodes")
	for node in nodes:
		if node.resource_type_id == career_behavior.gather_resource_id:
			_target_field = node
			break

func _find_refinery() -> void:
	if is_instance_valid(_target_bench):
		return
		
	var current_settlement = GameState.get_nearest_settlement(self)
	var stations = get_tree().get_nodes_in_group(career_behavior.refine_station_group)
	var public_benches = get_tree().get_nodes_in_group("CraftingBenches")
	
	var best_station = null
	var min_dist = INF
	
	for station in stations:
		if is_instance_valid(station) and station.ownership_type == "NPC" and station.owner_id == "Rival":
			if GameState.get_nearest_settlement(station) == current_settlement:
				var dist = global_position.distance_to(station.global_position)
				if dist < min_dist:
					min_dist = dist
					best_station = station
					
	if not best_station:
		# Search public/fallback stations
		for bench in public_benches:
			if is_accessible_by_rival(bench):
				var dist = global_position.distance_to(bench.global_position)
				if dist < min_dist:
					min_dist = dist
					best_station = bench
					
	_target_bench = best_station

func _find_finished_workshop() -> void:
	if is_instance_valid(_target_finished_bench):
		return
		
	var current_settlement = GameState.get_nearest_settlement(self)
	var stations = get_tree().get_nodes_in_group(career_behavior.finish_station_group)
	var public_benches = get_tree().get_nodes_in_group("CraftingBenches")
	
	var best_station = null
	var min_dist = INF
	
	for station in stations:
		if is_instance_valid(station) and station.ownership_type == "NPC" and station.owner_id == "Rival":
			if GameState.get_nearest_settlement(station) == current_settlement:
				var dist = global_position.distance_to(station.global_position)
				if dist < min_dist:
					min_dist = dist
					best_station = station
					
	if not best_station:
		for bench in public_benches:
			if is_accessible_by_rival(bench):
				var dist = global_position.distance_to(bench.global_position)
				if dist < min_dist:
					min_dist = dist
					best_station = bench
					
	_target_finished_bench = best_station

func _find_stall() -> void:
	if is_instance_valid(_target_stall):
		return
		
	var current_settlement = GameState.get_nearest_settlement(self)
	var stalls = get_tree().get_nodes_in_group("MarketStall")
	var best_stall = null
	var min_dist = INF
	
	for stall in stalls:
		if is_instance_valid(stall) and stall.ownership_type == "NPC" and stall.owner_id == "Rival":
			if GameState.get_nearest_settlement(stall) == current_settlement:
				var dist = global_position.distance_to(stall.global_position)
				if dist < min_dist:
					min_dist = dist
					best_stall = stall
					
	if not best_stall:
		for stall in stalls:
			if is_accessible_by_rival(stall):
				var dist = global_position.distance_to(stall.global_position)
				if dist < min_dist:
					min_dist = dist
					best_stall = stall
					
	_target_stall = best_stall

func _physics_process(delta: float) -> void:
	# Periodic check to buy vacant overworld rental houses
	_house_buy_check_timer -= delta
	if _house_buy_check_timer <= 0.0:
		_house_buy_check_timer = 5.0
		try_buy_available_house()

	# Periodic check to construct buildings or hire workers
	_building_check_timer -= delta * GameState.TIME_SPEED
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
			_find_raw_resource()
			if _target_field:
				if not is_harvesting:
					if _target_field.active_gatherers.size() >= _target_field.max_slots:
						_start_work_state(State.IDLE, randf_range(3.0, 6.0))
						return
					
					var fee = _target_field.get_entry_fee()
					if gold >= fee:
						gold -= fee
						is_harvesting = true
						_spawn_floating_text("Paid Permit: -%d Gold!" % fee)
					else:
						_start_work_state(State.IDLE, randf_range(3.0, 6.0))
						return
				
				_walk_towards_target_node(_target_field, delta)
				var phys_pos = global_position
				if phys_pos.distance_to(_target_field.global_position) < 48.0:
					current_state = State.GATHERING
			else:
				_start_work_state(State.WALKING_TO_REFINERY, 0.1)
				
		State.GATHERING:
			velocity = Vector2.ZERO
			if animated_sprite:
				animated_sprite.play("idle_" + _last_direction)
			move_and_slide()
			
			var lm = get_node_or_null("/root/LogisticsManager")
			if lm and _target_field:
				var amt = lm.get_buffer_amount(self)
				var congestion = _target_field.get_congestion_factor()
				
				if amt >= 3 or (amt > 0 and congestion < 0.55):
					is_harvesting = false
					lm.collect_rival_worker_yield(self)
					lm.erase_buffer(self)
					_target_field._on_body_exited(self)
					_start_work_state(State.WALKING_TO_REFINERY, 0.5)
			else:
				is_harvesting = false
				_start_work_state(State.WALKING_TO_REFINERY, 0.5)
			
		State.WALKING_TO_REFINERY:
			var raw_owned = inventory.get_item_amount(career_behavior.gather_resource_id)
			if raw_owned < 1:
				_start_work_state(State.WALKING_TO_RAW, 0.1)
				return
				
			_find_refinery()
			if _target_bench:
				_walk_towards_target_node(_target_bench, delta)
				var phys_pos = global_position + Vector2(0, -34)
				if phys_pos.distance_to(_target_bench.global_position) < 85.0:
					_start_work_state(State.REFINING, 2.5)
			else:
				_start_work_state(State.WALKING_TO_STALL, 0.1)
				
		State.REFINING:
			var recipe = load(career_behavior.refining_recipe_path)
			if recipe:
				execute_recipe(recipe, career_behavior.gather_resource_id)
			
			if career_behavior.has_finished_product():
				_start_work_state(State.WALKING_TO_FINISHED, 0.5)
			else:
				_start_work_state(State.WALKING_TO_STALL, 0.5)
				
		State.WALKING_TO_FINISHED:
			var refine_output_id = ""
			var refine_recipe = load(career_behavior.refining_recipe_path)
			if refine_recipe:
				refine_output_id = refine_recipe.output_item.id
			
			var ref_owned = inventory.get_item_amount(refine_output_id)
			if ref_owned < 1:
				_start_work_state(State.WALKING_TO_RAW, 0.1)
				return
				
			_find_finished_workshop()
			if _target_finished_bench:
				_walk_towards_target_node(_target_finished_bench, delta)
				var phys_pos = global_position + Vector2(0, -34)
				if phys_pos.distance_to(_target_finished_bench.global_position) < 85.0:
					_start_work_state(State.PRODUCING, 2.5)
			else:
				_start_work_state(State.WALKING_TO_STALL, 0.1)
				
		State.PRODUCING:
			var refine_output_id = ""
			var refine_recipe = load(career_behavior.refining_recipe_path)
			if refine_recipe:
				refine_output_id = refine_recipe.output_item.id
				
			var recipe = load(career_behavior.finished_recipe_path)
			if recipe:
				execute_recipe(recipe, refine_output_id)
			_start_work_state(State.WALKING_TO_STALL, 0.5)
			
		State.WALKING_TO_STALL:
			var sell_owned = inventory.get_item_amount(career_behavior.final_sell_item_id)
			if sell_owned < 1:
				_start_work_state(State.WALKING_TO_RAW, 0.1)
				return
				
			_find_stall()
			if _target_stall:
				_walk_towards_target_node(_target_stall, delta)
				var phys_pos = global_position + Vector2(0, -34)
				if phys_pos.distance_to(_target_stall.global_position) < 85.0:
					_start_work_state(State.SELLING, 2.0)
			else:
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
	var hours = GameState.time_hours
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
		current_schedule = next_sched
		_state_timer = 0.0
		_break_next_state = State.IDLE
		
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
				break

func try_construct_next_building() -> void:
	var current_settlement = GameState.get_nearest_settlement(self)
	if not current_settlement:
		return
		
	# Find first unlocked building path from behavior that isn't already built in this settlement
	for lvl in career_behavior.building_unlocks_by_level:
		if lvl <= level:
			var paths = career_behavior.building_unlocks_by_level[lvl]
			for path in paths:
				var b_data = load(path) as BuildingData
				if not b_data:
					continue
					
				var already_built = false
				var production_groups = ["Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Banks", "Inns", "Taverns", "Farmsteads", "Distilleries", "EventHalls"]
				for grp in production_groups:
					for b_node in get_tree().get_nodes_in_group(grp):
						if is_instance_valid(b_node) and b_node.ownership_type == "NPC" and b_node.owner_id == "Rival":
							var nearest_sett = GameState.get_nearest_settlement(b_node)
							if nearest_sett == current_settlement:
								if b_node.building_data and b_node.building_data.family == b_data.family:
									already_built = true
									break
					if already_built:
						break
						
				if not already_built:
					# Try to build! Find vacant lot
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
							_spawn_floating_text("Rival building %s!" % b_data.name)
							return # Build one at a time

func try_hire_employees() -> void:
	if gold < 500:
		return
		
	var current_settlement = GameState.get_nearest_settlement(self)
	if not current_settlement:
		return
		
	var production_groups = ["Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Banks", "Inns", "Taverns", "Farmsteads", "Distilleries", "EventHalls"]
	for grp in production_groups:
		for b_node in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(b_node) and b_node.ownership_type == "NPC" and b_node.owner_id == "Rival":
				var nearest_sett = GameState.get_nearest_settlement(b_node)
				if nearest_sett == current_settlement:
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
										
									candidate["active_recipe_path"] = recipe_path
									candidate["is_repeating"] = true
									candidate["craft_timer"] = 5.0
									candidate["craft_total_time"] = 5.0
									
									b_node.hired_employees.append(candidate)
									_spawn_floating_text("Rival hired %s!" % candidate.name)
									return

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

