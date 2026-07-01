extends "res://components/production/base_production_building.gd"

func _ready() -> void:
	_ready_base()
	
	add_to_group("EventHalls")
	add_to_group("MarketStall")
	add_to_group("nav_carve_obstacles")
	GameState.add_text_tag(self, custom_name if custom_name != "" else "Event Hall")
	
	# Adjust StallCounter visuals and collision to be on the right (x = 16 to 48)
	var stall_counter = get_node_or_null("StallCounter")
	if stall_counter:
		stall_counter.offset_left = 16.0
		stall_counter.offset_right = 48.0
		var stall_roof = stall_counter.get_node_or_null("StallRoof")
		if stall_roof:
			stall_roof.offset_left = 0.0
			stall_roof.offset_right = 32.0
			
	var col_stall = get_node_or_null("ColStall")
	if col_stall:
		col_stall.position = Vector2(32, 16)
		if col_stall.shape is RectangleShape2D:
			col_stall.shape = col_stall.shape.duplicate()
			col_stall.shape.size = Vector2(32, 48)
			
	var marker = get_node_or_null("EntranceMarker")
	if marker:
		marker.position = Vector2(32, 52)
	
	# Load Event Hall recipes inside the bench
	var bench = get_node_or_null("CraftingBench")
	if bench:
		bench.bench_name = "Event Master Desk"
		bench.recipes.clear()
		var r1 = load("res://common/items/recipes/noble_event.tres")
		var r2 = load("res://common/items/recipes/royal_event.tres")
		if r1: bench.recipes.append(r1)
		if r2: bench.recipes.append(r2)
			
		# Remove the bench's own interaction area
		var bench_interact = bench.get_node_or_null("InteractionArea")
		if bench_interact:
			bench_interact.queue_free()

	# Create left interaction area (Buy Building) dynamically
	var left_area = Area2D.new()
	left_area.name = "LeftInteractionArea"
	add_child(left_area)
	
	var col_left = CollisionShape2D.new()
	var shape_left = CircleShape2D.new()
	shape_left.radius = 24.0
	col_left.shape = shape_left
	col_left.position = Vector2(-32, 48)
	left_area.add_child(col_left)
	
	left_area.body_entered.connect(_on_front_body_entered)
	left_area.body_exited.connect(_on_front_body_exited)

	# Create doorway interaction area dynamically
	var front_area = Area2D.new()
	front_area.name = "FrontInteractionArea"
	add_child(front_area)
	
	var col_front = CollisionShape2D.new()
	var shape_front = CircleShape2D.new()
	shape_front.radius = 24.0
	col_front.shape = shape_front
	col_front.position = Vector2(0, 48)
	front_area.add_child(col_front)
	
	front_area.body_entered.connect(_on_front_body_entered)
	front_area.body_exited.connect(_on_front_body_exited)

	# Create counter interaction area dynamically
	var counter_area = Area2D.new()
	counter_area.name = "CounterInteractionArea"
	add_child(counter_area)
	
	var col_counter = CollisionShape2D.new()
	var shape_counter = CircleShape2D.new()
	shape_counter.radius = 24.0
	col_counter.shape = shape_counter
	col_counter.position = Vector2(32, 48)
	counter_area.add_child(col_counter)
	
	counter_area.body_entered.connect(_on_front_body_entered)
	counter_area.body_exited.connect(_on_front_body_exited)

func _process(delta: float) -> void:
	_tick_employees(delta)
