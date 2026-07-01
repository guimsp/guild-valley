class_name NPCAIController
extends CharacterBody2D

enum NPCType {
	TYPE_EMPLOYEE,
	TYPE_RELATION_TARGET,
	TYPE_CONSUMER,
	TYPE_STATIC
}

@export var npc_type: NPCType = NPCType.TYPE_EMPLOYEE
@export var speed: float = 50.0

@export var roams_interior_only: bool = false
@export var anchor_position: Vector2 = Vector2.ZERO
@export var is_quest_npc: bool = false
@export var quest_npc_id: String = ""
@export var npc_rank: String = ""
@export var rank_color: Color = Color.WHITE
@export var hometown: String = ""
var npc_runtime_state: Node = null
var is_talking: bool = false
var npc_gold: int = 100
var home_house: Node2D = null

var character_resource: CharacterResource = null:
	get:
		if not character_resource:
			character_resource = CharacterResource.new()
			character_resource.character_id = "char_" + str(Time.get_ticks_usec()) + "_" + str(randi() % 100000)
			var lvl = 1
			if skills_data and skills_data.has(career):
				lvl = skills_data[career].get("level", 1)
			character_resource.profession_level = lvl
			character_resource.update_daily_wage(self)
		return character_resource

var _road_speed_multiplier: float = 1.0
var active_roads_count: int = 0

# Hired Worker attributes
var is_hired: bool = false
var hired_by_building: Node2D = null
var worker_state: String = "idle_at_workshop":
	set(value):
		if worker_state != value:
			print("[NPC State Log] %s worker_state changed from %s to %s" % [npc_name, worker_state, value])
			worker_state = value
var shift_timer: float = 120.0
var target_mega_node: Area2D = null
var is_gathering: bool = false
var current_mega_node: Area2D = null
var limbo_timer: float = 0.0

var active_commercial_route: Resource = null
var commercial_route_current_waypoint_index: int = 0
var commercial_route_cargo_item_id: String = ""
var commercial_route_cargo_amount: int = 0
var commercial_route_gold_carried: int = 0
var commercial_route_sale_cooldown: float = 0.0
var current_stop_index: int = 0
var last_processed_stop_index: int = -1
var current_stop_transacted_count: int = 0
var cargo_inventory: InventoryComponent = null

var is_on_commercial_route: bool:
	get:
		return active_commercial_route != null

var career: String = "patreon"
var is_loaded: bool = false
var skills_data: Dictionary = {
	"patreon": { "level": 1, "xp": 0 },
	"scholar": { "level": 1, "xp": 0 },
	"craftsman": { "level": 1, "xp": 0 },
	"tailor": { "level": 1, "xp": 0 },
	"woodworker": { "level": 1, "xp": 0 },
	"herbalist": { "level": 1, "xp": 0 },
	"rogue": { "level": 1, "xp": 0 },
	"showman": { "level": 1, "xp": 0 }
}

var patreon_level: int:
	get: return skills_data["patreon"]["level"]
	set(val): skills_data["patreon"]["level"] = val
var scholar_level: int:
	get: return skills_data["scholar"]["level"]
	set(val): skills_data["scholar"]["level"] = val
var craftsman_level: int:
	get: return skills_data["craftsman"]["level"]
	set(val): skills_data["craftsman"]["level"] = val
var tailor_level: int:
	get: return skills_data["tailor"]["level"]
	set(val): skills_data["tailor"]["level"] = val
var woodworker_level: int:
	get: return skills_data["woodworker"]["level"]
	set(val): skills_data["woodworker"]["level"] = val
var herbalist_level: int:
	get: return skills_data["herbalist"]["level"]
	set(val): skills_data["herbalist"]["level"] = val
var rogue_level: int:
	get: return skills_data["rogue"]["level"]
	set(val): skills_data["rogue"]["level"] = val
var showman_level: int:
	get: return skills_data["showman"]["level"]
	set(val): skills_data["showman"]["level"] = val

var productivity: float:
	get:
		var active_career = career
		if is_instance_valid(hired_by_building) and "career" in hired_by_building and hired_by_building.career != "":
			active_career = hired_by_building.career
		var lvl = skills_data.get(active_career, {}).get("level", 1)
		var base_prod = 1.0 + (lvl * 0.02)
		if character_resource:
			var bonus = 0.0
			for trait_id in character_resource.active_mods:
				if trait_id.begins_with("Diligent Master_Lvl"):
					var lvl_mod = int(trait_id.replace("Diligent Master_Lvl", ""))
					if lvl_mod == 1: bonus += 0.03
					elif lvl_mod == 2: bonus += 0.06
					elif lvl_mod == 3: bonus += 0.10
			base_prod *= (1.0 + bonus)
		if GameState:
			base_prod = GameState.apply_macro_modifier(self, "productivity", base_prod)
		return base_prod
	set(val):
		pass
