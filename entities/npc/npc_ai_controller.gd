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
var is_talking: bool = false
var npc_gold: int = 100

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

var is_leisure_consuming: bool = false
var leisure_spot_building: Node2D = null
var scan_timer: float = 3.0

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
				return house.global_position
	return spawn_position

func _ready() -> void:
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
		setup_relationship_component()
		_setup_relationship_icon()
	
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
	
	var pm = get_node_or_null("/root/PoliticsManager")
	if pm:
		pm.law_changed.connect(_on_law_changed)
	
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
	action_label.position = Vector2(-150, -220)
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

func setup_relationship_component() -> void:
	if npc_type != NPCType.TYPE_RELATION_TARGET:
		return
	var rel = get_node_or_null("RelationshipComponent")
	if not rel:
		return
	match quest_npc_id:
		"elena":
			rel.hidden_preferences = ["spool_thread", "red_dye", "blue_dye"]
			rel.disliked_preferences = ["iron_ore", "corrosive_acid", "animal_feed", "smugglers_moonshine"]
			rel.profession_type = "tailor"
			rel.profession_level = 3
		"aldous":
			rel.hidden_preferences = ["ancient_manuscript", "ink", "paper"]
			rel.disliked_preferences = ["smugglers_moonshine", "animal_feed", "iron_ore", "corrosive_acid"]
			rel.profession_type = "scholar"
			rel.profession_level = 4
		"valeria":
			rel.hidden_preferences = ["confidential_documents", "gold_ring", "silver_necklace"]
			rel.disliked_preferences = ["animal_feed", "iron_ore", "wheat", "cotton", "smugglers_moonshine"]
			rel.profession_type = "scholar"
			rel.profession_level = 5
		"gideon":
			rel.hidden_preferences = ["standard_timber", "iron_ingot", "iron_ore"]
			rel.disliked_preferences = ["ancient_manuscript", "confidential_documents", "paper", "smugglers_moonshine"]
			rel.profession_type = "craftsman"
			rel.profession_level = 3

var _relationship_icon: Label = null

func _setup_relationship_icon() -> void:
	if npc_type != NPCType.TYPE_RELATION_TARGET:
		return
	var rel = get_node_or_null("RelationshipComponent")
	if not rel:
		return
	
	_relationship_icon = Label.new()
	_relationship_icon.name = "RelationshipIcon"
	_relationship_icon.text = "♥"
	_relationship_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relationship_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_relationship_icon.add_theme_font_size_override("font_size", 20)
	_relationship_icon.add_theme_color_override("font_outline_color", Color.BLACK)
	_relationship_icon.add_theme_constant_override("outline_size", 4)
	_relationship_icon.custom_minimum_size = Vector2(40, 40)
	_relationship_icon.position = Vector2(-20, -250)
	_relationship_icon.z_index = 21
	add_child(_relationship_icon)
	
	_update_relationship_icon(rel.relationship_value)
	
	if not rel.relationship_changed.is_connected(_update_relationship_icon):
		rel.relationship_changed.connect(_update_relationship_icon)

func _update_relationship_icon(val: float) -> void:
	if not is_instance_valid(_relationship_icon):
		return
	
	var color = Color.YELLOW
	if val < 0.0:
		color = Color.RED
	elif val >= 60.0:
		color = Color(1.0, 0.4, 0.7) # Pink
	elif val >= 30.0:
		color = Color.GREEN
		
	_relationship_icon.add_theme_color_override("font_color", color)

func _physics_process(delta: float) -> void:
	if is_instance_valid(scheduler) and scheduler.has_method("tick_scheduler"):
		scheduler.call("tick_scheduler", delta)
	_update_action_label()

func is_shift_active() -> bool:
	if GameState:
		return TimeManager.time_hours >= 8 and TimeManager.time_hours < 18
	return true

func _initialize_province() -> void:
	province = GameState.get_province_of_node(self)

