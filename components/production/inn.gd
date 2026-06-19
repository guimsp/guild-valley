extends "res://components/production/base_production_building.gd"


func _ready() -> void:
	_ready_base()
	
	add_to_group("Inns")
	add_to_group("MarketStall")
	add_to_group("nav_carve_obstacles")
	GameState.add_text_tag(self, custom_name if custom_name != "" else "Inn")
	
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
	
	var bench = get_node_or_null("CraftingBench")
	if bench:
		bench.bench_name = "Inn Bench"
		bench.recipes.clear()
		
		# L1 Inn / L2 Hotel common services
		var r1 = load("res://common/items/recipes/kitchen_service.tres")
		var r2 = load("res://common/items/recipes/bathhouse_service.tres")
		if r1: bench.recipes.append(r1)
		if r2: bench.recipes.append(r2)
		
		# L2 Hotel premium services
		if building_level >= 2:
			var r3 = load("res://common/items/recipes/hotel_dining_berry.tres")
			var r4 = load("res://common/items/recipes/hotel_dining_gilded.tres")
			if r3: bench.recipes.append(r3)
			if r4: bench.recipes.append(r4)
		
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
	
	if building_storage:
		var sbox = get_node_or_null("StrongboxComponent")
		if sbox:
			# 1. Kitchen Service (Savory Eggs)
			var k_tickets = building_storage.get_item_amount("kitchen_service_ticket")
			if k_tickets > 0:
				building_storage.remove_item("kitchen_service_ticket", k_tickets)
				var mult = 1.5 if building_level >= 2 else 1.0
				var revenue = int(k_tickets * 60 * mult)
				sbox.strongbox_gold += revenue
				sbox.add_transaction("Kitchen Service", k_tickets, revenue, GameState.get_time_string(), "Guests")
				GameState.spawn_ui_floating_text("+%d Gold (Kitchen Service)" % revenue)
				
			# 2. Bathhouse Service
			var b_tickets = building_storage.get_item_amount("bathhouse_ticket")
			if b_tickets > 0:
				building_storage.remove_item("bathhouse_ticket", b_tickets)
				var mult = 2.0 if building_level >= 2 else 1.0
				var revenue = int(b_tickets * 40 * mult)
				sbox.strongbox_gold += revenue
				sbox.add_transaction("Bathhouse Service", b_tickets, revenue, GameState.get_time_string(), "Guests")
				GameState.spawn_ui_floating_text("+%d Gold (Bathhouse Service)" % revenue)
				
			# 3. Fine Dining (Berry Cake)
			var d_tickets = building_storage.get_item_amount("hotel_dining_ticket")
			if d_tickets > 0:
				building_storage.remove_item("hotel_dining_ticket", d_tickets)
				var revenue = int(d_tickets * 150)
				sbox.strongbox_gold += revenue
				sbox.add_transaction("Fine Dining (Berry)", d_tickets, revenue, GameState.get_time_string(), "Guests")
				GameState.spawn_ui_floating_text("+%d Gold (Hotel Fine Dining)" % revenue)
				
			# 4. Fine Dining (Gilded Cake)
			var dg_tickets = building_storage.get_item_amount("hotel_dining_ticket_gilded")
			if dg_tickets > 0:
				building_storage.remove_item("hotel_dining_ticket_gilded", dg_tickets)
				var revenue = int(dg_tickets * 250)
				sbox.strongbox_gold += revenue
				sbox.add_transaction("Fine Dining (Gilded)", dg_tickets, revenue, GameState.get_time_string(), "Guests")
				GameState.spawn_ui_floating_text("+%d Gold (Hotel Fine Dining)" % revenue)
