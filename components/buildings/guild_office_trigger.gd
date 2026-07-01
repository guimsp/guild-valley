extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.call("register_interactable", self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.call("unregister_interactable", self)

func get_interaction_text() -> String:
	var office_name = get_meta("office_name")
	return "Guild Office: " + office_name

func interact(_player: CharacterBody2D) -> void:
	var office_name = get_meta("office_name")
	var prov = GameState.get_province_of_node(self) if GameState else "Valley Province"
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
	if hud and hud.has_method("open_guild_ui"):
		hud.call("open_guild_ui", prov)