func _on_law_changed(prov: String, law_id: String, is_active: bool) -> void:
	if not is_active:
		return
	if not is_hired or not is_instance_valid(hired_by_building):
		return
		
	var my_prov = province
	if my_prov == "Unknown Province" or my_prov == "":
		my_prov = GameState.get_province_of_node(self) if GameState else ""
		
	if my_prov != prov:
		return
		
	# Check active gathering task
	if is_instance_valid(target_mega_node):
		var res_id = target_mega_node.resource_type_id
		if law_id == "crown_forestry_protection" and res_id == "standard_timber":
			_trigger_worker_strike("Forestry Protection")
		elif law_id == "noble_game_preservation" and res_id == "venison":
			_trigger_worker_strike("Game Preservation")
			
	# Check active smelting
	if law_id == "metallurgical_monopoly" and hired_by_building.is_in_group("Smelters"):
		var sett = GameState.get_nearest_settlement(hired_by_building)
		if sett and not sett.is_in_group("Cities"):
			_trigger_worker_strike("Metallurgical Monopoly")

func _trigger_worker_strike(reason: String) -> void:
	is_gathering = false
	if is_instance_valid(target_mega_node):
		target_mega_node._on_body_exited(self)
	worker_state = "returning_to_workshop"
	if is_instance_valid(hired_by_building):
		var target_pos = hired_by_building.get_interaction_position()
		_generate_path(target_pos)
		
		# Cancel this task on building's hired employees list too
		for emp in hired_by_building.hired_employees:
			if emp.get("npc_ref") == self:
				emp["active_gathering_node_path"] = ""
				emp["active_recipe_path"] = ""
				emp["shift_status"] = "idle"
				emp["is_paused"] = true
				break
				
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
	if hud and hud.has_method("_spawn_floating_text"):
		hud._spawn_floating_text("%s: On Strike! (%s)" % [npc_name, reason], global_position)

func gain_profession_xp(career_id: String, amount: int) -> void:
	if not skills_data.has(career_id):
		return
		
	var data = skills_data[career_id]
	var lvl = data["level"]
	if lvl in [3, 6, 9]:
		data["xp"] = 0
		return
		
	data["xp"] += amount
	var xp_to_next: int = int(round(100 * pow(1.5, data["level"] - 1)))
	
	while data["xp"] >= xp_to_next:
		data["xp"] -= xp_to_next
		data["level"] += 1
		print("[NPC] %s Leveled Up %s to Lvl %d!" % [npc_name, career_id.capitalize(), data["level"]])
		
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud:
			if hud.has_method("_spawn_floating_text"):
				hud._spawn_floating_text("%s Leveled Up: Lvl %d!" % [career_id.capitalize(), data["level"]], global_position)
			if hud.get("_building_ui_instance") != null and is_instance_valid(hud._building_ui_instance) and hud._building_ui_instance.has_method("refresh"):
				hud._building_ui_instance.refresh()
				
		lvl = data["level"]
		if lvl in [3, 6, 9]:
			data["xp"] = 0
			if hud and hud.has_method("_spawn_floating_text"):
				hud._spawn_floating_text("%s Locked at Lvl %d! Needs Breakthrough!" % [career_id.capitalize(), lvl], global_position)
			break
			
		xp_to_next = int(round(100 * pow(1.5, data["level"] - 1)))

func go_to_workshop(building: Node2D) -> void:
	npc_type = NPCType.TYPE_EMPLOYEE
	is_hired = true
	hired_by_building = building
	worker_state = "traveling_to_workshop"
	limbo_timer = 0.0
	
	if animated_sprite:
		if building.ownership_type == "Player":
			animated_sprite.modulate = Color(0.6, 1.0, 0.6) # Greenish
		else:
			animated_sprite.modulate = Color(1.0, 0.6, 0.6) # Reddish
			
	var target_pos = building.global_position
	if building.has_method("get_interaction_position"):
		target_pos = building.get_interaction_position()
	_generate_path(target_pos)

