extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	print("[RoutesConsole] Body entered: ", body.name, " is player? ", body.is_in_group("Player"))
	if body.is_in_group("Player"):
		body.register_interactable(self)

func _on_body_exited(body: Node2D) -> void:
	print("[RoutesConsole] Body exited: ", body.name)
	if body.is_in_group("Player"):
		body.unregister_interactable(self)

func get_interaction_text() -> String:
	return "Open Commercial Routes Console"

func interact(_player: CharacterBody2D) -> void:
	print("[RoutesConsole] Player interacted! Opening UI...")
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
		
	if hud and hud.has_method("open_commercial_routes_ui"):
		hud.open_commercial_routes_ui()
	else:
		print("[RoutesConsole] Error: HUD not found or open_commercial_routes_ui method missing!")
