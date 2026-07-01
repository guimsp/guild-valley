class_name TeleportTrigger
extends Area2D

@export var is_local_teleport: bool = false
@export_file("*.tscn") var target_scene_path: String = ""
@export var target_spawn_position: Vector2 = Vector2.ZERO
@export var is_exit_door: bool = false
var target_room_node: Node = null

@export_enum("Public", "Player", "Rented", "NPC") var ownership_type: String = "Player"
@export var owner_id: String = "Player"
@export var buy_cost: int = 500
@export var rent_cost: int = 100
@export var rent_days_remaining: int = 0
@export var max_rent_days: int = 5
@export var is_buyable: bool = true
@export var is_rentable: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("TeleportTriggers")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if ownership_type == "NPC":
			body.register_interactable(self)
		else:
			_teleport()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.unregister_interactable(self)

func _teleport() -> void:
	if is_local_teleport:
		if is_exit_door:
			TransitionScreen.transition_exit_interior(target_spawn_position)
		elif is_instance_valid(target_room_node):
			TransitionScreen.transition_to_interior(target_room_node, target_spawn_position)
		else:
			TransitionScreen.transition_teleport(target_spawn_position)
	elif target_scene_path != "":
		TransitionScreen.transition_to_scene(target_scene_path, target_spawn_position)
	else:
		push_warning("[TeleportTrigger] Trigger collided but no transition parameters set!")

func get_interaction_text() -> String:
	return "Locked. Opponent property." if ownership_type == "NPC" else "Enter"


func interact(_player: CharacterBody2D) -> void:
	if ownership_type != "NPC":
		_teleport()