var salary: int:
	get:
		if character_resource:
			character_resource.update_daily_wage(self)
			return character_resource.daily_wage
		return 15
	set(val):
		if character_resource:
			character_resource.daily_wage = val
var province: String = "Unknown Province"
var spawn_settlement: Node2D = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

enum State {
	IDLE_HOME,
	SEARCH_CHOOSE,
	TRAVEL,
	TRANSACT
}

var current_state: State = State.IDLE_HOME
var profile: NPCProfile = null
var last_decision_breakdown: Dictionary = {}
var decision_history: Array = []

var npc_name: String = ""
var spawn_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var wait_timer: float = 0.0
var last_direction: String = "south"
var nav_motor: NPCNavigationMotor = null
var action_label: Label = null

# Target stall for transaction
var target_stall: CollisionObject2D = null
var target_item_id: String = ""
var is_searching: bool = false
var return_home_requested: bool = false

var _economy_manager: Node = null

# Child Components (Node Composition using base Node types to avoid global class cache issues)
var navigation: Node = null
var econ_brain: Node = null
var scheduler: Node = null
var interaction_component: Node = null
var employee_component: Node = null

var is_leisure_consuming: bool = false
var leisure_spot_building: Node2D = null
var scan_timer: float = 3.0
var _action_label_timer: float = randf_range(0.0, 0.3)

var speed_multiplier: float:
	get:
		if is_instance_valid(navigation) and navigation.has_method("get_speed_multiplier"):
			return navigation.get_speed_multiplier()
		return _road_speed_multiplier
	set(val):
		if is_instance_valid(navigation) and navigation.has_method("set_speed_multiplier"):
			navigation.set_speed_multiplier(val)
		else:
			_road_speed_multiplier = val

func get_home_position() -> Vector2:
	if GameState and quest_npc_id != "" and quest_npc_id == GameState.spouse_npc_id:
		for house in get_tree().get_nodes_in_group("Houses"):
			if is_instance_valid(house) and house.ownership_type == "Player" and not house.is_rental:
				return house.global_position + Vector2(0, 48)
				
	if is_instance_valid(home_house):
		if home_house.has_meta("blueprint_door_pos"):
			return home_house.get_meta("blueprint_door_pos") + Vector2(0, 32)
		return home_house.global_position + Vector2(0, 48)
		
	return spawn_position

