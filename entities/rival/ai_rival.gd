class_name AIRival
extends CharacterBody2D

@export var speed: float = 80.0
@export var gold: int = 100

var active_roads_count: int = 0
var speed_multiplier: float = 1.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var inventory: Node = $InventoryComponent

enum State {
	IDLE,
	WALKING_TO_FIELD,
	GATHERING,
	WALKING_TO_BENCH,
	CRAFTING,
	WALKING_TO_STALL,
	SELLING
}

var current_state: State = State.WALKING_TO_FIELD
var current_schedule: String = "work" # "sleep", "morning", "work", "lunch", "evening"

var _last_direction: String = "south"
var _state_timer: float = 0.0
var _break_next_state: State = State.IDLE

# Target nodes in the world
var _target_field: Node2D = null
var _target_bench: Node2D = null
var _target_stall: Node2D = null

# Waypoints path queue
var _path_queue: Array[Vector2] = []
var _wander_target: Vector2 = Vector2.ZERO
var _wander_wait_timer: float = 0.0
var _house_buy_check_timer: float = 5.0

# Item Resources
var wheat_res: ItemData
var flour_res: ItemData
var _spawn_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	_spawn_position = global_position
	# Add rival to group
	add_to_group("Rivals")
	
	# Load item resources
	wheat_res = load("res://common/items/instances/wheat.tres")
	flour_res = load("res://common/items/instances/flour.tres")
	
	# Tint sprite to distinguish from player (e.g. reddish tint)
	if animated_sprite:
		animated_sprite.modulate = Color(1.0, 0.6, 0.6)
		
	# Delay finding targets slightly to ensure scenes are fully loaded
	await get_tree().process_frame
	_find_targets()

