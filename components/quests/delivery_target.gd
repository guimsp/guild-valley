class_name DeliveryTarget
extends StaticBody2D

@export var target_id: String = ""
@export var target_name: String = ""
@export var quest_item_id: String = ""

func _ready() -> void:
	add_to_group("DeliveryTargets")
	add_to_group("nav_carve_obstacles")
	
	# Set up visual representation
	var color_rect = ColorRect.new()
	color_rect.size = Vector2(32.0, 32.0)
	color_rect.position = Vector2(-16.0, -16.0)
	if target_id == "church_archive":
		color_rect.color = Color(0.8, 0.7, 0.2, 0.8) # Gold
	else:
		color_rect.color = Color(0.3, 0.5, 0.8, 0.8) # Blue
	add_child(color_rect)
	
	# Add static collision
	var collision = CollisionShape2D.new()
	var box = RectangleShape2D.new()
	box.size = Vector2(32.0, 32.0)
	collision.shape = box
	add_child(collision)
	
	if GameState:
		GameState.add_text_tag(self, target_name)
		
	# Add interaction area
	var area = Area2D.new()
	area.name = "InteractionArea"
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 48.0
	col.shape = shape
	area.add_child(col)
	add_child(area)
	
	area.body_entered.connect(func(body):
		if body.is_in_group("Player"):
			body.register_interactable(self)
	)
	area.body_exited.connect(func(body):
		if body.is_in_group("Player"):
			body.unregister_interactable(self)
	)

func get_interaction_text() -> String:
	if GameState and GameState.player_inventory and GameState.player_inventory.has_item(quest_item_id, 1):
		return "Deliver to %s" % target_name
	return "Inspect %s" % target_name

func interact(_player: CharacterBody2D) -> void:
	if GameState and GameState.player_inventory and GameState.player_inventory.has_item(quest_item_id, 1):
		GameState.player_inventory.remove_item(quest_item_id, 1)
		
		# Complete matching active quests
		var completed_any = false
		for q in QuestManager.accepted_quests:
			if q.get("delivery_target_id") == target_id:
				QuestManager.complete_quest(q)
				completed_any = true
				break
				
		if completed_any:
			GameState.spawn_ui_floating_text("Delivered item to %s!" % target_name)
		else:
			GameState.spawn_ui_floating_text("Item delivered.")
	else:
		GameState.show_npc_dialogue(self, target_name, ["This is the %s. A delivery is expected here." % target_name])
