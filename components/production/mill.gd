extends StaticBody2D

@onready var vane_container: Node2D = get_node_or_null("Exterior/VaneContainer")
@onready var fade_trigger: Area2D = get_node_or_null("FadeTrigger")
@onready var exterior: Control = get_node_or_null("Exterior")

func _ready() -> void:
	add_to_group("Mills")
	GameState.add_text_tag(self, "Mill")
	
	var footprint = get_node_or_null("CollisionShape2D")
	if footprint:
		footprint.disabled = true
		
	if fade_trigger:
		fade_trigger.body_entered.connect(_on_fade_body_entered)
		fade_trigger.body_exited.connect(_on_fade_body_exited)
	
	# Load standard farmer recipes inside the bench
	var bench = get_node_or_null("CraftingBench")
	if bench:
		bench.bench_name = "Flour Mill"
		var grind_wheat = load("res://common/items/recipes/grind_wheat.tres")
		var bake_bread = load("res://common/items/recipes/bake_bread.tres")
		bench.recipes.clear()
		if grind_wheat:
			bench.recipes.append(grind_wheat)
		if bake_bread:
			bench.recipes.append(bake_bread)
		
		# Remove the bench's own interaction area to prevent outside interaction from other sides
		var bench_interact = bench.get_node_or_null("InteractionArea")
		if bench_interact:
			bench_interact.queue_free()

	# Create front interaction area dynamically
	var front_area = Area2D.new()
	front_area.name = "FrontInteractionArea"
	add_child(front_area)
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 32.0
	col.shape = shape
	col.position = Vector2(0, 48) # Centered at the front door/entrance outside the collision box
	front_area.add_child(col)
	
	front_area.body_entered.connect(_on_front_body_entered)
	front_area.body_exited.connect(_on_front_body_exited)

func _process(delta: float) -> void:
	# Spin the windmill vane continuously
	if vane_container:
		vane_container.rotation += delta * 1.5

func _on_front_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.register_interactable(self)

func _on_front_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.unregister_interactable(self)

# Prompt text displayed on HUD
func get_interaction_text() -> String:
	return "Craft"

# Called when player interacts (presses E)
func interact(player: CharacterBody2D) -> void:
	var bench = get_node_or_null("CraftingBench")
	if bench and bench.has_method("interact"):
		bench.interact(player)


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
