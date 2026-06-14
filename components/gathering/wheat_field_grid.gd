extends Node2D

var crop_nodes: Array[Node2D] = []

@export_enum("Public", "Player", "Rented", "NPC") var ownership_type: String = "Public"
@export var owner_id: String = ""
@export var buy_cost: int = 100
@export var rent_cost: int = 25
@export var rent_days_remaining: int = 0
@export var max_rent_days: int = 5
@export var is_buyable: bool = true
@export var is_rentable: bool = true

func _ready() -> void:
	# Remove placement-only root collision shape if it exists
	var placement_col = get_node_or_null("CollisionShape2D")
	if placement_col:
		placement_col.queue_free()

	# Add grid to group Beds/fields/etc just in case
	add_to_group("WheatFieldGrids")
	GameState.add_text_tag(self, "Wheat Field")
	
	# Spawn crops on the parent level node so they Y-sort correctly with the player
	call_deferred("_spawn_crops")

func _spawn_crops() -> void:
	var parent = get_parent()
	if not parent:
		return
		
	var field_scene = load("res://components/gathering/wheat_field.tscn")
	if not field_scene:
		return
		
	# Grid spacing is 32 pixels (since wheat fields are 32x32)
	# Center the 4x4 grid at (0, 0)
	for r in range(4):
		for c in range(4):
			if r % 2 == 0:
				var plot = field_scene.instantiate() as Node2D
				plot.global_position = global_position + Vector2(
					(c - 1.5) * 32.0,
					(r - 1.5) * 32.0
				)
				if "ownership_type" in plot:
					plot.ownership_type = ownership_type
				if "owner_id" in plot:
					plot.owner_id = owner_id
				if "rent_days_remaining" in plot:
					plot.rent_days_remaining = rent_days_remaining
				parent.add_child(plot)
				crop_nodes.append(plot)
			else:
				# Free row: spawn a plain non-colliding dark soil ColorRect
				var soil = ColorRect.new()
				soil.size = Vector2(32, 32)
				soil.position = Vector2(
					(c - 1.5) * 32.0 - 16.0,
					(r - 1.5) * 32.0 - 16.0
				)
				soil.color = Color(0.3, 0.2, 0.15, 1.0)
				add_child(soil)

func _exit_tree() -> void:
	for node in crop_nodes:
		if is_instance_valid(node):
			node.queue_free()
