class_name CottonPlant
extends StaticBody2D

@onready var interaction_area: Area2D = $InteractionArea
@onready var crop_visual: ColorRect = $ColorRect/CropVisual

var is_grown: bool = true

var ownership_type: String = "Public"
var owner_id: String = ""
var buy_cost: int = 100
var rent_cost: int = 25
var rent_days_remaining: int = 0
var max_rent_days: int = 5
var is_buyable: bool = true
var is_rentable: bool = true

func _ready() -> void:
	add_to_group("CottonPlants")
	
	# Connect interaction signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
		
	_update_visuals()

func _on_interaction_body_entered(body: Node2D) -> void:
	if is_grown and body.is_in_group("Player"):
		body.register_interactable(self)

func _on_interaction_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.unregister_interactable(self)

# Prompt text displayed on HUD
func get_interaction_text() -> String:
	return "Harvest" if is_grown else ""

# Called when player interacts (presses E)
func interact(player: CharacterBody2D) -> void:
	if not is_grown:
		return
		
	# Load item resource
	var cotton_res = load("res://common/items/instances/cotton.tres")
	if not cotton_res:
		return
		
	# Attempt to add to player inventory
	var remainder = GameState.player_inventory.add_item(cotton_res, 1)
	if remainder > 0:
		# Player inventory is full
		spawn_floating_text("Inventory Full!")
		_animate_failure()
		return
		
	# Successfully harvested
	is_grown = false
	_update_visuals()
	
	# Unregister from player since it's no longer harvestable
	player.unregister_interactable(self)
	
	spawn_floating_text("+1 Cotton!")
	_animate_success()

func simulate_overnight_tick() -> void:
	is_grown = true
	_update_visuals()

func _update_visuals() -> void:
	if not crop_visual:
		return
		
	if is_grown:
		# Cotton fluffy white
		crop_visual.color = Color(0.95, 0.95, 0.98, 1.0)
	else:
		# Dark dry brown soil
		crop_visual.color = Color(0.36, 0.25, 0.2, 1.0)

func spawn_floating_text(txt: String) -> void:
	var label = Label.new()
	label.text = txt
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(-30, -40)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 32.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	
	await tween.finished
	label.queue_free()

func _animate_success() -> void:
	# Flash scale
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.08)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)

func _animate_failure() -> void:
	# Shake
	var _orig_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position:x", _orig_pos.x - 4, 0.05)
	tween.tween_property(self, "position:x", _orig_pos.x + 4, 0.05)
	tween.tween_property(self, "position:x", _orig_pos.x - 4, 0.05)
	tween.tween_property(self, "position:x", _orig_pos.x, 0.05)