func is_accessible_by_rival(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	var target = node
	var grid = _get_grid_for_crop(node)
	if grid:
		target = grid
		
	if "ownership_type" in target:
		return target.ownership_type == "Public" or target.ownership_type == "NPC"
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

func _find_targets() -> void:
	# Find wheat field (prefer a grown one and check accessibility)
	var fields = get_tree().get_nodes_in_group("WheatFields")
	_target_field = null
	for field in fields:
		if field is WheatField and field.is_grown and is_accessible_by_rival(field):
			_target_field = field
			break
	if not _target_field:
		for field in fields:
			if is_accessible_by_rival(field):
				_target_field = field
				break
		
	# Find crafting bench (check accessibility)
	var benches = get_tree().get_nodes_in_group("CraftingBenches")
	_target_bench = null
	for bench in benches:
		if is_accessible_by_rival(bench):
			_target_bench = bench
			break
		
	# Find market stall (check accessibility)
	var stalls = get_tree().get_nodes_in_group("MarketStall")
	_target_stall = null
	for stall in stalls:
		if is_accessible_by_rival(stall):
			_target_stall = stall
			break

func _physics_process(delta: float) -> void:
	# Periodic check to buy vacant overworld rental houses
	_house_buy_check_timer -= delta
	if _house_buy_check_timer <= 0.0:
		_house_buy_check_timer = 5.0
		try_buy_available_house()

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
		
	# Ensure targets exist
	if not is_instance_valid(_target_field) or not is_instance_valid(_target_bench) or not is_instance_valid(_target_stall):
		if not is_instance_valid(_target_field): _target_field = null
		if not is_instance_valid(_target_bench): _target_bench = null
		if not is_instance_valid(_target_stall): _target_stall = null
		_find_targets()

	# 3. Execute schedule behavior
	match current_schedule:
		"sleep":
			# Idle at home
			velocity = Vector2.ZERO
			if animated_sprite:
				animated_sprite.play("idle_" + _last_direction)
			move_and_slide()
			
		"lunch":
			# Idle in front of market stall
			var target = _target_stall.global_position + Vector2(0, 50) if _target_stall else _spawn_position
			if global_position.distance_to(target) > 20.0:
				_walk_towards(target, delta)
			else:
				velocity = Vector2.ZERO
				if animated_sprite:
					animated_sprite.play("idle_" + _last_direction)
				move_and_slide()
				
		"morning":
			# Wander slowly near spawn
			_process_wandering(_spawn_position, 100.0, delta)
			
		"evening":
			# Wander near spawn (slightly offset)
			_process_wandering(_spawn_position + Vector2(0, 50), 80.0, delta)
			
		"work":
			# Execute active production loop state machine
			_process_work_state(delta)

# Active work production state loop
func _process_work_state(delta: float) -> void:
	match current_state:
		State.WALKING_TO_FIELD:
			if _target_field:
				_walk_along_path(_target_field.global_position, delta, _target_field)
				var phys_pos = global_position + Vector2(0, -34)
				if phys_pos.distance_to(_target_field.global_position) < 38.0:
					_start_work_state(State.GATHERING, 2.0)
			else:
				_start_work_state(State.WALKING_TO_BENCH, 0.1)
				
		State.GATHERING:
			if _target_field:
				var field = _target_field as WheatField
				if field.is_grown:
					field.is_grown = false
					field._update_visuals()
					field.spawn_floating_text("Rival harvested!")
					inventory.add_item(wheat_res, 3)
				else:
					field.spawn_floating_text("Rival found no wheat...")
			_start_work_state(State.WALKING_TO_BENCH, 0.5)
			
		State.WALKING_TO_BENCH:
			if _target_bench:
				_walk_along_path(_target_bench.global_position, delta, _target_bench)
				var phys_pos = global_position + Vector2(0, -34)
				if phys_pos.distance_to(_target_bench.global_position) < 52.0:
					_start_work_state(State.CRAFTING, 2.5)
			else:
				_start_work_state(State.WALKING_TO_STALL, 0.1)
				
		State.CRAFTING:
			var wheat_owned = inventory.get_item_amount("wheat")
			if wheat_owned >= 3:
				inventory.remove_item("wheat", 3)
				inventory.add_item(flour_res, 1)
				_spawn_floating_text("Rival crafted Flour!")
			_start_work_state(State.WALKING_TO_STALL, 0.5)
			
		State.WALKING_TO_STALL:
			if _target_stall:
				_walk_along_path(_target_stall.global_position, delta, _target_stall)
				var phys_pos = global_position + Vector2(0, -34)
				if phys_pos.distance_to(_target_stall.global_position) < 58.0:
					_start_work_state(State.SELLING, 2.0)
			else:
				_start_work_state(State.WALKING_TO_FIELD, 0.1)
				
		State.SELLING:
			var flour_owned = inventory.get_item_amount("flour")
			if flour_owned > 0 and _target_stall:
				var stall = _target_stall as MarketStall
				stall.inventory.add_item(flour_res, flour_owned)
				inventory.remove_item("flour", flour_owned)
				
				var price = stall.get_sell_price(flour_res) * flour_owned
				gold += price
				_spawn_floating_text("Rival sold Flour for %d Gold!" % price)
			_start_work_state(State.WALKING_TO_FIELD, 2.0)

# Handles routing along path queue and obstacle avoidance
func _walk_along_path(target_pos: Vector2, delta: float, target_node: CollisionObject2D = null) -> void:
	if _path_queue.is_empty():
		_generate_path(target_pos, target_node)
		
	if not _path_queue.is_empty():
		var next_point = _path_queue[0]
		_walk_towards(next_point, delta)
		if global_position.distance_to(next_point) < 16.0:
			_path_queue.remove_at(0)
	else:
		_walk_towards(target_pos, delta)

# Pathfind via Raycast + Waypoint intersections
func _generate_path(destination: Vector2, target_node: CollisionObject2D = null) -> void:
	_path_queue.clear()
	
	# If direct path is not blocked, walk straight
	if not is_path_blocked(global_position, destination, target_node):
		_path_queue.append(destination)
		return
		
	# Find waypoints in scene
	var waypoints = get_tree().get_nodes_in_group("Waypoints")
	if waypoints.is_empty():
		_path_queue.append(destination)
		return
		
	# 1. Search for a waypoint that can clear both sides
	var best_waypoint: Node2D = null
	var min_dist = INF
	
	for wp in waypoints:
		var wp_node = wp as Node2D
		if not wp_node:
			continue
		var wp_pos = wp_node.global_position
		
		# Direct line of sight checks
		if not is_path_blocked(global_position, wp_pos, null) and not is_path_blocked(wp_pos, destination, target_node):
			var dist = global_position.distance_to(wp_pos) + wp_pos.distance_to(destination)
			if dist < min_dist:
				min_dist = dist
				best_waypoint = wp_node
				
	if best_waypoint:
		_path_queue.append(best_waypoint.global_position)
		_path_queue.append(destination)
		return
		
	# 2. Fallback: Find closest visible waypoint
	var closest_wp: Node2D = null
	var closest_dist = INF
	for wp in waypoints:
		var wp_node = wp as Node2D
		if not wp_node:
			continue
		var wp_pos = wp_node.global_position
		if not is_path_blocked(global_position, wp_pos):
			var dist = global_position.distance_to(wp_pos)
			if dist < closest_dist:
				closest_dist = dist
				closest_wp = wp_node
				
	if closest_wp:
		_path_queue.append(closest_wp.global_position)
		_path_queue.append(destination)
	else:
		_path_queue.append(destination)

# Checks for solid physics obstructions using raycasts
func is_path_blocked(from: Vector2, to: Vector2, target_node: CollisionObject2D = null) -> bool:
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return false
		
	var query = PhysicsRayQueryParameters2D.create(from, to)
	
	# Exclude self and player
	var exclude_rids = [get_rid()]
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		exclude_rids.append(player.get_rid())
		
	# Exclude target node if provided
	if target_node:
		exclude_rids.append(target_node.get_rid())
		
	# Also ignore any workstation the AI is currently standing next to (starting node)
	var workstations = []
	workstations.append_array(get_tree().get_nodes_in_group("WheatFields"))
	workstations.append_array(get_tree().get_nodes_in_group("CraftingBenches"))
	workstations.append_array(get_tree().get_nodes_in_group("MarketStall"))
	
	var phys_pos = global_position + Vector2(0, -34)
	for ws in workstations:
		if ws is CollisionObject2D:
			if phys_pos.distance_to(ws.global_position) < 75.0:
				exclude_rids.append(ws.get_rid())
				
	query.exclude = exclude_rids
	var result = space_state.intersect_ray(query)
	return result.size() > 0

# Updates active state with a 40% chance of a slacking break
func _start_work_state(new_state: State, duration: float) -> void:
	current_state = new_state
	_state_timer = duration
	_path_queue.clear()
	
	# Chance of break
	if new_state in [State.WALKING_TO_FIELD, State.WALKING_TO_BENCH, State.WALKING_TO_STALL]:
		if randf() < 0.40:
			_break_next_state = new_state
			current_state = State.IDLE
			_state_timer = randf_range(3.0, 6.0)
			_spawn_floating_text("Rival resting...")

# Route pathing based on active work state
func _route_to_state_target() -> void:
	_find_targets() # Find target dynamically before routing
	match current_state:
		State.WALKING_TO_FIELD:
			if _target_field:
				_generate_path(_target_field.global_position, _target_field)
		State.WALKING_TO_BENCH:
			if _target_bench:
				_generate_path(_target_bench.global_position, _target_bench)
		State.WALKING_TO_STALL:
			if _target_stall:
				_generate_path(_target_stall.global_position, _target_stall)

# Dynamic Schedule Controller
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
		_path_queue.clear()
		_state_timer = 0.0
		_break_next_state = State.IDLE
		
		match current_schedule:
			"sleep":
				current_state = State.IDLE
			"morning":
				_wander_target = global_position
				_wander_wait_timer = 0.0
			"lunch":
				var target = _target_stall.global_position + Vector2(0, 50) if _target_stall else _spawn_position
				_generate_path(target, _target_stall)
			"evening":
				_wander_target = global_position
				_wander_wait_timer = 0.0
			"work":
				current_state = State.WALKING_TO_FIELD
				_route_to_state_target()

# Processes random wandering in a zone
func _process_wandering(center: Vector2, radius: float, delta: float) -> void:
	if _wander_wait_timer > 0.0:
		_wander_wait_timer -= delta
		velocity = Vector2.ZERO
		if animated_sprite:
			animated_sprite.play("idle_" + _last_direction)
		move_and_slide()
		return
		
	if global_position.distance_to(_wander_target) < 15.0 or _wander_target == Vector2.ZERO:
		# Choose a new target
		var angle = randf() * TAU
		var dist = randf() * radius
		_wander_target = center + Vector2(cos(angle), sin(angle)) * dist
		_wander_wait_timer = randf_range(2.0, 5.0)
	else:
		_walk_towards(_wander_target, delta)

# Base movement towards a vector coord
func _walk_towards(target_pos: Vector2, _delta: float) -> void:
	var dir = global_position.direction_to(target_pos)
	velocity = dir * speed * speed_multiplier
	
	if velocity != Vector2.ZERO:
		_last_direction = _get_cardinal_direction(velocity)
		if animated_sprite:
			animated_sprite.play("walk_" + _last_direction)
	else:
		if animated_sprite:
			animated_sprite.play("idle_" + _last_direction)
			
	move_and_slide()

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
			var cost = house.buy_cost * 3
			if gold >= cost:
				gold -= cost
				house.ownership_type = "NPC"
				house.owner_id = "Rival"
				house._update_door_state()
				_spawn_floating_text("Rival bought house for %d G!" % cost)
				break
