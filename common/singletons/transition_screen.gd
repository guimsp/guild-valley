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
	if player and _target_position != Vector2(1550, 500):
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
	TimeManager.advance_day()
	SaveLoadManager.save_game()
	
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


func transition_to_interior(room_node: Node, spawn_position: Vector2) -> void:
	# Freeze player input
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("freeze"):
		player.freeze()
		
	# Fade to black (0.15s)
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, 0.15)
	await tween.finished
	faded_out.emit()
	
	# Reposition player
	if player:
		player.global_position = spawn_position
		
		# Reset camera position instantly and lock camera limits
		var camera = player.get_node_or_null("Camera2D")
		if camera and camera is Camera2D:
			var rect: Rect2
			if room_node is Control:
				rect = room_node.get_global_rect()
			elif room_node.has_node("Floor") and room_node.get_node("Floor") is Control:
				rect = room_node.get_node("Floor").get_global_rect()
			else:
				# Fallback: estimate interior size centered at the room's position
				var room_pos = Vector2.ZERO
				if "global_position" in room_node:
					room_pos = room_node.global_position
				rect = Rect2(room_pos - Vector2(250, 200), Vector2(500, 400))
				
			camera.limit_left = int(rect.position.x)
			camera.limit_right = int(rect.end.x)
			camera.limit_top = int(rect.position.y)
			camera.limit_bottom = int(rect.end.y)
			camera.reset_smoothing()
			
	# Fade to transparent (0.15s)
	var tween_in = create_tween()
	tween_in.tween_property(color_rect, "color:a", 0.0, 0.15)
	await tween_in.finished
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faded_in.emit()
	
	# Re-enable player input
	if player and player.has_method("unfreeze"):
		player.unfreeze()


func transition_exit_interior(spawn_position: Vector2) -> void:
	# Freeze player input
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("freeze"):
		player.freeze()
		
	# Fade to black (0.15s)
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, 0.15)
	await tween.finished
	faded_out.emit()
	
	# Reposition player
	if player:
		player.global_position = spawn_position
		
		# Reset camera position instantly and restore camera limits to default (large bounds)
		var camera = player.get_node_or_null("Camera2D")
		if camera and camera is Camera2D:
			camera.limit_left = -10000000
			camera.limit_right = 10000000
			camera.limit_top = -10000000
			camera.limit_bottom = 10000000
			camera.reset_smoothing()
			
	# Fade to transparent (0.15s)
	var tween_in = create_tween()
	tween_in.tween_property(color_rect, "color:a", 0.0, 0.15)
	await tween_in.finished
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faded_in.emit()
	
	# Re-enable player input
	if player and player.has_method("unfreeze"):
		player.unfreeze()

