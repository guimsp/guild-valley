extends StaticBody2D

@export var buy_cost: int = 300
@export_enum("Public", "Player", "Rented", "NPC") var ownership_type: String = "Player"
@export var owner_id: String = "Player"
@export var base_revenue: int = 40

@onready var fade_trigger: Area2D = get_node_or_null("FadeTrigger")
@onready var exterior: Control = get_node_or_null("Exterior")

func _ready() -> void:
	add_to_group("Inns")
	GameState.add_text_tag(self, "Inn")
	var footprint = get_node_or_null("CollisionShape2D")
	if footprint: 
		footprint.disabled = true
	if fade_trigger:
		fade_trigger.body_entered.connect(_on_fade_body_entered)
		fade_trigger.body_exited.connect(_on_fade_body_exited)

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
