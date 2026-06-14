class_name Player
extends CharacterBody2D

# Movement speed exported to the inspector
@export var speed: float = 150.0

var active_roads_count: int = 0
var speed_multiplier: float = 1.0

# Reference to the AnimatedSprite2D child node
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Keep track of the last faced direction to play the correct idle animation.
# Default to "south" (facing forward) as a standard game starting orientation.
var _last_direction: String = "south"

# State flags
var is_frozen: bool = false

# List of interactable objects in range
var interactables_in_range: Array = []
signal interactables_changed

func _ready() -> void:
	# Add the player to a global group so other systems can find it
	add_to_group("Player")

func register_interactable(interactable: Node) -> void:
	if not interactables_in_range.has(interactable):
		interactables_in_range.append(interactable)
		interactables_changed.emit()

func unregister_interactable(interactable: Node) -> void:
	if interactables_in_range.has(interactable):
		interactables_in_range.erase(interactable)
		interactables_changed.emit()

func get_facing_interactables() -> Array:
	var facing = []
	for obj in interactables_in_range:
		if is_instance_valid(obj):
			var diff = obj.global_position - global_position
			var obj_dir = ""
			if abs(diff.x) > abs(diff.y):
				obj_dir = "east" if diff.x > 0 else "west"
			else:
				obj_dir = "south" if diff.y > 0 else "north"
			if obj_dir == _last_direction:
				facing.append(obj)
	facing.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	return facing

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

func interact_with_object() -> void:
	var facing = get_facing_interactables()
	if facing.size() > 0:
		var interactable = facing[0]
		var check_node = interactable
		var grid = _get_grid_for_crop(interactable)
		if grid:
			check_node = grid
		
		if "ownership_type" in check_node and check_node.ownership_type == "NPC":
			spawn_floating_text("Locked: NPC Owned!")
			return
			
		if interactable.has_method("interact"):
			interactable.interact(self)


func _unhandled_input(event: InputEvent) -> void:
	if is_frozen:
		return
	if event.is_action_pressed("interact"):
		interact_with_object()
	elif (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_R) or event.is_action_pressed("buy_workstation"):
		try_buy_workstation()
	elif (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_T) or event.is_action_pressed("rent_workstation"):
		try_rent_workstation()

func try_buy_workstation() -> void:
	var facing = get_facing_interactables()
	if facing.size() == 0:
		return
	var target = facing[0]
	var grid = _get_grid_for_crop(target)
	if grid:
		target = grid
		
	if not is_instance_valid(target) or not ("ownership_type" in target):
		return
		
	if target.ownership_type == "Player":
		spawn_floating_text("Already Owned!")
		return
		
	var is_buyable = target.is_buyable if "is_buyable" in target else false
	if not is_buyable:
		spawn_floating_text("Not Buyable!")
		return
		
	var cost = target.buy_cost if "buy_cost" in target else 0
	if target.ownership_type == "NPC":
		cost *= 3 # 3x premium pricing from competition
		
	if GameState.gold < cost:
		spawn_floating_text("Need %d Gold!" % cost)
		return
		
	GameState.gold -= cost
	target.ownership_type = "Player"
	target.owner_id = "Player"
	
	if "crop_nodes" in target:
		for plot in target.crop_nodes:
			if is_instance_valid(plot):
				plot.ownership_type = "Player"
				plot.owner_id = "Player"
				
	interactables_changed.emit()
	spawn_floating_text("Bought for %d Gold!" % cost)

func try_rent_workstation() -> void:
	var facing = get_facing_interactables()
	if facing.size() == 0:
		return
	var target = facing[0]
	var grid = _get_grid_for_crop(target)
	if grid:
		target = grid
		
	if not is_instance_valid(target) or not ("ownership_type" in target):
		return
		
	if target.ownership_type == "Player":
		spawn_floating_text("Already Owned!")
		return
		
	var is_rentable = target.is_rentable if "is_rentable" in target else false
	if not is_rentable:
		spawn_floating_text("Not Rentable!")
		return
		
	var max_days = target.max_rent_days if "max_rent_days" in target else 5
	var current_days = target.rent_days_remaining if "rent_days_remaining" in target else 0
	if current_days >= max_days:
		spawn_floating_text("Rent Full (%d/%d)!" % [current_days, max_days])
		return
		
	var cost = target.rent_cost if "rent_cost" in target else 0
	if GameState.gold < cost:
		spawn_floating_text("Need %d Gold!" % cost)
		return
		
	GameState.gold -= cost
	target.rent_days_remaining = current_days + 1
	target.ownership_type = "Rented"
	target.owner_id = "Player"
	
	if "crop_nodes" in target:
		for plot in target.crop_nodes:
			if is_instance_valid(plot):
				plot.ownership_type = "Rented"
				plot.owner_id = "Player"
				plot.rent_days_remaining = target.rent_days_remaining
				
	interactables_changed.emit()
	spawn_floating_text("+1 Rent Day (%d/%d)!" % [target.rent_days_remaining, max_days])

func spawn_floating_text(txt: String) -> void:
	var label = Label.new()
	label.text = txt
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	if "Need" in txt or "Locked" in txt or "Not" in txt or "Full" in txt:
		label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	else:
		label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(-50, -40)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 32.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	
	await tween.finished
	label.queue_free()

func _physics_process(_delta: float) -> void:
	if is_frozen:
		# If frozen, ignore input and stand still
		velocity = Vector2.ZERO
		animated_sprite.play("idle_" + _last_direction)
		return

	# Get the input vector using the mapped actions (automatically handles deadzones and normalizes diagonals)
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_vector != Vector2.ZERO:
		# Apply velocity based on direction and speed (scaled by road speed boost)
		velocity = input_vector * speed * speed_multiplier
		
		# Determine the dominant cardinal direction for the 4-way animations
		var new_dir = _get_cardinal_direction(input_vector)
		if new_dir != _last_direction:
			_last_direction = new_dir
			interactables_changed.emit()
		
		# Play the walk animation for the corresponding direction
		animated_sprite.play("walk_" + _last_direction)
	else:
		# Stop movement when no input is received
		velocity = Vector2.ZERO
		
		# Play the idle animation facing the last moved direction
		animated_sprite.play("idle_" + _last_direction)
		
	# Move the character using Godot's physics engine (move_and_slide uses class velocity property in Godot 4)
	move_and_slide()

# Functions to lock and unlock player controls during transitions
func freeze() -> void:
	is_frozen = true
	velocity = Vector2.ZERO
	if animated_sprite:
		animated_sprite.play("idle_" + _last_direction)

func unfreeze() -> void:
	is_frozen = false

# Helper function to map an 8-direction vector to one of the 4 cardinal directions
func _get_cardinal_direction(direction: Vector2) -> String:
	# Determine if the movement is more horizontal or vertical
	if abs(direction.x) > abs(direction.y):
		return "east" if direction.x > 0 else "west"
	else:
		return "south" if direction.y > 0 else "north"