func resume_normal_behavior() -> void:
	if is_instance_valid(hired_by_building):
		var eq = get_node_or_null("EquipmentComponent")
		if eq:
			var current_tool = eq.get_equipped_item("tool")
			if current_tool != null:
				var target_storage = hired_by_building.get("building_storage")
				if not target_storage:
					target_storage = hired_by_building.get("inventory")
				if target_storage:
					target_storage.add_item(current_tool, 1)
				eq.unequip_item("tool")
	is_hired = false
	npc_type = NPCType.TYPE_CONSUMER
	hired_by_building = null
	worker_state = "idle_at_workshop"
	limbo_timer = 5.0
	target_mega_node = null
	is_gathering = false
	current_mega_node = null
	
	if animated_sprite:
		animated_sprite.modulate = Color(0.6, 0.8, 1.0) # Reset to soft blue
		
	var lm = get_node_or_null("/root/LogisticsManager")
	if lm:
		lm.erase_buffer(self)

func _try_equip_tool_from_building(node_path: String) -> void:
	if is_instance_valid(econ_brain) and econ_brain.has_method("try_equip_tool_from_building"):
		econ_brain.call("try_equip_tool_from_building", node_path)

func start_gathering_shift(node: Area2D) -> void:
	target_mega_node = node
	is_gathering = false
	shift_timer = 120.0
	
	if is_instance_valid(node):
		var req_tool = ""
		if is_instance_valid(econ_brain) and econ_brain.has_method("get_required_tool_id_for_node"):
			req_tool = econ_brain.call("get_required_tool_id_for_node", node.get_path())
			
		var has_tool = false
		var eq = get_node_or_null("EquipmentComponent")
		if eq and req_tool != "":
			var current_tool = eq.get_equipped_item("tool")
			if current_tool != null and current_tool.id == req_tool:
				has_tool = true
				
		var close_to_workshop = false
		if is_instance_valid(hired_by_building):
			var doorstep = hired_by_building.get_interaction_position()
			if global_position.y >= 9000.0 or global_position.distance_to(doorstep) <= 30.0:
				close_to_workshop = true
				
		if req_tool != "" and not has_tool and not close_to_workshop:
			worker_state = "traveling_to_workshop"
			if is_instance_valid(hired_by_building):
				var target_pos = hired_by_building.get_interaction_position()
				_generate_path(target_pos)
		else:
			worker_state = "traveling_to_node"
			if req_tool != "" and not has_tool:
				_try_equip_tool_from_building(node.get_path())
			# If inside, teleport outside first
			if global_position.y > 9000.0 and is_instance_valid(hired_by_building):
				_teleport(hired_by_building.get_interaction_position())
			var target_pos = node.global_position
			_generate_path(target_pos)

func deposit_cargo() -> void:
	if is_instance_valid(econ_brain) and econ_brain.has_method("deposit_cargo"):
		econ_brain.call("deposit_cargo")

func _exit_tree() -> void:
	if is_instance_valid(hired_by_building):
		var eq = get_node_or_null("EquipmentComponent")
		if eq:
			var current_tool = eq.get_equipped_item("tool")
			if current_tool != null:
				var target_storage = hired_by_building.get("building_storage")
				if not target_storage:
					target_storage = hired_by_building.get("inventory")
				if target_storage:
					target_storage.add_item(current_tool, 1)
				eq.unequip_item("tool")
	var lm = get_node_or_null("/root/LogisticsManager")
	if lm:
		lm.erase_buffer(self)

func on_tool_broken() -> void:
	is_gathering = false
	if is_instance_valid(target_mega_node):
		target_mega_node._on_body_exited(self)
	worker_state = "returning_to_workshop"
	if is_instance_valid(hired_by_building):
		var target_pos = hired_by_building.get_interaction_position()
		_generate_path(target_pos)

func _pause_employee_due_to_missing_tool() -> void:
	is_gathering = false
	if is_instance_valid(target_mega_node):
		target_mega_node._on_body_exited(self)
	worker_state = "idle_at_workshop"
	if is_instance_valid(hired_by_building):
		var target_pos = hired_by_building.get_interaction_position()
		if global_position.distance_to(target_pos) > 50.0:
			_generate_path(target_pos)
			
		for emp in hired_by_building.hired_employees:
			if emp.get("npc_ref") == self:
				emp["is_paused"] = true
				emp["active_gathering_node_path"] = ""
				break
				
	if GameState.has_method("add_alert"):
		var b_name = hired_by_building.name.replace("Interior_", "") if is_instance_valid(hired_by_building) else "Workshop"
		var msg = "%s cannot gather: No Tool equipped. Please open building management, click Equipment, and equip a tool." % npc_name
		AlertManager.add_alert("Tool Missing", msg, "warning", hired_by_building)
		
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("_spawn_floating_text"):
		hud._spawn_floating_text("%s: Missing Tool!" % npc_name, global_position)

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
	var show_emotes = true
	if _economy_manager:
		show_emotes = _economy_manager.show_debug_emotes
	if not show_emotes:
		return
		
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.custom_minimum_size = Vector2(100, 20)
	label.position = Vector2(-50, -45)
	label.z_index = 15
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", -75.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 3.0)
	tween.tween_callback(label.queue_free)

