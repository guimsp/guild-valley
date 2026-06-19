class_name Bed
extends StaticBody2D

@export var building_data: BuildingData = null

@onready var interaction_area: Area2D = $InteractionArea

@export_enum("Public", "Player", "Rented", "NPC") var ownership_type: String = "Player"
@export var owner_id: String = "Player"
@export var buy_cost: int = 100
@export var rent_cost: int = 25
@export var rent_days_remaining: int = 0
@export var max_rent_days: int = 5
@export var is_buyable: bool = false
@export var is_rentable: bool = false

func _ready() -> void:
	if not building_data:
		building_data = GameState.get_building_data_for_node(self)
	add_to_group("Beds")
	GameState.add_text_tag(self, "Bed")
	# Connect interaction signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)

func _on_interaction_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.register_interactable(self)

func _on_interaction_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.unregister_interactable(self)

# Prompt text displayed on HUD
func get_interaction_text() -> String:
	return "Sleep"

# Called when player interacts (presses E)
func interact(_player: CharacterBody2D) -> void:
	# Trigger transition to next day
	TransitionScreen.transition_to_next_day()