func _ready() -> void:
	# Add NPCRuntimeState node dynamically if not already present
	if not has_node("NPCRuntimeState"):
		var state_script = load("res://entities/npc/NPCRuntimeState.gd")
		if state_script:
			npc_runtime_state = Node.new()
			npc_runtime_state.set_script(state_script)
			npc_runtime_state.name = "NPCRuntimeState"
			add_child(npc_runtime_state)
			
	# Add interaction and employee components dynamically
	var interact_script = load("res://components/npc/npc_interaction_component.gd")
	if interact_script:
		interaction_component = interact_script.new()
		interaction_component.name = "NPCInteractionComponent"
		add_child(interaction_component)
		interaction_component.setup(self)
		
	var emp_script = load("res://components/npc/npc_employee_component.gd")
	if emp_script:
		employee_component = emp_script.new()
		employee_component.name = "NPCEmployeeComponent"
		add_child(employee_component)
		employee_component.setup(self)
			
	# Instantiate and register sub-components dynamically
	navigation = get_node_or_null("NPCNavigationComponent")
	if not navigation:
		var nav_script = load("res://components/npc/npc_navigation_component.gd")
		if nav_script:
			navigation = nav_script.new()
			navigation.name = "NPCNavigationComponent"
			add_child(navigation)
		
	econ_brain = get_node_or_null("NPCEconomicBrain")
	if not econ_brain:
		var econ_script = load("res://components/npc/npc_economic_brain.gd")
		if econ_script:
			econ_brain = econ_script.new()
			econ_brain.name = "NPCEconomicBrain"
			add_child(econ_brain)
		
	scheduler = get_node_or_null("NPCScheduler")
	if not scheduler:
		var sched_script = load("res://components/npc/npc_scheduler.gd")
		if sched_script:
			scheduler = sched_script.new()
			scheduler.name = "NPCScheduler"
			add_child(scheduler)

	spawn_position = global_position
	target_position = global_position
	add_to_group("NPCs")
	
	if npc_type == NPCType.TYPE_RELATION_TARGET:
		add_to_group("RelationNPCs")
		if not has_node("RelationshipComponent"):
			var rel = load("res://components/relationship/relationship_component.gd").new()
			rel.name = "RelationshipComponent"
			add_child(rel)
		if interaction_component:
			interaction_component.setup_relationship_component()
			interaction_component.setup_relationship_icon()
	
	# Generate a random name
	var names = ["Aldous", "Bram", "Cuthbert", "Dante", "Elric", "Finnian", "Gideon", "Hadrian", "Ingram", "Jesper", "Kaelen", "Lysander", "Magnus", "Nesta", "Orion", "Percival", "Quentin", "Rowan", "Silas", "Tristan", "Urias", "Valerius", "Wyatt", "Xavier", "Yorick", "Zephyr", "Adela", "Beatrix", "Clara", "Dorothea", "Elowen", "Flora", "Gemma", "Hilda", "Ida", "Juliet", "Kora", "Lavinia", "Maeve", "Nora", "Opal", "Petra", "Rowena", "Sybil", "Tessa", "Una", "Vespera", "Willa", "Ysabel", "Zelda"]
	if npc_name == "":
		npc_name = names[randi() % names.size()]
	
	if is_quest_npc:
		add_to_group("QuestNPCs")
		
	var interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 0
	interaction_area.collision_mask = 1
	
	var col_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 32.0
	col_shape.shape = shape
	interaction_area.add_child(col_shape)
	add_child(interaction_area)
	
	interaction_area.body_entered.connect(func(body):
		if body.is_in_group("Player"):
			body.register_interactable(self)
	)
	interaction_area.body_exited.connect(func(body):
		if body.is_in_group("Player"):
			body.unregister_interactable(self)
	)
	
	collision_layer = 8
	collision_mask = 0
	
	# Override collision shape to be smaller for NPCs so they fit through narrow path clearances
	var col = get_node_or_null("CollisionShape2D")
	if col and col.shape is RectangleShape2D:
		col.shape = col.shape.duplicate()
		col.shape.size = Vector2(16, 12)
		col.position = Vector2(0, -6)
	
	# Soft blue modulate to distinguish from player and rival
	if animated_sprite and not has_meta("is_guild_master") and not has_meta("is_guild_office_npc"):
		animated_sprite.modulate = Color(0.6, 0.8, 1.0)
		
	# Instantiate default profile if not assigned
	if not profile:
		profile = NPCProfile.new()
		
	_economy_manager = get_node_or_null("/root/EconomyManager")
	nav_motor = get_node_or_null("NPCNavigationMotor")
	
	cargo_inventory = InventoryComponent.new()
	cargo_inventory.max_slots = 4
	cargo_inventory.max_stack = 20
	add_child(cargo_inventory)
	
	var eq_script = load("res://components/equipment/equipment_component.gd")
	if eq_script:
		var eq = eq_script.new()
		eq.name = "EquipmentComponent"
		add_child(eq)
		eq.equipment_changed.connect(recalculate_equipment_stats)
	
	# Randomize levels and stats
	if not is_loaded:
		if npc_type != NPCType.TYPE_RELATION_TARGET:
			var careers = ["patreon", "scholar", "craftsman", "tailor", "woodworker", "herbalist", "rogue", "showman"]
			career = careers[randi() % careers.size()]
			
		var min_l = 1
		var max_l = 2
		var pm = get_node_or_null("/root/ProsperityManager")
		if pm and province != "Unknown Province" and province != "":
			var val = pm.province_prosperity.get(province, 100.0)
			var p_level = pm.get_level_for_prosperity(val)
			if p_level == 2:
				min_l = 3
				max_l = 4
			elif p_level >= 3:
				min_l = 5
				max_l = 7
				
		skills_data = {
			"patreon": { "level": randi_range(min_l, max_l), "xp": 0 },
			"scholar": { "level": randi_range(min_l, max_l), "xp": 0 },
			"craftsman": { "level": randi_range(min_l, max_l), "xp": 0 },
			"tailor": { "level": randi_range(min_l, max_l), "xp": 0 },
			"woodworker": { "level": randi_range(min_l, max_l), "xp": 0 },
			"herbalist": { "level": randi_range(min_l, max_l), "xp": 0 },
			"rogue": { "level": randi_range(min_l, max_l), "xp": 0 },
			"showman": { "level": randi_range(min_l, max_l), "xp": 0 }
		}
		if npc_type == NPCType.TYPE_RELATION_TARGET:
			var rel = get_node_or_null("RelationshipComponent")
			if rel:
				career = rel.profession_type
				if skills_data.has(career):
					skills_data[career]["level"] = rel.profession_level
		speed = randf_range(50.0, 90.0)
		# salary is computed dynamically based on level, speed, productivity, and traits!
	
	call_deferred("_initialize_province")
	

	
	# Instantiate persistent debug action label above NPC head
	action_label = Label.new()
	action_label.name = "ActionLabel"
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", 11)
	action_label.add_theme_color_override("font_color", Color.WHITE)
	action_label.add_theme_color_override("font_outline_color", Color.BLACK)
	action_label.add_theme_constant_override("outline_size", 3)
	action_label.custom_minimum_size = Vector2(300, 45)
	action_label.position = Vector2(-150, -60)
	action_label.z_index = 20
	add_child(action_label)
		
	# Delay first action
	wait_timer = randf_range(1.0, 3.0)

