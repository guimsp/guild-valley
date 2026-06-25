extends "res://components/production/base_production_building.gd"

func _ready() -> void:
	_ready_base()
	
	add_to_group("Sanitariums")
	add_to_group("MarketStall")
	add_to_group("nav_carve_obstacles")
	GameState.add_text_tag(self, custom_name if custom_name != "" else "Imperial Sanitarium")
	
	# Adjust StallCounter visuals and collision to be on the right
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
	
	# Load Sanitarium recipes inside the bench
	var bench = get_node_or_null("CraftingBench")
	if bench:
		bench.bench_name = "Sanitarium Contract Board"
		bench.recipes.clear()
		var r1 = load("res://common/items/recipes/provincial_sanitarium_desk.tres")
		var r2 = load("res://common/items/recipes/contract_crop_blight.tres")
		var r3 = load("res://common/items/recipes/contract_treat_archduke.tres")
		if r1: bench.recipes.append(r1)
		if r2: bench.recipes.append(r2)
		if r3: bench.recipes.append(r3)
			
		# Remove the bench's own interaction area
		var bench_interact = bench.get_node_or_null("InteractionArea")
		if bench_interact:
			bench_interact.queue_free()

	# Create left interaction area dynamically
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
		_process_event_certificate(
			"crop_blight_contract",
			"res://common/items/instances/Finished Goods/crop_blight_contract.tres",
			"res://common/items/recipes/contract_crop_blight.tres",
			"Blight Eradication Contract",
			"State"
		)
		_process_event_certificate(
			"archduke_treatment_contract",
			"res://common/items/instances/Finished Goods/archduke_treatment_contract.tres",
			"res://common/items/recipes/contract_treat_archduke.tres",
			"Archduke Treatment Contract",
			"State"
		)

func _process_event_certificate(cert_id: String, cert_path: String, recipe_path: String, service_name: String, guest_type: String) -> void:
	var cert_qty = building_storage.get_item_amount(cert_id)
	if cert_qty <= 0:
		return
		
	building_storage.remove_item(cert_id, cert_qty)
	
	var cert_item = load(cert_path) as ItemData
	var recipe = load(recipe_path) as Recipe
	if not cert_item or not recipe:
		return
		
	var consumed_items: Array = []
	for input in recipe.inputs:
		var qty = recipe.inputs[input]
		for j in range(qty):
			consumed_items.append(input)
			
	var econ = get_node_or_null("/root/EconomyManager")
	if not econ:
		return
		
	var sbox = get_node_or_null("StrongboxComponent")
	if not sbox:
		return
		
	var total_payout: int = 0
	var total_influence: int = 0
	var total_prestige: int = 0
	var bad_outcomes_count: int = 0
	var outcome_names: Array[String] = []
	
	var base_influence: int = 50 if cert_id == "crop_blight_contract" else 75
	var base_prestige: int = 100 if cert_id == "crop_blight_contract" else 150
	var contract_data: Dictionary = {
		"influence": base_influence,
		"prestige": base_prestige
	}
	
	for i in range(cert_qty):
		var resolution: Dictionary = econ.resolve_grand_event(consumed_items, contract_data)
		var payout: int = resolution.get("payout", 0)
		var outcome_tier: int = resolution.get("outcome_tier", 1)
		
		total_payout += payout
		if outcome_tier == 0:
			bad_outcomes_count += 1
			
		var outcome_str: String = "Regular"
		match outcome_tier:
			0: outcome_str = "Bad"
			1: outcome_str = "Regular"
			2: outcome_str = "Good"
			3: outcome_str = "Excellent"
			4: outcome_str = "Pristine"
		outcome_names.append(outcome_str)
		
		var p_mult: float = resolution.get("prestige_multiplier", 1.0)
		total_influence += int(round(float(base_influence) * p_mult))
		total_prestige += int(round(float(base_prestige) * p_mult))
		
	sbox.strongbox_gold += total_payout
	
	GameState.influence += total_influence
	GameState.permanent_influence += total_prestige
	
	var outcomes_summary: String = ", ".join(outcome_names)
	var tx_name: String = "%s (%s)" % [service_name, outcomes_summary]
	sbox.add_transaction(tx_name, cert_qty, total_payout, TimeManager.get_time_string(), guest_type)
	
	GameState.spawn_ui_floating_text("+%d Gold, +%d Influence (%s: %s)" % [total_payout, total_influence, service_name, outcomes_summary])
	
	if bad_outcomes_count > 0:
		var msg: String = "A completed %s failed testing, causing minor delays and reduced payouts." % service_name
		AlertManager.add_alert("Grand Event Mishap!", msg, "warning", self)
