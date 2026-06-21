class_name Fountain
extends StaticBody2D

@export var fountain_name: String = "Town Fountain"

@onready var interaction_area: Area2D = $InteractionArea

var gathering_player: CharacterBody2D = null
var gather_timer: float = 0.0
var gathered_amount: int = 0

func _ready() -> void:
	add_to_group("Fountains")
	add_to_group("nav_carve_obstacles")
	if GameState and GameState.has_method("add_text_tag"):
		GameState.add_text_tag(self, "Fountain")

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
		if gathering_player == body:
			_stop_gathering()

# Prompt text displayed on HUD
func get_interaction_text() -> String:
	if is_instance_valid(gathering_player):
		return "Stop Gathering Water"
	return "Gather Water"

func interact(player: CharacterBody2D) -> void:
	if is_instance_valid(gathering_player) and gathering_player == player:
		_stop_gathering()
	else:
		_start_gathering(player)

func _process(delta: float) -> void:
	if is_instance_valid(gathering_player):
		if gathering_player.get("is_harvesting") == false:
			_stop_gathering()
			return
			
		gather_timer -= delta
		if gather_timer <= 0.0:
			gather_timer = 3.0
			_give_water_tick()

func _start_gathering(player: CharacterBody2D) -> void:
	var econ_mgr = get_node_or_null("/root/EconomyManager")
	var water_res = econ_mgr.item_database.get("water") if econ_mgr else null
	if not water_res:
		water_res = load("res://common/items/instances/Raw Materials/water.tres")
		
	var inv = GameState.player_inventory if (GameState and GameState.player_inventory) else (player.get("inventory") if "inventory" in player else null)
	if inv and inv.slots.size() >= inv.max_slots:
		var has_space = false
		for slot in inv.slots:
			if slot.item == water_res and slot.quantity < water_res.max_stack:
				has_space = true
				break
		if not has_space:
			if GameState and GameState.has_method("spawn_ui_floating_text"):
				GameState.spawn_ui_floating_text("Inventory Full!")
			return

	gathering_player = player
	gather_timer = 3.0
	gathered_amount = 0
	player.set("is_harvesting", true)
	if GameState and GameState.has_method("spawn_ui_floating_text"):
		GameState.spawn_ui_floating_text("Started gathering water...")
	
	if player.has_signal("interactables_changed"):
		player.interactables_changed.emit()
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("update_interaction_prompt"):
		hud.update_interaction_prompt()

func _stop_gathering() -> void:
	if is_instance_valid(gathering_player):
		gathering_player.set("is_harvesting", false)
		if GameState and GameState.has_method("spawn_ui_floating_text"):
			GameState.spawn_ui_floating_text("Stopped gathering. Total: %d Water" % gathered_amount)
		if gathering_player.has_signal("interactables_changed"):
			gathering_player.interactables_changed.emit()
	gathering_player = null
	gather_timer = 0.0
	gathered_amount = 0
	
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("update_interaction_prompt"):
		hud.update_interaction_prompt()

func _give_water_tick() -> void:
	if not is_instance_valid(gathering_player):
		return
		
	var econ_mgr = get_node_or_null("/root/EconomyManager")
	var water_res = econ_mgr.item_database.get("water") if econ_mgr else null
	if not water_res:
		water_res = load("res://common/items/instances/Raw Materials/water.tres")
		
	if not water_res:
		print("[Fountain] Error: Water item resource not found!")
		_stop_gathering()
		return
		
	var inv = GameState.player_inventory if (GameState and GameState.player_inventory) else (gathering_player.get("inventory") if "inventory" in gathering_player else null)
	if not inv:
		print("[Fountain] Error: Player inventory not found!")
		_stop_gathering()
		return
		
	var remainder = inv.add_item(water_res, 1)
	var added = 1 - remainder
	if added > 0:
		gathered_amount += added
		if GameState and GameState.has_method("spawn_ui_floating_text"):
			GameState.spawn_ui_floating_text("+1 Water")
	else:
		if GameState and GameState.has_method("spawn_ui_floating_text"):
			GameState.spawn_ui_floating_text("Inventory Full!")
		_stop_gathering()

func get_interaction_position() -> Vector2:
	return global_position + Vector2(0, 32)
