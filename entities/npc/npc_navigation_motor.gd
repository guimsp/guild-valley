# ==============================================================================
# ARCHITECTURAL SETTINGS EXPLANATION & EDITOR SETUP GUIDE FOR 2D ROAD PREFERENCE:
# ==============================================================================
# Godot 4's NavigationServer2D uses a cost-based pathfinding algorithm (AStar internally).
# To configure road preferences and avoidance in the editor:
#
# 1. Base World Ground (Grass) Setup:
#    - Create a NavigationRegion2D covering your entire background/walkable map bounds.
#    - Edit the NavigationRegion2D properties:
#      * Set the "Travel Cost" and "Enter Cost" to 2.0.
#      * This makes stepping onto or traversing the generic grass expensive for pathfinding.
#
# 2. Road Network & Plazas Setup:
#    - Create separate NavigationRegion2D nodes for road segments and plaza tiles.
#    - Edit their NavigationRegion2D properties:
#      * Set the "Travel Cost" and "Enter Cost" to 0.5.
#      * Pathfinding will strongly prioritize these regions when looking for the shortest route.
#
# 3. Dynamic Obstacle Avoidance (NavigationObstacle2D & RVO):
#    - Enable 'avoidance_enabled = true' on the 'NavigationAgent2D' node.
#    - Connect to the 'velocity_computed' signal. Movement must be handled inside the callback
#      using the calculated safe_velocity to steer fluidly around obstacles.
# ==============================================================================

class_name NPCNavigationMotor
extends Node

@export var speed: float = 50.0

var parent_body: CharacterBody2D = null
var nav_agent: NavigationAgent2D = null
var path_line: Line2D = null

# Target throttling variables
var last_target_position: Vector2 = Vector2.ZERO
var target_update_cooldown: float = 0.0
const UPDATE_INTERVAL: float = 0.3
var path_pending: bool = false

# Recovery variables
var recovery_timer: float = 0.0
var recovery_velocity: Vector2 = Vector2.ZERO

# Stuck detection variables
var last_stuck_position: Vector2 = Vector2.ZERO
var stuck_timer: float = 0.0
const STUCK_SPEED_THRESHOLD: float = 5.0
const STUCK_TIME_THRESHOLD: float = 2.0  # Allowed time for engine RVO to resolve bottlenecks naturally

