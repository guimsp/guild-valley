class_name InfluenceBroker
extends StaticBody2D

var broker_name: String = "Influence Broker"

@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	add_to_group("InfluenceBroker")
	GameState.add_text_tag(self, "Broker")
	
	# Reposition and recolor the Broker text tag so it sits cleanly above his head
	for child in get_children():
		if child is Label and child.text == "Broker":
			child.position = Vector2(-60, -75)
			child.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	
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

func get_interaction_text() -> String:
	return "Buy Influence"

func interact(_player: CharacterBody2D) -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
		
	if hud and hud.has_method("open_influence_broker_ui"):
		hud.open_influence_broker_ui(self)