func _update_action_label() -> void:
	if not is_instance_valid(action_label):
		return
		
	var show_emotes = true
	if _economy_manager:
		show_emotes = _economy_manager.show_debug_emotes
	action_label.visible = show_emotes
	
	if not show_emotes:
		return
		
	if roams_interior_only:
		action_label.text = "%s\n(City Council)" % npc_name
		return
		
	var state_str = "Unknown"
	var target_item = target_item_id
	var target_stall_node = target_stall
	
	var item_name = ""
	if target_item != "":
		item_name = target_item.capitalize()
		if _economy_manager and _economy_manager.item_database.has(target_item):
			item_name = _economy_manager.item_database[target_item].name
			
	var shop_info = ""
	if is_instance_valid(target_stall_node):
		var s_name = ""
		var building = null
		var building_type = ""
		
		if target_stall_node.get("parent_building") != null:
			building = target_stall_node.parent_building
			s_name = target_stall_node.market_name
		else:
			if target_stall_node.get("custom_name") != null and target_stall_node.custom_name != "":
				s_name = target_stall_node.custom_name
			elif target_stall_node.get("market_name") != null and target_stall_node.market_name != "":
				s_name = target_stall_node.market_name
			else:
				s_name = target_stall_node.name
				
			var building_groups = ["Bakeries", "Smelters", "Inns", "Looms", "Mills", "PaperMakers", "PrintingPresses", "Banks", "Houses"]
			for grp in building_groups:
				if target_stall_node.is_in_group(grp):
					building = target_stall_node
					break
		
		if is_instance_valid(building):
			s_name = building.custom_name if ("custom_name" in building and building.custom_name != "") else building.name
			if building.is_in_group("Bakeries"): building_type = "Bakery"
			elif building.is_in_group("Smelters"): building_type = "Smelter"
			elif building.is_in_group("Inns"): building_type = "Inn"
			elif building.is_in_group("Looms"): building_type = "Loom"
			elif building.is_in_group("Mills"): building_type = "Mill"
			elif building.is_in_group("PaperMakers"): building_type = "Paper Maker"
			elif building.is_in_group("PrintingPresses"): building_type = "Printing Press"
			elif building.is_in_group("Banks"): building_type = "Bank"
			elif building.is_in_group("Houses"): building_type = "House"
		
		if building_type != "":
			shop_info = "%s (%s)" % [s_name, building_type]
		else:
			shop_info = s_name

	if is_hired:
		if not is_shift_active():
			state_str = "Off-Duty (Resting)"
			if is_leisure_consuming:
				if is_instance_valid(leisure_spot_building):
					state_str = "Off-Duty (Relaxing at %s)" % (leisure_spot_building.custom_name if ("custom_name" in leisure_spot_building and leisure_spot_building.custom_name != "") else leisure_spot_building.name)
				else:
					state_str = "Off-Duty (Relaxing)"
			elif is_instance_valid(leisure_spot_building):
				state_str = "Off-Duty (Going to %s)" % (leisure_spot_building.custom_name if ("custom_name" in leisure_spot_building and leisure_spot_building.custom_name != "") else leisure_spot_building.name)
			else:
				state_str = "Off-Duty (Wandering)"
		elif active_commercial_route != null:
			if active_commercial_route.get("route_stops") != null:
				match worker_state:
					"internal_route_transit":
						var stop_idx = current_stop_index
						var stops_count = active_commercial_route.route_stops.size()
						state_str = "Logistics Stop %d/%d (Transit)" % [stop_idx + 1, stops_count]
					"internal_route_action":
						state_str = "Logistics Stop %d (Executing)" % (current_stop_index + 1)
					_:
						state_str = "Logistics: " + worker_state.capitalize()
			else:
				var cargo_name = commercial_route_cargo_item_id.capitalize() if commercial_route_cargo_item_id != "" else "Cargo"
				match worker_state:
					"commercial_route_loading":
						state_str = "Logistics: Loading " + cargo_name
					"commercial_route_transit":
						state_str = "Logistics: Waypoint %d/%d" % [commercial_route_current_waypoint_index + 1, active_commercial_route.market_waypoints.size()]
					"commercial_route_returning":
						state_str = "Logistics: Returning to Workshop"
					_:
						state_str = "Logistics: " + worker_state.capitalize()
		else:
			match worker_state:
				"traveling_to_workshop":
					state_str = "Traveling to Workshop"
				"idle_at_workshop":
					state_str = "Idle at Workshop"
				"traveling_to_node":
					var node_name = target_mega_node.node_name if is_instance_valid(target_mega_node) else "Mega-Node"
					state_str = "Traveling to %s" % node_name
				"gathering_at_node":
					var node_name = target_mega_node.node_name if is_instance_valid(target_mega_node) else "Mega-Node"
					state_str = "Gathering at %s" % node_name
				"returning_to_workshop":
					state_str = "Returning with Cargo"
				"traveling_to_workbench":
					state_str = "Going to workbench"
				"producing_goods":
					var has_recipe = false
					var is_paused = false
					if is_instance_valid(hired_by_building):
						for emp in hired_by_building.hired_employees:
							if emp.get("npc_ref") == self:
								if emp.get("active_recipe_path") != "":
									has_recipe = true
								is_paused = emp.get("is_paused", false)
								break
					if has_recipe:
						if is_paused:
							state_str = "Waiting for Materials"
						else:
							state_str = "Producing Goods"
					else:
						state_str = "Idle at Workbench"
				_:
					state_str = worker_state.capitalize()
	else:
		match current_state:
			State.IDLE_HOME:
				state_str = "Idle"
			State.SEARCH_CHOOSE:
				if target_item != "":
					state_str = "Searching for %s" % item_name
				else:
					state_str = "Searching"
			State.TRAVEL:
				if return_home_requested:
					state_str = "Returning Home"
				elif target_item != "" and shop_info != "":
					state_str = "Traveling to buy %s at %s" % [item_name, shop_info]
				else:
					state_str = "Traveling"
			State.TRANSACT:
				if target_item != "" and shop_info != "":
					state_str = "Buying %s at %s" % [item_name, shop_info]
				else:
					state_str = "Buying"
				
	action_label.text = "%s\n(%s)" % [npc_name, state_str]

