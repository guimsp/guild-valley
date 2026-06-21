extends StaticBody2D

@export var building_data: BuildingData = null

@export var is_rental: bool = false
@export var is_guild: bool = false
@export var is_city_council: bool = false
@export_enum("Public", "Player", "Rented", "NPC") var ownership_type: String = "Player"
@export var owner_id: String = "Player"
@export var buy_cost: int = 250
@export var rent_cost: int = 30
@export var is_buyable: bool = true
@export var is_rentable: bool = false

@export var custom_name: String = "House"

@export var is_occupied: bool = false
@export var rent_days_remaining: int = 0

@onready var col_door: CollisionShape2D = get_node_or_null("ColDoor")
@onready var fade_trigger: Area2D = get_node_or_null("FadeTrigger")
@onready var exterior: Control = get_node_or_null("Exterior")
@onready var front_area: Area2D = get_node_or_null("FrontInteractionArea")

var nearest_settlement: Node2D = null
var entry_door: Area2D = null
var interior_position: Vector2 = Vector2.ZERO
var instanced_interior: Node2D = null
var inventory: Node = null

func _ready() -> void:
	if is_guild:
		ownership_type = "Public"
		is_buyable = false
		owner_id = "Guild"
	elif is_city_council:
		ownership_type = "Public"
		is_buyable = false
		owner_id = "Council"
		
	var local_interior = get_node_or_null("Interior")
	if local_interior:
		local_interior.queue_free()
		
	if not building_data:
		building_data = GameState.get_building_data_for_node(self)
	add_to_group("Houses")
	add_to_group("nav_carve_obstacles")
	GameState.add_text_tag(self, custom_name)
	
	var footprint = get_node_or_null("CollisionShape2D")
	if footprint:
		footprint.disabled = true
		
	if fade_trigger:
		fade_trigger.body_entered.connect(_on_fade_body_entered)
		fade_trigger.body_exited.connect(_on_fade_body_exited)
		
	if front_area:
		front_area.body_entered.connect(_on_front_body_entered)
		front_area.body_exited.connect(_on_front_body_exited)
		
	# Setup shared inventory
	_setup_shared_inventory()
		
	await get_tree().process_frame
	_find_nearest_settlement()
	
	# Instantiate off-screen interior
	var building_id = "bld_house_%d_%d" % [int(global_position.x), int(global_position.y)]
	interior_position = GameState.allocate_interior_space(building_id)
	
	var interior_path = "res://components/buildings/interior_template.tscn"
	if is_city_council:
		interior_path = "res://components/buildings/lawhouse_interior.tscn"
	elif is_guild:
		interior_path = "res://components/buildings/guild_hall_interior.tscn"
		
	var interior_scene = load(interior_path)
	if interior_scene:
		instanced_interior = interior_scene.instantiate() as Node2D
		instanced_interior.name = "Interior_House_" + str(int(global_position.x))
		instanced_interior.global_position = interior_position
		var parent_scene = get_tree().current_scene if get_tree().current_scene else get_tree().root
		parent_scene.call_deferred("add_child", instanced_interior)
		
		var exit_spawn_pos = global_position + Vector2(0, 64)
		instanced_interior.call_deferred("setup_interior", self, exit_spawn_pos)
		
	_create_entry_door()
	_update_door_state()

func _find_nearest_settlement() -> void:
	var min_dist: float = INF
	var closest: Node2D = null
	for city in get_tree().get_nodes_in_group("Cities"):
		var dist = global_position.distance_to(city.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = city
	for town in get_tree().get_nodes_in_group("Towns"):
		var dist = global_position.distance_to(town.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = town
	nearest_settlement = closest

func set_is_rental(val: bool) -> void:
	is_rental = val
	_update_door_state()

func _update_door_state() -> void:
	if col_door:
		var should_lock = false
		if ownership_type == "NPC":
			should_lock = true
		elif ownership_type == "Player":
			if is_rental and is_occupied:
				should_lock = true
		elif ownership_type == "Rented":
			if owner_id != "Player":
				should_lock = true
		col_door.disabled = not should_lock
		
	if entry_door:
		entry_door.ownership_type = ownership_type
		entry_door.owner_id = owner_id
		if entry_door.has_method("_update_door_state"):
			entry_door._update_door_state()
			
	if instanced_interior and instanced_interior.exit_door:
		instanced_interior.exit_door.ownership_type = ownership_type
		instanced_interior.exit_door.owner_id = owner_id
		if instanced_interior.exit_door.has_method("_update_door_state"):
			instanced_interior.exit_door._update_door_state()

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

func _on_front_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.register_interactable(self)

func _on_front_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.unregister_interactable(self)

func get_interaction_text() -> String:
	if is_guild:
		return "Enter %s" % custom_name
	if ownership_type == "NPC":
		return "Buy House (%d G)" % (buy_cost * 3)
	elif ownership_type == "Player":
		if is_rental:
			return "Occupied" if is_occupied else "Vacant Rental"
		else:
			return "Personal Home (Enter)"
	return "Enter"

func interact(player: CharacterBody2D) -> void:
	if ownership_type == "NPC" and not is_guild:
		player.spawn_floating_text("Press [R] to buy this house!")
	elif ownership_type == "Player" and is_rental and is_occupied:
		player.spawn_floating_text("This rental house is occupied!")
	else:
		if entry_door:
			entry_door._teleport()


func _setup_shared_inventory() -> void:
	var inv_script = load("res://components/inventory/inventory_component.gd")
	inventory = inv_script.new()
	inventory.name = "BuildingInventory"
	inventory.max_slots = 8
	inventory.max_stack = 20
	inventory.max_weight = 100.0
	add_child(inventory)

func _create_entry_door() -> void:
	entry_door = Area2D.new()
	entry_door.name = "EntryDoorTrigger"
	entry_door.set_script(load("res://components/teleport/teleport_trigger.gd"))
	entry_door.position = Vector2(0, 32)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 16)
	col.shape = shape
	entry_door.add_child(col)
	
	add_child(entry_door)
	
	entry_door.is_local_teleport = true
	entry_door.target_spawn_position = interior_position + Vector2(0, 60)
	entry_door.ownership_type = ownership_type
	entry_door.owner_id = owner_id
