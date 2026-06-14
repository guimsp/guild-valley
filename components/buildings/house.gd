extends StaticBody2D

@export var is_rental: bool = false
@export_enum("Public", "Player", "Rented", "NPC") var ownership_type: String = "Player"
@export var owner_id: String = "Player"
@export var buy_cost: int = 250
@export var rent_cost: int = 30
@export var is_buyable: bool = true
@export var is_rentable: bool = false

@export var custom_name: String = "House"

@export var is_occupied: bool = false
@export var rent_days_remaining: int = 0

@onready var col_door: CollisionShape2D = get_node_or_null("ColDoor")
@onready var fade_trigger: Area2D = get_node_or_null("FadeTrigger")
@onready var exterior: Control = get_node_or_null("Exterior")
@onready var front_area: Area2D = get_node_or_null("FrontInteractionArea")

var nearest_settlement: Node2D = null

func _ready() -> void:
	add_to_group("Houses")
	GameState.add_text_tag(self, custom_name)
	
	var footprint = get_node_or_null("CollisionShape2D")
	if footprint:
		footprint.disabled = true
		
	if fade_trigger:
		fade_trigger.body_entered.connect(_on_fade_body_entered)
		fade_trigger.body_exited.connect(_on_fade_body_exited)
		
	if front_area:
		front_area.body_entered.connect(_on_front_body_entered)
		front_area.body_exited.connect(_on_front_body_exited)
		
	await get_tree().process_frame
	_find_nearest_settlement()
	_update_door_state()

func _find_nearest_settlement() -> void:
	var min_dist: float = INF
	var closest: Node2D = null
	for city in get_tree().get_nodes_in_group("Cities"):
		var dist = global_position.distance_to(city.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = city
	for town in get_tree().get_nodes_in_group("Towns"):
		var dist = global_position.distance_to(town.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = town
	nearest_settlement = closest

func set_is_rental(val: bool) -> void:
	is_rental = val
	_update_door_state()

func _update_door_state() -> void:
	if not col_door:
		return
	var should_lock = false
	if ownership_type == "NPC":
		should_lock = true
	elif ownership_type == "Player":
		if is_rental and is_occupied:
			should_lock = true
	elif ownership_type == "Rented":
		if owner_id != "Player":
			should_lock = true
	col_door.disabled = not should_lock

func _on_fade_body_entered(body: Node2D) -> void:
	if (body.is_in_group("Player") or body.is_in_group("Rivals")) and exterior:
		create_tween().tween_property(exterior, "modulate:a", 0.0, 0.25)

func _on_fade_body_exited(body: Node2D) -> void:
	if (body.is_in_group("Player") or body.is_in_group("Rivals")):
		if fade_trigger:
			for b in fade_trigger.get_overlapping_bodies():
				if b.is_in_group("Player") or b.is_in_group("Rivals"):
					return
		if exterior:
			create_tween().tween_property(exterior, "modulate:a", 1.0, 0.25)

func _on_front_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.register_interactable(self)

func _on_front_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.unregister_interactable(self)

func get_interaction_text() -> String:
	if ownership_type == "NPC":
		return "Buy House (%d G)" % (buy_cost * 3)
	elif ownership_type == "Player":
		if is_rental:
			return "Occupied" if is_occupied else "Vacant Rental"
		else:
			return "Personal Home (Enter)"
	return "Enter"

func interact(player: CharacterBody2D) -> void:
	if ownership_type == "NPC":
		player.spawn_floating_text("Press [R] to buy this house!")
	elif ownership_type == "Player" and is_rental and is_occupied:
		player.spawn_floating_text("This rental house is occupied!")