func _ready() -> void:
	parent_body = get_parent() as CharacterBody2D
	if not parent_body:
		push_error("NPCNavigationMotor must be a child of CharacterBody2D!")
		return
		
	# Find or create NavigationAgent2D child
	nav_agent = parent_body.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if not nav_agent:
		nav_agent = NavigationAgent2D.new()
		nav_agent.name = "NavigationAgent2D"
		parent_body.add_child(nav_agent)
		
	# Configure NavAgent settings
	nav_agent.path_desired_distance = 16.0
	nav_agent.target_desired_distance = 16.0
	nav_agent.avoidance_enabled = false
	nav_agent.neighbor_distance = 150.0
	nav_agent.max_neighbors = 10
		
	# Dynamically instantiate a top-level Line2D child for path drawing (uses global coordinates)
	path_line = Line2D.new()
	path_line.name = "PathLineRenderer"
	path_line.width = 1.5
	path_line.default_color = Color(1.0, 0.9, 0.2, 0.4) # Semi-transparent yellow
	path_line.top_level = true
	add_child(path_line)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(parent_body) or not is_instance_valid(nav_agent):
		return
		
	# Check if the parent NPC should be stationary
	var is_waiting = false
	if "is_talking" in parent_body and parent_body.is_talking:
		is_waiting = true
	elif "is_frozen" in parent_body and parent_body.is_frozen:
		is_waiting = true
	elif "wait_timer" in parent_body and parent_body.wait_timer > 0.0:
		is_waiting = true
	elif "limbo_timer" in parent_body and parent_body.limbo_timer > 0.0:
		is_waiting = true
	elif "worker_state" in parent_body and (parent_body.worker_state == "gathering_at_node" or parent_body.worker_state == "producing_goods"):
		is_waiting = true
	elif "npc_type" in parent_body and parent_body.npc_type == 3: # TYPE_STATIC
		is_waiting = true
	
	if not is_waiting and is_instance_valid(parent_body) and parent_body.get("active_commercial_route") != null:
		var pm = get_node_or_null("/root/PoliticsManager")
		if pm:
			var npc_prov = parent_body.get("province")
			if npc_prov == "Unknown Province" or npc_prov == "":
				npc_prov = GameState.get_province_of_node(parent_body) if GameState else ""
			if pm.is_law_active("courier_curfew", npc_prov):
				var is_night = TimeManager.time_hours >= 20 or TimeManager.time_hours < 6 if GameState else false
				if is_night:
					is_waiting = true
		
	if is_waiting:
		parent_body.velocity = Vector2.ZERO
		if parent_body.has_method("update_animation"):
			parent_body.update_animation(Vector2.ZERO)
		_update_path_line()
		return
		
	# 1. Emergency Fallback Steering override
	if recovery_timer > 0.0:
		recovery_timer -= delta
		parent_body.velocity = recovery_velocity
		parent_body.move_and_slide()
		if parent_body.has_method("update_animation"):
			parent_body.update_animation(parent_body.velocity)
		
		# Reset stuck parameters during active recovery steering
		stuck_timer = 0.0
		last_stuck_position = parent_body.global_position
		_update_path_line()
		return
		
	if target_update_cooldown > 0.0:
		target_update_cooldown -= delta
		
	# 2. Wait for path mesh synchronization frame
	if path_pending:
		path_pending = false
		parent_body.velocity = Vector2.ZERO
		if parent_body.has_method("update_animation"):
			parent_body.update_animation(Vector2.ZERO)
		_update_path_line()
		return
		
	if nav_agent.is_navigation_finished():
		parent_body.velocity = Vector2.ZERO
		if parent_body.has_method("update_animation"):
			parent_body.update_animation(Vector2.ZERO)
		_update_path_line()
		return
		
	var next_path_pos = nav_agent.get_next_path_position()
	var current_pos = parent_body.global_position
	
	# Compute direction and intended movement velocity
	var dir = current_pos.direction_to(next_path_pos)
	var speed_multiplier = parent_body.get("speed_multiplier") if "speed_multiplier" in parent_body else 1.0
	var base_speed = parent_body.get("speed") if "speed" in parent_body else speed
	parent_body.velocity = dir * base_speed * speed_multiplier
	parent_body.move_and_slide()
	if parent_body.has_method("update_animation"):
		parent_body.update_animation(parent_body.velocity)
		
	_update_path_line()
	
	# Stuck detection logic
	_check_stuck_failsafe(delta)

func move_to_target(target_position: Vector2, force: bool = false) -> void:
	if not is_instance_valid(nav_agent):
		return
		
	# Resolve the target position to the closest walkable point on the navmesh to prevent unreachable voids
	var walkable_target = target_position
	var map_rid = nav_agent.get_navigation_map()
	if map_rid.is_valid():
		walkable_target = NavigationServer2D.map_get_closest_point(map_rid, target_position)
		
	# Check if the target shifted and update cooldown has expired
	var target_shifted_significantly = walkable_target.distance_to(last_target_position) > 16.0
	if walkable_target.distance_to(last_target_position) > 2.0:
		if force or target_shifted_significantly or target_update_cooldown <= 0.0:
			nav_agent.target_position = walkable_target
			last_target_position = walkable_target
			target_update_cooldown = UPDATE_INTERVAL
			stuck_timer = 0.0
			last_stuck_position = parent_body.global_position
			path_pending = true

