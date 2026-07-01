extends Area2D

@export var target_province: String = "Oakhaven Province"
@export var toll_cost: int = 15
@export var guard_name: String = "City Guard"
@export var push_direction: Vector2 = Vector2.ZERO # If zero, defaults to opposite of player's facing direction

var _last_toll_time: float = 0.0
var _active_player: CharacterBody2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player") or not (body is CharacterBody2D):
		return
		
	# Check if player starting province matches target, or if they have a license
	var starting_prov = ProvinceMasterData.get_player_starting_province()
	if target_province == starting_prov or ProvinceMasterData.has_province_license(target_province):
		return
		
	# Check cooldown to prevent duplicate triggers
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _last_toll_time < 3.0:
		return
		
	_active_player = body
	_trigger_toll()

func _trigger_toll() -> void:
	_active_player.freeze()
	
	var lines = [
		"Halt! You are entering %s." % target_province,
		"Non-residents must pay a checkpoint toll of %d Gold to pass." % toll_cost,
		"Or you can purchase a local operating license at the City Hall to bypass all tolls and operate in this province."
	]
	
	GameState.show_npc_dialogue(self, guard_name, lines, func():
		var bubble_scene = load("res://UI/npc_dialogue_bubble.tscn")
		if not bubble_scene:
			_active_player.unfreeze()
			return
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
				
			bubble.start_dialogue(self, guard_name, ["How do you wish to proceed?"], func():
				pass
			)
			
			var choices = ["Pay %d Gold" % toll_cost, "Turn Back"]
			bubble.show_choices(choices, func(choice_idx):
				bubble._on_close_pressed()
				if choice_idx == 0:
					if GameState.gold >= toll_cost:
						GameState.gold -= toll_cost
						_last_toll_time = Time.get_ticks_msec() / 1000.0
						GameState.show_npc_dialogue(self, guard_name, ["You may pass. Welcome to %s." % target_province], func():
							_active_player.unfreeze()
						)
					else:
						GameState.show_npc_dialogue(self, guard_name, ["You cannot afford the toll! Stand back."], func():
							_push_player_back(_active_player)
						)
				else:
					_push_player_back(_active_player)
			)
	)

func _push_player_back(player: CharacterBody2D) -> void:
	# Temporarily lift the input freeze, but disable player's physics processing to prevent fighting
	player.unfreeze()
	player.set_physics_process(false)
	
	# Determine push direction
	var dir = push_direction.normalized()
	if dir == Vector2.ZERO:
		var last_dir = player.get("_last_direction") if player.get("_last_direction") != null else "south"
		match last_dir:
			"north": dir = Vector2.DOWN
			"south": dir = Vector2.UP
			"east": dir = Vector2.LEFT
			"west": dir = Vector2.RIGHT
			_: dir = Vector2.DOWN
			
	var target_pos = player.global_position + dir * 80.0
	
	var tween = create_tween()
	tween.tween_property(player, "global_position", target_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	# Verify player is completely outside the Area2D boundary before restoring control
	while overlaps_body(player):
		player.global_position += dir * 16.0
		await get_tree().physics_frame
		
	# Restore control
	player.set_physics_process(true)
