class_name OreMine
extends StaticBody2D

@onready var interaction_area: Area2D = $InteractionArea
@onready var mine_visual: ColorRect = $ColorRect/MineVisual

var max_ore: int = 3
var current_ore: int = 3

@export_enum("Public", "Player", "Rented", "NPC") var ownership_type: String = "Public"
@export var owner_id: String = ""
@export var buy_cost: int = 300
@export var rent_cost: int = 80
@export var rent_days_remaining: int = 0
@export var max_rent_days: int = 5
@export var is_buyable: bool = true
@export var is_rentable: bool = true

func _ready() -> void:
	add_to_group("OreMines")
	GameState.add_text_tag(self, "Mine")
	
	# Connect interaction signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
		
	_update_visuals()

func _on_interaction_body_entered(body: Node2D) -> void:
	if current_ore > 0 and body.is_in_group("Player"):
		body.register_interactable(self)

func _on_interaction_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.unregister_interactable(self)

# Prompt text displayed on HUD
func get_interaction_text() -> String:
	return "Mine Ore (%d left)" % current_ore if current_ore > 0 else ""

# Called when player interacts (presses E)
func interact(player: CharacterBody2D) -> void:
	if current_ore <= 0:
		return
		
	# Load item resource
	var ore_res = load("res://common/items/instances/iron_ore.tres")
	if not ore_res:
		return
		
	# Attempt to add to player inventory
	var remainder = GameState.player_inventory.add_item(ore_res, 1)
	if remainder > 0:
		spawn_floating_text("Inventory Full!")
		_animate_failure()
		return
		
	# Successfully harvested
	current_ore -= 1
	_update_visuals()
	
	if current_ore <= 0:
		player.unregister_interactable(self)
		
	spawn_floating_text("+1 Iron Ore!")
	_animate_success()

func simulate_overnight_tick() -> void:
	current_ore = max_ore
	_update_visuals()

func _update_visuals() -> void:
	if not mine_visual:
		return
		
	if current_ore > 0:
		# Glowing metallic orange/rust color
		mine_visual.color = Color(0.85, 0.45, 0.25, 1.0)
	else:
		# Depleted dark empty grey rock
		mine_visual.color = Color(0.2, 0.2, 0.22, 1.0)

func spawn_floating_text(txt: String) -> void:
	var label = Label.new()
	label.text = txt
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.45))
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