func recalculate_equipment_stats() -> void:
	if not has_node("EquipmentComponent"):
		return
	var eq = get_node("EquipmentComponent")
	var base_slots = 4
	var total_slots = base_slots + eq.get_total_capacity_bonus()
	if cargo_inventory:
		cargo_inventory.max_slots = total_slots
		cargo_inventory.inventory_changed.emit()


func _physics_process(delta: float) -> void:
	if is_instance_valid(scheduler) and scheduler.has_method("tick_scheduler"):
		scheduler.call("tick_scheduler", delta)
	
	_action_label_timer -= delta
	if _action_label_timer <= 0.0:
		_action_label_timer = randf_range(0.25, 0.45)
		NPCDiagnostics.update_action_label(self)

func is_shift_active() -> bool:
	if GameState:
		return TimeManager.time_hours >= 8 and TimeManager.time_hours < 18
	return true

func _initialize_province() -> void:
	province = GameState.get_province_of_node(self)

func gain_profession_xp(career_id: String, amount: int) -> void:
	if employee_component:
		employee_component.gain_profession_xp(career_id, amount)

func go_to_workshop(building: Node2D) -> void:
	if employee_component:
		employee_component.go_to_workshop(building)

func resume_normal_behavior() -> void:
	if employee_component:
		employee_component.resume_normal_behavior()

func start_gathering_shift(node: Area2D) -> void:
	if employee_component:
		employee_component.start_gathering_shift(node)

func deposit_cargo() -> void:
	if employee_component:
		employee_component.deposit_cargo()

func on_tool_broken() -> void:
	if employee_component:
		employee_component.on_tool_broken()

func _pause_employee_due_to_missing_tool() -> void:
	if employee_component:
		employee_component._pause_employee_due_to_missing_tool()

func transfer_to_building(new_building: Node2D) -> void:
	if employee_component:
		employee_component.transfer_to_building(new_building)

func get_interaction_text() -> String:
	if interaction_component:
		return interaction_component.get_interaction_text()
	return "Talk to " + npc_name

func interact(player: CharacterBody2D) -> void:
	if interaction_component:
		interaction_component.interact(player)

func update_animation(vel: Vector2) -> void:
	if is_instance_valid(navigation) and navigation.has_method("update_movement_animation"):
		navigation.call("update_movement_animation", vel)

func _get_cardinal_direction(direction: Vector2) -> String:
	if is_instance_valid(navigation) and navigation.has_method("get_cardinal_direction"):
		return navigation.call("get_cardinal_direction", direction)
	if abs(direction.x) > abs(direction.y):
		return "east" if direction.x > 0 else "west"
	else:
		return "south" if direction.y > 0 else "north"

func _generate_path(destination: Vector2) -> void:
	if is_instance_valid(navigation) and navigation.has_method("generate_path"):
		navigation.call("generate_path", destination)

func _teleport(target_pos: Vector2) -> void:
	if is_instance_valid(navigation) and navigation.has_method("teleport"):
		navigation.call("teleport", target_pos)
	else:
		global_position = target_pos
		velocity = Vector2.ZERO

func spawn_debug_emote(text: String, color: Color) -> void:
	NPCDiagnostics.spawn_debug_emote(self, text, color)
