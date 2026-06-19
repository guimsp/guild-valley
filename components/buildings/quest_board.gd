class_name QuestBoard
extends StaticBody2D

@export var region_name: String = ""

@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	add_to_group("QuestBoards")
	if region_name == "":
		# Wait one frame to let settlements set up
		await get_tree().process_frame
		region_name = GameState.get_province_of_node(self)
		
	GameState.add_text_tag(self, "Quest Board")
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.register_interactable(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.unregister_interactable(self)

func get_interaction_text() -> String:
	return "Read Quest Board (%s)" % region_name

func interact(_player: CharacterBody2D) -> void:
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("open_quest_board_ui"):
		hud.open_quest_board_ui(region_name)
