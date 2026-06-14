extends CanvasLayer

signal faded_out
signal faded_in

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_rect: ColorRect = $ColorRect

# Target level state
var _target_scene: String = ""
var _target_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Ignore input events on the black screen and make sure it is transparent
	color_rect.color.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func transition_to_scene(scene_path: String, spawn_position: Vector2) -> void:
	_target_scene = scene_path
	_target_position = spawn_position
	
	# Freeze player input
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("freeze"):
		player.freeze()
		
	# Play fade out
	animation_player.play("fade_to_black")
	await animation_player.animation_finished
	faded_out.emit()
	
	# Change the level
	get_tree().change_scene_to_file(_target_scene)
	
	# Wait for the next frame so nodes in the new level are ready
	await get_tree().process_frame
	
	# Position the player in the new level
	player = get_tree().get_first_node_in_group("Player")
	if player:
		player.global_position = _target_position
		
		# Reset camera position instantly so it doesn't pan across the world
		var camera = player.get_node_or_null("Camera2D")
		if camera and camera is Camera2D:
			camera.reset_smoothing()
			
	# Play fade in
	animation_player.play("fade_to_normal")
	await animation_player.animation_finished
	faded_in.emit()
	
	# Re-enable player input
	if player and player.has_method("unfreeze"):
		player.unfreeze()

func transition_to_next_day() -> void:
	# Freeze player input
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("freeze"):
		player.freeze()
		
	# Play fade out
	animation_player.play("fade_to_black")
	await animation_player.animation_finished
	
	# Advance day and run overnight market ticks
	GameState.advance_day()
	GameState.save_game()
	
	# Delay for sleep simulation
	await get_tree().create_timer(1.0).timeout
	
	# Play fade in
	animation_player.play("fade_to_normal")
	await animation_player.animation_finished
	
	# Re-enable player input
	if player and player.has_method("unfreeze"):
		player.unfreeze()

func transition_teleport(spawn_position: Vector2) -> void:
	# Freeze player input
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("freeze"):
		player.freeze()
		
	# Play fade out
	animation_player.play("fade_to_black")
	await animation_player.animation_finished
	faded_out.emit()
	
	# Reposition player
	if player:
		player.global_position = spawn_position
		
		# Reset camera position instantly so it doesn't pan across the world
		var camera = player.get_node_or_null("Camera2D")
		if camera and camera is Camera2D:
			camera.reset_smoothing()
			
	# Play fade in
	animation_player.play("fade_to_normal")
	await animation_player.animation_finished
	faded_in.emit()
	
	# Re-enable player input
	if player and player.has_method("unfreeze"):
		player.unfreeze()