func transfer_to_building(new_building: Node2D) -> void:
	if not is_hired or hired_by_building == new_building:
		return
		
	var old_building = hired_by_building
	hired_by_building = new_building
	
	# Find employee dictionary in old building's hired_employees
	var emp_dict = {}
	if old_building and "hired_employees" in old_building:
		for i in range(old_building.hired_employees.size()):
			var emp = old_building.hired_employees[i]
			if emp.get("npc_ref") == self or emp.get("name") == npc_name:
				emp_dict = emp
				old_building.hired_employees.remove_at(i)
				break
				
	if emp_dict.is_empty():
		emp_dict = {
			"npc_ref": self,
			"name": npc_name,
			"salary": salary,
			"career": career,
			"levels": {
				"patreon": patreon_level,
				"scholar": scholar_level,
				"craftsman": craftsman_level,
				"tailor": tailor_level,
				"woodworker": woodworker_level,
				"herbalist": herbalist_level,
				"rogue": rogue_level,
				"showman": showman_level
			},
			"active_recipe_path": "",
			"craft_timer": 0.0,
			"craft_total_time": 0.0,
			"is_repeating": true,
			"auto_gather_on_shortage": false,
			"is_paused": false
		}
	
	emp_dict["active_recipe_path"] = ""
	emp_dict["active_gathering_node_path"] = ""
	emp_dict["is_paused"] = false
	if emp_dict.has("active_commercial_route"):
		emp_dict.erase("active_commercial_route")
	active_commercial_route = null
	
	if "hired_employees" in new_building:
		new_building.hired_employees.append(emp_dict)
		
	worker_state = "traveling_to_workshop"
	var target_pos = new_building.get_interaction_position() if new_building.has_method("get_interaction_position") else new_building.global_position
	_generate_path(target_pos)
		
	if animated_sprite:
		if new_building.ownership_type == "Player":
			animated_sprite.modulate = Color(0.6, 1.0, 0.6)
		else:
			animated_sprite.modulate = Color(1.0, 0.6, 0.6)

