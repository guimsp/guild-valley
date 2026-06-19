class_name GatheringWorker
extends CharacterBody2D

@export var speed: float = 80.0
@export var worker_name: String = "Worker"
@export var owner_id: String = "Player" # "Player" or "Rival"
@export var productivity: float = 1.0

var target_mega_node: Area2D = null
var home_workshop: Node2D = null
var is_returning: bool = false
var is_gathering: bool = false
var current_mega_node: Area2D = null
var is_shift_worker: bool = false
var shift_timer: float = 120.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var _last_direction: String = "south"

func _ready() -> void:
	add_to_group("GatheringWorkers")
	
	collision_layer = 8
	collision_mask = 0
	
	# Setup visual modulating tint
	if animated_sprite:
		if owner_id == "Player":
			animated_sprite.modulate = Color(0.6, 1.0, 0.6) # Greenish
		else:
			animated_sprite.modulate = Color(1.0, 0.6, 0.6) # Reddish
			
	if not nav_agent:
		nav_agent = NavigationAgent2D.new()
		nav_agent.path_desired_distance = 16.0
		nav_agent.target_desired_distance = 16.0
		add_child(nav_agent)
		
	var pm = get_node_or_null("/root/PoliticsManager")
	if pm:
		pm.law_changed.connect(_on_law_changed)

func _on_law_changed(prov: String, law_id: String, is_active: bool) -> void:
	if not is_active:
		return
	var my_prov = GameState.get_province_of_node(self) if GameState else ""
	if my_prov != prov:
		return
		
	if is_instance_valid(target_mega_node):
		var res_id = target_mega_node.resource_type_id
		if law_id == "crown_forestry_protection" and res_id == "standard_timber":
			_trigger_strike("Forestry Protection")
		elif law_id == "noble_game_preservation" and res_id == "venison":
			_trigger_strike("Game Preservation")

func _trigger_strike(reason: String = "Law Banned") -> void:
	is_gathering = false
	is_returning = true
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
	if hud and hud.has_method("_spawn_floating_text"):
		hud._spawn_floating_text("%s: On Strike! (%s)" % [worker_name, reason], global_position)
	if is_instance_valid(target_mega_node):
		target_mega_node._on_body_exited(self)

func _physics_process(delta: float) -> void:
	if not is_returning and is_instance_valid(target_mega_node):
		var pm = get_node_or_null("/root/PoliticsManager")
		var my_prov = GameState.get_province_of_node(self) if GameState else ""
		if pm and my_prov != "":
			var res_id = target_mega_node.resource_type_id
			var is_illegal = false
			if pm.is_law_active("crown_forestry_protection", my_prov) and res_id == "standard_timber":
				is_illegal = true
			elif pm.is_law_active("noble_game_preservation", my_prov) and res_id == "venison":
				is_illegal = true
				
			if is_illegal:
				_trigger_strike("Illegal Resource")
				return

	if is_gathering:
		velocity = Vector2.ZERO
		if animated_sprite:
			animated_sprite.play("idle_" + _last_direction)
		move_and_slide()
		
		if is_shift_worker:
			shift_timer -= delta
			if shift_timer <= 0.0:
				is_gathering = false
				is_returning = true
				if is_instance_valid(target_mega_node):
					target_mega_node._on_body_exited(self)
		return
		
	var target_pos = Vector2.ZERO
	if is_returning:
		if is_instance_valid(home_workshop):
			target_pos = home_workshop.global_position
		else:
			target_pos = GameState.get_nearest_settlement(self).global_position
			
		if global_position.distance_to(target_pos) < 32.0:
			# Arrived home: deposit and despawn safely
			if is_shift_worker and is_instance_valid(home_workshop):
				var target_storage = home_workshop.get("building_storage")
				if target_storage:
					var econ_mgr = get_node_or_null("/root/EconomyManager")
					var res_id = target_mega_node.resource_type_id if target_mega_node else "wheat"
					var item_res = econ_mgr.item_database.get(res_id) if econ_mgr else null
					if item_res:
						target_storage.add_item(item_res, 20)
						var hud = get_tree().get_first_node_in_group("PlayerHUD")
						if hud and hud.has_method("_spawn_floating_text"):
							hud._spawn_floating_text("Deposited 20 %s!" % item_res.name, global_position)
			else:
				var lm = get_node_or_null("/root/LogisticsManager")
				if lm:
					if owner_id == "Player":
						lm.collect_worker_yield(self)
					else:
						lm.collect_rival_worker_yield(self)
					lm.erase_buffer(self)
			queue_free()
			return
	else:
		if is_instance_valid(target_mega_node):
			target_pos = target_mega_node.global_position
		else:
			is_returning = true
			return
			
	nav_agent.target_position = target_pos
	
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		if animated_sprite:
			animated_sprite.play("idle_" + _last_direction)
		move_and_slide()
		return
		
	var next_path_pos = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_path_pos)
	velocity = dir * speed
	
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

func on_mega_node_full(_node: Area2D) -> void:
	is_returning = true

func recall() -> void:
	is_gathering = false
	is_returning = true
	# Exiting Area2D will naturally trigger _on_body_exited on the MegaNode and stop the gathering state.

func _exit_tree() -> void:
	var lm = get_node_or_null("/root/LogisticsManager")
	if lm:
		lm.erase_buffer(self)