func _check_stuck_failsafe(delta: float) -> void:
	if not is_instance_valid(parent_body) or not is_instance_valid(nav_agent):
		return
		
	var current_pos = parent_body.global_position
	var dist_moved = current_pos.distance_to(last_stuck_position)
	var speed_achieved = dist_moved / delta if delta > 0.0 else 0.0
	
	# If speed is below threshold while moving
	if speed_achieved < STUCK_SPEED_THRESHOLD:
		stuck_timer += delta
		if stuck_timer >= STUCK_TIME_THRESHOLD:
			stuck_timer = 0.0
			# Trigger stuck bypass recovery
			_bypass_obstacle()
	else:
		stuck_timer = 0.0
		last_stuck_position = current_pos

func _bypass_obstacle() -> void:
	if not is_instance_valid(nav_agent):
		return
		
	# Check if parent is going to a stall and is close enough for a force-transaction bypass
	if parent_body and parent_body.get("current_state") == NPCAIController.State.TRAVEL:
		var target_stall = parent_body.get("target_stall")
		var return_home = parent_body.get("return_home_requested")
		if not return_home and is_instance_valid(target_stall):
			var target_pos = target_stall.global_position
			if target_stall.has_method("get_interaction_position"):
				target_pos = target_stall.get_interaction_position()
			var dist = parent_body.global_position.distance_to(target_pos)
			if dist <= 40.0:
				print("[NPCNavigationMotor] NPC %s stuck close to stall doorstep (dist: %.1f). Force-transacting!" % [parent_body.get("npc_name"), dist])
				parent_body.set("current_state", NPCAIController.State.TRANSACT)
				nav_agent.target_position = parent_body.global_position
				path_pending = true
				return
		
	# Choose a recovery direction perpendicular to current heading + some random noise
	var current_dir = parent_body.velocity.normalized()
	if current_dir == Vector2.ZERO:
		current_dir = Vector2.DOWN
	var angle = (PI / 2.0) if randf() < 0.5 else (-PI / 2.0)
	var recovery_dir = current_dir.rotated(angle + randf_range(-0.5, 0.5)).normalized()
	
	var base_speed = parent_body.get("speed") if "speed" in parent_body else speed
	var speed_multiplier = parent_body.get("speed_multiplier") if "speed_multiplier" in parent_body else 1.0
	
	recovery_velocity = recovery_dir * base_speed * speed_multiplier * 1.2
	recovery_timer = 0.8
		
	# Recalculate path by applying a slight offset to the current path destination
	var offset = Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0))
	var recovery_target = last_target_position + offset
	nav_agent.target_position = recovery_target
	# Ensure the cooldown allows immediate recalculation for this bypass
	target_update_cooldown = 0.0
	path_pending = true
	var name_str = parent_body.get("npc_name") if parent_body.get("npc_name") != "" else parent_body.name
	print("[NPCNavigationMotor] NPC %s detected stuck! Initiating 0.8s perpendicular recovery push: %s" % [name_str, recovery_velocity])

func _update_path_line() -> void:
	if not is_instance_valid(path_line):
		return
		
	var show_lines = true
	var econ_mgr = get_node_or_null("/root/EconomyManager")
	if econ_mgr:
		show_lines = econ_mgr.show_debug_emotes
		
	if show_lines and is_instance_valid(nav_agent) and not nav_agent.is_navigation_finished() and recovery_timer <= 0.0:
		path_line.points = nav_agent.get_current_navigation_path()
	else:
		path_line.clear_points()

func teleport_to(target_pos: Vector2) -> void:
	if is_instance_valid(parent_body):
		parent_body.global_position = target_pos
		parent_body.velocity = Vector2.ZERO
	if is_instance_valid(nav_agent):
		nav_agent.target_position = target_pos
		# Clear target history to avoid stale path calculations
		last_target_position = target_pos
		path_pending = true
		stuck_timer = 0.0
	recovery_timer = 0.0