func get_interaction_text() -> String:
	if has_meta("is_guild_master"):
		return "Talk to " + npc_name
	if has_meta("is_guild_office_npc"):
		return "Talk to " + npc_name
	if is_quest_npc:
		var matching = []
		for q in QuestManager.accepted_quests:
			if q.target_npc_id == quest_npc_id:
				matching.append(q)
		for q in matching:
			var current = GameState.player_inventory.get_item_amount(q.item_id)
			if current >= q.item_amount:
				return "Complete Quest: Deliver " + q.item_name
		return "Talk to Councilor"
	return "Talk to " + npc_name

func interact(player: CharacterBody2D) -> void:
	if has_meta("is_guild_master"):
		_interact_guild_master(player)
		return
		
	if has_meta("is_guild_office_npc"):
		_interact_guild_office_npc(player)
		return
		
	if npc_type == NPCType.TYPE_RELATION_TARGET:
		var rel_ui_scene = load("res://UI/relationship_ui.tscn")
		if rel_ui_scene:
			var rel_ui = rel_ui_scene.instantiate()
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if not hud:
				hud = get_tree().get_first_node_in_group("game_hud")
			if hud:
				var parent_node = hud.get_node_or_null("Control")
				if parent_node:
					parent_node.add_child(rel_ui)
				else:
					hud.add_child(rel_ui)
				rel_ui.setup(self)
				return
				
	if is_quest_npc:
		QuestManager.try_complete_quest(quest_npc_id, player)
	else:
		var career_name = career.capitalize() if career != "" else "Citizen"
		var lines = [
			"Hello there! My name is %s." % npc_name,
			"I work as a %s here in %s." % [career_name, province],
			"It's a beautiful day to build and trade in Guild Valley!"
		]
		GameState.show_npc_dialogue(self, npc_name, lines)

func _interact_guild_master(player: CharacterBody2D) -> void:
	var target_prof = get_meta("guild_profession") if has_meta("guild_profession") else "General"
	
	if target_prof != "General" and GameState.career_levels.get(target_prof, 0) == 0:
		var lines = [
			"Welcome to the %s Guild Hall." % target_prof.capitalize(),
			"I am the Guild Master, but I only deal with rank advancements for %ss." % target_prof.capitalize(),
			"You do not belong to our guild. Please speak to your own Guild Master if you seek rank advancement."
		]
		GameState.show_npc_dialogue(self, npc_name, lines)
		return

	var eligible = []
	
	# Player
	for cr in GameState.career_levels:
		if target_prof != "General" and cr != target_prof:
			continue
		var lvl = GameState.career_levels[cr]
		if lvl in [3, 6, 9]:
			var already_has = false
			for path in GameState.active_trial_recipes:
				var trial = load(path)
				if trial and trial.required_career == cr and trial.get_meta("character_name") == "Player":
					already_has = true
					break
			if not already_has:
				eligible.append({
					"name": "Player",
					"is_player": true,
					"career": cr,
					"level": lvl,
					"ref": null
				})
				
	# Employees
	var workshops = get_tree().get_nodes_in_group("production_buildings")
	for ws in workshops:
		if ws.ownership_type == "Player":
			for emp in ws.hired_employees:
				var npc_ref = emp.get("npc_ref")
				if is_instance_valid(npc_ref):
					for cr in npc_ref.skills_data:
						if target_prof != "General" and cr != target_prof:
							continue
						var lvl = npc_ref.skills_data[cr].get("level", 1)
						if lvl in [3, 6, 9]:
							var already_has = false
							for path in GameState.active_trial_recipes:
								var trial = load(path)
								if trial and trial.required_career == cr and trial.get_meta("character_name") == npc_ref.npc_name:
									already_has = true
									break
							if not already_has:
								eligible.append({
									"name": npc_ref.npc_name,
									"is_player": false,
									"career": cr,
									"level": lvl,
									"ref": npc_ref
								})
								
	var choices: Array[String] = []
	for data in eligible:
		var fee = 100
		if data.level == 6: fee = 250
		elif data.level == 9: fee = 500
		choices.append("%s: %s Breakthrough (%d Gold)" % [data.name, data.career.capitalize(), fee])
	choices.append("Cancel")
	
	var lines = [
		"Welcome to the Guild Hall, citizen.",
		"I manage professional rank advancements here.",
		"Do you or your hired employees have a breakthrough rank trial to request?"
	]
	
	var bubble_scene = load("res://UI/npc_dialogue_bubble.tscn")
	if not bubble_scene:
		return
	var bubble = bubble_scene.instantiate()
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
	if hud:
		var parent_node = hud.get_node_or_null("Control")
		if parent_node:
			parent_node.add_child(bubble)
		else:
			hud.add_child(bubble)
			
		player.freeze()
		bubble.start_dialogue(self, npc_name, lines, func():
			player.unfreeze()
		)
		bubble.show_choices(choices, func(choice_idx):
			bubble._on_close_pressed()
			if choice_idx < eligible.size():
				var target_data = eligible[choice_idx]
				_start_breakthrough_quest(target_data)
		)

func _interact_guild_office_npc(player: CharacterBody2D) -> void:
	var target_prof = get_meta("guild_profession") if has_meta("guild_profession") else "General"
	
	if target_prof != "General" and GameState.career_levels.get(target_prof, 0) == 0:
		var office_name = get_meta("office_name") if has_meta("office_name") else "Office"
		var lines = [
			"Hello there. This is the office of the %s for the %s Guild." % [office_name, target_prof.capitalize()],
			"I am afraid we only serve registered guild members here.",
			"Since you are not a %s, I cannot help you." % target_prof.capitalize()
		]
		GameState.show_npc_dialogue(self, npc_name, lines)
		return

	var office_name = get_meta("office_name") if has_meta("office_name") else "Office"
	var prov = GameState.get_province_of_node(self) if GameState else "Valley Province"
	
	var lines = []
	var choices = []
	
	if office_name == "Grand Chairman":
		lines = [
			"Greetings, citizen. I am the Grand Chairman of the conclave.",
			"Here we coordinate political campaigns, seasonal council seat elections, and regulatory audits.",
			"How can I assist you in conclave politics today?"
		]
		choices = ["Manage Conclave Elections", "Access Edicts & Audits", "Cancel"]
	elif office_name == "Logistics Overseer":
		lines = [
			"Greetings, citizen. I am the Donations Overseer for the guild.",
			"You can donate Gold or commodity stockpiles to elevate our province's prosperity.",
			"Would you like to make a donation?"
		]
		choices = ["Open Donations UI", "Cancel"]
	else: # Materials Steward
		lines = [
			"Greetings, merchant. I am the Materials Steward.",
			"I authorize the purchase of wholesale material bundles when province prosperity milestones are reached.",
			"Would you like to review available timed bundles?"
		]
		choices = ["Open Wholesaler Bundles", "Cancel"]
		
	var bubble_scene = load("res://UI/npc_dialogue_bubble.tscn")
	if not bubble_scene:
		return
	var bubble = bubble_scene.instantiate()
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
	if hud:
		var parent_node = hud.get_node_or_null("Control")
		if parent_node:
			parent_node.add_child(bubble)
		else:
			hud.add_child(bubble)
			
		player.freeze()
		bubble.start_dialogue(self, npc_name, lines, func():
			player.unfreeze()
		)
		bubble.show_choices(choices, func(choice_idx):
			bubble._on_close_pressed()
			
			var target_tab = ""
			if office_name == "Grand Chairman":
				if choice_idx == 0:
					target_tab = "Elections"
				elif choice_idx == 1:
					target_tab = "Audits"
			elif office_name == "Logistics Overseer":
				if choice_idx == 0:
					target_tab = "Donations"
			elif office_name == "Materials Steward":
				if choice_idx == 0:
					target_tab = "Wholesalers"
					
			if target_tab != "":
				if hud.has_method("open_guild_ui"):
					hud.call("open_guild_ui", prov, target_tab)
		)

func _start_breakthrough_quest(data: Dictionary) -> void:
	var fee = 100
	if data.level == 6: fee = 250
	elif data.level == 9: fee = 500
	
	if GameState.gold < fee:
		GameState.spawn_ui_floating_text("You need at least %d Gold to start this breakthrough!" % fee)
		return
		
	var trial = Recipe.new()
	trial.recipe_name = "Trial: %s %s" % [data.name, data.career.capitalize()]
	trial.required_career = data.career
	trial.required_level = 1
	trial.xp_reward = 0
	trial.is_breakthrough_only = true
	trial.set_meta("character_name", data.name)
	trial.set_meta("is_player", data.is_player)
	trial.set_meta("career", data.career)
	trial.set_meta("level", data.level)
	trial.set_meta("gold_fee", fee)
	
	var wheat = load("res://common/items/instances/Raw Materials/wheat.tres") as ItemData
	var flour = load("res://common/items/instances/Semi-Elaborate/flour.tres") as ItemData
	var bread = load("res://common/items/instances/Finished Goods/bread.tres") as ItemData
	var cotton = load("res://common/items/instances/Raw Materials/cotton.tres") as ItemData
	var cloth = load("res://common/items/instances/Semi-Elaborate/cloth.tres") as ItemData
	var ore = load("res://common/items/instances/Raw Materials/iron_ore.tres") as ItemData
	var ingot = load("res://common/items/instances/Semi-Elaborate/iron_ingot.tres") as ItemData
	var paper = load("res://common/items/instances/Semi-Elaborate/paper.tres") as ItemData
	var book = load("res://common/items/instances/Skill Items/book_patreon.tres") as ItemData
	
	var inputs: Dictionary[ItemData, int] = {}
	if data.career == "patreon":
		if data.level == 3:
			inputs[wheat] = 5
		elif data.level == 6:
			inputs[flour] = 5
		else:
			inputs[bread] = 10
	elif data.career == "craftsman":
		if data.level == 3:
			inputs[ore] = 5
		elif data.level == 6:
			inputs[ingot] = 5
		else:
			inputs[ingot] = 10
	elif data.career == "tailor":
		if data.level == 3:
			inputs[cotton] = 5
		elif data.level == 6:
			inputs[cloth] = 5
		else:
			inputs[cloth] = 10
	else:
		if data.level == 3:
			inputs[paper] = 5
		elif data.level == 6:
			inputs[book] = 2
		else:
			inputs[book] = 5
			
	var final_inputs: Dictionary[ItemData, int] = {}
	for k in inputs:
		if k != null:
			final_inputs[k] = inputs[k]
	if final_inputs.is_empty() and wheat != null:
		final_inputs[wheat] = 1
		
	trial.inputs = final_inputs
	
	var milestone = ItemData.new()
	milestone.id = ("milestone_%s_%s_%d" % [data.name, data.career, data.level]).validate_node_name()
	milestone.name = "%s's %s Milestone" % [data.name, data.career.capitalize()]
	milestone.base_value = 1
	milestone.is_tradable = false
	trial.output_item = milestone
	trial.output_amount = 1
	
	var file_name = ("breakthrough_%s_%s_%d.tres" % [data.name, data.career, data.level]).validate_node_name()
	var path = "user://" + file_name
	ResourceSaver.save(trial, path)
	
	GameState.active_trial_recipes.append(path)
	
	var message = "I have drafted the trial recipe: '%s'. Craft this milestone item at a Tier 2+ production workshop for %s to break through!" % [trial.recipe_name, data.career.capitalize()]
	GameState.show_npc_dialogue(self, "Guild Master", [message])

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
