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

var _road_speed_multiplier: float = 1.0
var speed_multiplier: float:
	get:
		var eq_speed = 0.0
		if has_node("EquipmentComponent"):
			eq_speed = get_node("EquipmentComponent").get_total_speed_bonus()
		var base_mult = _road_speed_multiplier + eq_speed
		
		# Martial Carriage Ban penalty for carts/couriers
		var pm = get_node_or_null("/root/PoliticsManager")
		if pm and active_commercial_route != null:
			var npc_prov = province
			if npc_prov == "Unknown Province" or npc_prov == "":
				npc_prov = GameState.get_province_of_node(self) if GameState else ""
			if pm.is_law_active("martial_carriage_ban", npc_prov):
				base_mult *= 0.60 # -40% speed
		return base_mult
	set(val):
		_road_speed_multiplier = val
var active_roads_count: int = 0

# Hired Worker attributes
var is_hired: bool = false
var hired_by_building: Node2D = null
var worker_state: String = "idle_at_workshop" # traveling_to_workshop, idle_at_workshop, traveling_to_node, gathering_at_node, returning_to_workshop, traveling_to_workbench, producing_goods
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
	"tailor": { "level": 1, "xp": 0 }
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

var productivity: float:
	get:
		var active_career = career
		if is_instance_valid(hired_by_building) and "career" in hired_by_building and hired_by_building.career != "":
			active_career = hired_by_building.career
		var lvl = skills_data.get(active_career, {}).get("level", 1)
		return 1.0 + (lvl * 0.02)
	set(val):
		pass
var salary: int = 15
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

func get_home_position() -> Vector2:
	if GameState and quest_npc_id != "" and quest_npc_id == GameState.spouse_npc_id:
		for house in get_tree().get_nodes_in_group("Houses"):
			if is_instance_valid(house) and house.ownership_type == "Player" and not house.is_rental:
				return house.global_position
	return spawn_position

func _ready() -> void:
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
	
	# Set layer separation: Layer 4 is NPC layer (value 8)
	# Set mask to Layer 1 (Static geometry) and Layer 3 (Lot barriers)
	collision_layer = 8
	collision_mask = 0

	
	# Override collision shape to be smaller for NPCs so they fit through narrow path clearances
	var col = get_node_or_null("CollisionShape2D")
	if col and col.shape is RectangleShape2D:
		col.shape = col.shape.duplicate()
		col.shape.size = Vector2(16, 12)
		col.position = Vector2(0, -6)
	
	# Soft blue modulate to distinguish from player and rival
	if animated_sprite:
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
		var careers = ["patreon", "scholar", "craftsman", "tailor"]
		career = careers[randi() % careers.size()]
		skills_data = {
			"patreon": { "level": randi_range(1, 5), "xp": 0 },
			"scholar": { "level": randi_range(1, 5), "xp": 0 },
			"craftsman": { "level": randi_range(1, 5), "xp": 0 },
			"tailor": { "level": randi_range(1, 5), "xp": 0 }
		}
		speed = randf_range(50.0, 90.0)
		salary = randi_range(12, 28)
	
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
			rel.profession_type = "tailor"
			rel.profession_level = 3
		"aldous":
			rel.hidden_preferences = ["ancient_manuscript", "ink", "paper"]
			rel.profession_type = "scholar"
			rel.profession_level = 4
		"valeria":
			rel.hidden_preferences = ["confidential_documents", "gold_ring", "silver_necklace"]
			rel.profession_type = "scholar"
			rel.profession_level = 5
		"gideon":
			rel.hidden_preferences = ["standard_timber", "iron_ingot", "iron_ore"]
			rel.profession_type = "woodworker"
			rel.profession_level = 3

func _physics_process(delta: float) -> void:
	if is_talking:
		velocity = Vector2.ZERO
		if has_method("update_animation"):
			update_animation(Vector2.ZERO)
		_update_action_label()
		return

	if npc_type == NPCType.TYPE_STATIC:
		_process_static_scan(delta)
		_update_action_label()
		return

	if npc_type == NPCType.TYPE_RELATION_TARGET:
		_process_relation_target_behavior(delta)
		_update_action_label()
		return

	if npc_type == NPCType.TYPE_EMPLOYEE:
		if is_hired:
			if is_shift_active():
				_process_hired_worker(delta)
			else:
				_process_employee_leisure(delta)
		else:
			_process_employee_leisure(delta)
		_update_action_label()
		return

	# Default consumer behavior (TYPE_CONSUMER)
	if roams_interior_only:
		_process_interior_roam(delta)
		_update_action_label()
		return

	if limbo_timer > 0.0:
		limbo_timer -= delta
		velocity = Vector2.ZERO
		if has_method("update_animation"):
			update_animation(Vector2.ZERO)
		_update_action_label()
		return

	# Tick cooldowns in IDLE_HOME and TRAVEL states
	if profile:
		profile.tick_demands(delta)
		
	match current_state:
		State.IDLE_HOME:
			_process_idle_home(delta)
		State.SEARCH_CHOOSE:
			_process_search_choose(delta)
		State.TRAVEL:
			_process_travel(delta)
		State.TRANSACT:
			_process_transact(delta)
			
	_update_action_label()

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
	data["xp"] += amount
	var xp_to_next: int = int(round(100 * pow(1.5, data["level"] - 1)))
	
	while data["xp"] >= xp_to_next:
		data["xp"] -= xp_to_next
		data["level"] += 1
		print("[NPC] %s Leveled Up %s to Lvl %d!" % [npc_name, career_id.capitalize(), data["level"]])
		
		# Show a floating text overlay above the NPC's head
		var hud = get_tree().get_first_node_in_group("PlayerHUD")
		if hud:
			if hud.has_method("_spawn_floating_text"):
				hud._spawn_floating_text("%s Leveled Up: Lvl %d!" % [career_id.capitalize(), data["level"]], global_position)
			if hud.get("_building_ui_instance") != null and is_instance_valid(hud._building_ui_instance) and hud._building_ui_instance.has_method("refresh"):
				hud._building_ui_instance.refresh()
				
		xp_to_next = int(round(100 * pow(1.5, data["level"] - 1)))

func go_to_workshop(building: Node2D) -> void:
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
	is_hired = false
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

func start_gathering_shift(node: Area2D) -> void:
	target_mega_node = node
	worker_state = "traveling_to_node"
	is_gathering = false
	shift_timer = 120.0
	
	# If inside, teleport outside first
	if global_position.y > 9000.0 and is_instance_valid(hired_by_building):
		_teleport(hired_by_building.get_interaction_position())
		
	var target_pos = node.global_position
	_generate_path(target_pos)

func deposit_cargo() -> void:
	if is_instance_valid(hired_by_building):
		var strongbox = hired_by_building.get_node_or_null("StrongboxComponent")
		if strongbox:
			var lm = get_node_or_null("/root/LogisticsManager")
			if lm and lm.gathered_buffer.has(self):
				var data = lm.gathered_buffer[self]
				var res_id = data["resource_id"]
				var amount = int(floor(data["amount"]))
				if amount > 0:
					var econ_mgr = get_node_or_null("/root/EconomyManager")
					var item_res = econ_mgr.item_database.get(res_id) if econ_mgr else null
					if item_res:
						if strongbox.has_method("deposit_resources"):
							strongbox.deposit_resources(item_res, amount)
						else:
							var target_storage = hired_by_building.get("building_storage")
							if target_storage:
								target_storage.add_item(item_res, amount)
						
						var hud = get_tree().get_first_node_in_group("PlayerHUD")
						if hud and hud.has_method("_spawn_floating_text"):
							hud._spawn_floating_text("Deposited %d %s!" % [amount, item_res.name], global_position)
				lm.erase_buffer(self)

func _exit_tree() -> void:
	var lm = get_node_or_null("/root/LogisticsManager")
	if lm:
		lm.erase_buffer(self)

func on_tool_broken() -> void:
	if is_gathering or worker_state in ["traveling_to_node", "gathering_at_node", "returning_to_workshop"]:
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
		GameState.add_alert("Tool Missing", msg, "warning", hired_by_building)
		
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if hud and hud.has_method("_spawn_floating_text"):
		hud._spawn_floating_text("%s: Missing Tool!" % npc_name, global_position)

func _process_hired_worker(delta: float) -> void:
	if active_commercial_route != null:
		if active_commercial_route.get("route_stops") != null:
			_process_internal_trade_route(delta)
		else:
			_process_commercial_route(delta)
		return
		
	var active_recipe_path = ""
	var active_gathering_node_path = ""
	if is_instance_valid(hired_by_building):
		for emp in hired_by_building.hired_employees:
			if emp.get("npc_ref") == self:
				active_recipe_path = emp.get("active_recipe_path", "")
				active_gathering_node_path = str(emp.get("active_gathering_node_path", ""))
				break
				
	if active_gathering_node_path != "":
		var eq = get_node_or_null("EquipmentComponent")
		if eq and not eq.get_equipped_item("tool"):
			_pause_employee_due_to_missing_tool()
			return
				
	if active_recipe_path == "" and active_gathering_node_path == "":
		if global_position.y > 9000.0:
			if is_instance_valid(hired_by_building):
				_teleport(hired_by_building.get_interaction_position())
			worker_state = "idle_at_workshop"
			
	match worker_state:
		"traveling_to_workshop":
			if is_instance_valid(hired_by_building):
				var target_pos = hired_by_building.get_interaction_position()
				if global_position.distance_to(target_pos) <= 24.0:
					worker_state = "idle_at_workshop"
					velocity = Vector2.ZERO
					if has_method("update_animation"):
						update_animation(Vector2.ZERO)
		
		"idle_at_workshop":
			if wait_timer > 0.0:
				wait_timer -= delta
				velocity = Vector2.ZERO
				if has_method("update_animation"):
					update_animation(Vector2.ZERO)
			else:
				if is_instance_valid(hired_by_building):
					var angle = randf() * TAU
					var dist = randf_range(30.0, 60.0)
					var wander_pos = hired_by_building.get_interaction_position() + Vector2(cos(angle), sin(angle)) * dist
					_generate_path(wander_pos)
					wait_timer = randf_range(3.0, 7.0)
					
		"traveling_to_node":
			# check legality before pathfinding or while moving
			var my_prov = province
			if my_prov == "Unknown Province" or my_prov == "":
				my_prov = GameState.get_province_of_node(self) if GameState else ""
			var pm = get_node_or_null("/root/PoliticsManager")
			if pm and is_instance_valid(target_mega_node) and my_prov != "":
				var res_id = target_mega_node.resource_type_id
				var is_illegal = false
				if pm.is_law_active("crown_forestry_protection", my_prov) and res_id == "standard_timber":
					is_illegal = true
				elif pm.is_law_active("noble_game_preservation", my_prov) and res_id == "venison":
					is_illegal = true
					
				if is_illegal:
					_trigger_worker_strike("Illegal Action")
					return

			if is_gathering:
				worker_state = "gathering_at_node"
				shift_timer = 120.0
				velocity = Vector2.ZERO
				if has_method("update_animation"):
					update_animation(Vector2.ZERO)
			else:
				if is_instance_valid(target_mega_node):
					var dist = global_position.distance_to(target_mega_node.global_position)
					if dist <= 48.0:
						target_mega_node._on_body_entered(self)
		
		"gathering_at_node":
			velocity = Vector2.ZERO
			if has_method("update_animation"):
				update_animation(Vector2.ZERO)
				
			shift_timer -= delta
			if shift_timer <= 0.0:
				is_gathering = false
				if is_instance_valid(target_mega_node):
					target_mega_node._on_body_exited(self)
				worker_state = "returning_to_workshop"
				if is_instance_valid(hired_by_building):
					var target_pos = hired_by_building.get_interaction_position()
					_generate_path(target_pos)
					
		"returning_to_workshop":
			if is_instance_valid(hired_by_building):
				var target_pos = hired_by_building.get_interaction_position()
				if global_position.distance_to(target_pos) <= 24.0:
					deposit_cargo()
					worker_state = "idle_at_workshop"
					velocity = Vector2.ZERO
					if has_method("update_animation"):
						update_animation(Vector2.ZERO)
						
		"traveling_to_workbench":
			var my_prov = province
			if my_prov == "Unknown Province" or my_prov == "":
				my_prov = GameState.get_province_of_node(self) if GameState else ""
			var pm = get_node_or_null("/root/PoliticsManager")
			if pm and my_prov != "" and is_instance_valid(hired_by_building) and hired_by_building.is_in_group("Smelters"):
				if pm.is_law_active("metallurgical_monopoly", my_prov):
					var sett = GameState.get_nearest_settlement(hired_by_building)
					if sett and not sett.is_in_group("Cities"):
						_trigger_worker_strike("Illegal Smelting")
						return

			if is_instance_valid(hired_by_building):
				if global_position.y < 9000.0:
					var doorstep = hired_by_building.get_interaction_position()
					if nav_motor and nav_motor.nav_agent.target_position.y >= 9000.0:
						_generate_path(doorstep)
						
					if global_position.distance_to(doorstep) <= 28.0:
						if is_instance_valid(hired_by_building.instanced_interior):
							_teleport(hired_by_building.instanced_interior.global_position + Vector2(0, 60))
							if is_instance_valid(hired_by_building.instanced_interior.crafting_bench):
								var bench_pos = hired_by_building.instanced_interior.crafting_bench.global_position
								_generate_path(bench_pos)
				else:
					if is_instance_valid(hired_by_building.instanced_interior) and is_instance_valid(hired_by_building.instanced_interior.crafting_bench):
						var bench_pos = hired_by_building.instanced_interior.crafting_bench.global_position
						if nav_motor and nav_motor.nav_agent.target_position != bench_pos:
							_generate_path(bench_pos)
							
						var dist = global_position.distance_to(bench_pos)
						var nav_finished = false
						if nav_motor and nav_motor.nav_agent:
							nav_finished = nav_motor.nav_agent.is_navigation_finished()
						
						# The bench physical size is 64x48, so we check if within 55px or path finished next to it
						if dist <= 55.0 or nav_finished:
							worker_state = "producing_goods"
							velocity = Vector2.ZERO
							if has_method("update_animation"):
								update_animation(Vector2.ZERO)
								
		"producing_goods":
			var is_paused = false
			if is_instance_valid(hired_by_building):
				for emp in hired_by_building.hired_employees:
					if emp.get("npc_ref") == self:
						is_paused = emp.get("is_paused", false)
						break
						
			if is_paused:
				if wait_timer > 0.0:
					wait_timer -= delta
					velocity = Vector2.ZERO
					if has_method("update_animation"):
						update_animation(Vector2.ZERO)
				else:
					if is_instance_valid(hired_by_building):
						var center_pos = hired_by_building.global_position
						if global_position.y >= 9000.0:
							if is_instance_valid(hired_by_building.instanced_interior):
								center_pos = hired_by_building.instanced_interior.global_position
						else:
							center_pos = hired_by_building.get_interaction_position()
							
						var angle = randf() * TAU
						var dist = randf_range(20.0, 50.0)
						var wander_pos = center_pos + Vector2(cos(angle), sin(angle)) * dist
						_generate_path(wander_pos)
						wait_timer = randf_range(3.0, 6.0)
			else:
				velocity = Vector2.ZERO
				if has_method("update_animation"):
					update_animation(Vector2.ZERO)

func update_animation(vel: Vector2) -> void:
	if vel.length() > 5.0:
		last_direction = _get_cardinal_direction(vel)
		if animated_sprite:
			animated_sprite.play("walk_" + last_direction)
	else:
		if animated_sprite:
			animated_sprite.play("idle_" + last_direction)

func _process_idle_home(delta: float) -> void:
	# Check if shopping queue has items
	if profile and not profile.shopping_queue.is_empty():
		current_state = State.SEARCH_CHOOSE
		wait_timer = 0.0
		return
		
	if wait_timer > 0.0:
		wait_timer -= delta
		velocity = Vector2.ZERO
		if has_method("update_animation"):
			update_animation(Vector2.ZERO)
		if wait_timer <= 0.0:
			_choose_new_wander_target()
		return
		
	var nav_finished = true
	if nav_motor and nav_motor.nav_agent:
		nav_finished = nav_motor.nav_agent.is_navigation_finished()
		
	if nav_finished:
		wait_timer = randf_range(3.0, 7.0)

func _process_search_choose(_delta: float) -> void:
	if is_searching:
		return # wait for search callback
		
	if not profile or profile.shopping_queue.is_empty():
		# Shopping complete, return home
		return_home_requested = true
		_generate_path(get_home_position())
		current_state = State.TRAVEL
		return
		
	target_item_id = profile.shopping_queue[0]
	is_searching = true
	
	# Spawn debug search indicator emote
	spawn_debug_emote("? " + target_item_id, Color.ORANGE)
	
	# Register query in staggered EconomyManager queue
	if _economy_manager:
		_economy_manager.request_shop_search(self, target_item_id, _on_shop_search_resolved)
	else:
		_on_shop_search_resolved(null)

func _on_shop_search_resolved(stall: CollisionObject2D) -> void:
	is_searching = false
	if not is_instance_valid(stall):
		# No shop found matching criteria/in stock
		# Remove item and put on failed/cooldown penalty in profile
		if profile:
			profile.shopping_queue.erase(target_item_id)
			if profile.demand_profiles.has(target_item_id):
				# Increment unmet necessity accumulation count (max 2)
				profile.demand_profiles[target_item_id]["accumulation"] = min(2, profile.demand_profiles[target_item_id].get("accumulation", 1) + 1)
				# Penalty retry timer (15 to 30 seconds)
				profile.demand_profiles[target_item_id]["timer"] = randf_range(15.0, 30.0)
				
		# Visual alert
		spawn_debug_emote("X No Shop", Color.RED)
		
		# Continue shopping next items or go home
		current_state = State.SEARCH_CHOOSE
		return
		
	# Shop found, proceed to travel to its interaction doorstep position
	target_stall = stall
	var target_pos = stall.global_position
	if stall.has_method("get_interaction_position"):
		target_pos = stall.get_interaction_position()
	_generate_path(target_pos)
	current_state = State.TRAVEL
	return_home_requested = false
	spawn_debug_emote("$ Go to shop", Color.YELLOW)

func _process_travel(_delta: float) -> void:
	# If travelling to shop, check distance to target stall doorstep
	if not return_home_requested and is_instance_valid(target_stall):
		var target_pos = target_stall.global_position
		if target_stall.has_method("get_interaction_position"):
			target_pos = target_stall.get_interaction_position()
		var dist = global_position.distance_to(target_pos)
		if dist <= 24.0: # Close enough to doorstep to transact
			if nav_motor and is_instance_valid(nav_motor.nav_agent):
				nav_motor.nav_agent.target_position = global_position # stop moving
			current_state = State.TRANSACT
			return
			
	# If the navigation is finished, we reached path end
	if nav_motor and nav_motor.nav_agent:
		if nav_motor.path_pending:
			return
		if nav_motor.nav_agent.is_navigation_finished():
			if return_home_requested:
				current_state = State.IDLE_HOME
				wait_timer = randf_range(2.0, 5.0)
			else:
				# Finished path but did not reach the stall. Erase/postpone item retry
				if profile and target_item_id != "":
					profile.shopping_queue.erase(target_item_id)
					if profile.demand_profiles.has(target_item_id):
						profile.demand_profiles[target_item_id]["accumulation"] = min(2, profile.demand_profiles[target_item_id].get("accumulation", 1) + 1)
						profile.demand_profiles[target_item_id]["timer"] = randf_range(15.0, 30.0)
				spawn_debug_emote("X Blocked", Color.RED)
				current_state = State.SEARCH_CHOOSE

func _process_transact(_delta: float) -> void:
	if not is_instance_valid(target_stall) or not target_stall.inventory:
		# Shop disappeared / invalid
		current_state = State.SEARCH_CHOOSE
		return
		
	# Perform transaction
	var item_data: ItemData = _economy_manager.item_database.get(target_item_id) if _economy_manager else null
	if item_data and (target_stall.ownership_type == "Public" or target_stall.inventory.get_item_amount(target_item_id) > 0):
		var available_stock = target_stall.inventory.get_item_amount(target_item_id) if target_stall.ownership_type != "Public" else 999
		var wanted_amount = 1
		if profile and profile.demand_profiles.has(target_item_id):
			wanted_amount = profile.demand_profiles[target_item_id].get("accumulation", 1)
			
		var buy_limit = 999
		if npc_type == NPCType.TYPE_CONSUMER and target_stall.ownership_type != "Public":
			if item_data.get_item_category() == 2: # Finished Product
				buy_limit = randi_range(1, 2)
				
		var buy_amount = min(wanted_amount, min(available_stock, buy_limit))
		var price = target_stall.get_buy_price(item_data)
		var total_cost = price * buy_amount
		
		# Deduct stock if NOT Public
		if target_stall.ownership_type != "Public":
			target_stall.inventory.remove_item(target_item_id, buy_amount)
		
		# Pay the owner
		_payout_stall_owner(target_stall, total_cost, item_data.name, buy_amount)
		
		# Successful transaction feedback (show amount if > 1)
		if buy_amount > 1:
			spawn_debug_emote("+%d %s ($%d)" % [buy_amount, item_data.name, total_cost], Color.GREEN)
		else:
			spawn_debug_emote("+%s ($%d)" % [item_data.name, total_cost], Color.GREEN)
		
		# Remove from shopping queue and reset accumulation
		if profile:
			profile.shopping_queue.erase(target_item_id)
			# Reset normal demand timer and reset accumulation to 1
			if profile.demand_profiles.has(target_item_id):
				profile.demand_profiles[target_item_id]["accumulation"] = 1
				var min_c = profile.demand_profiles[target_item_id].get("cooldown_min", 30.0)
				var max_c = profile.demand_profiles[target_item_id].get("cooldown_max", 60.0)
				profile.demand_profiles[target_item_id]["timer"] = randf_range(min_c, max_c)
	else:
		# Out of stock since we arrived
		spawn_debug_emote("X Sold Out", Color.RED)
		if profile:
			profile.shopping_queue.erase(target_item_id)
			if profile.demand_profiles.has(target_item_id):
				profile.demand_profiles[target_item_id]["accumulation"] = min(2, profile.demand_profiles[target_item_id].get("accumulation", 1) + 1)
				profile.demand_profiles[target_item_id]["timer"] = randf_range(15.0, 30.0) # short retry
				
	# Combo shopping check
	current_state = State.SEARCH_CHOOSE

func _payout_stall_owner(stall: CollisionObject2D, amount: int, item_name: String, qty: int) -> void:
	if stall.ownership_type == "Player" or (stall.ownership_type == "Rented" and stall.owner_id == "Player"):
		var target_node = stall
		if "parent_building" in stall and is_instance_valid(stall.parent_building):
			target_node = stall.parent_building
			
		var strongbox = target_node.get_node_or_null("StrongboxComponent")
		if strongbox:
			var timestamp = GameState.get_time_string() if GameState.has_method("get_time_string") else "Day %d" % GameState.time_days
			strongbox.add_transaction(item_name, qty, amount, timestamp, npc_name)
			GameState.spawn_ui_floating_text("+%d Gold (Strongbox: %s)" % [amount, target_node.name.replace("Interior_", "")])
		else:
			GameState.gold += amount
			GameState.spawn_ui_floating_text("+%d Gold (Stall Customer)" % amount)
	elif stall.ownership_type == "NPC" and stall.owner_id == "Rival":
		var rivals = get_tree().get_nodes_in_group("Rivals")
		if rivals.size() > 0:
			rivals[0].gold += amount


func _get_cardinal_direction(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "east" if direction.x > 0 else "west"
	else:
		return "south" if direction.y > 0 else "north"

func _choose_new_wander_target() -> void:
	var roads = get_tree().get_nodes_in_group("Roads")
	var plazas = get_tree().get_nodes_in_group("Plazas")
	
	var nearby_walkables = []
	var home_pos = get_home_position()
	for road in roads:
		if road.global_position.distance_to(home_pos) < 300.0:
			nearby_walkables.append(road)
	for plaza in plazas:
		if plaza.global_position.distance_to(home_pos) < 300.0:
			nearby_walkables.append(plaza)
			
	if nearby_walkables.is_empty():
		var angle = randf() * TAU
		var dist = randf() * 100.0
		var fallback_pos = home_pos + Vector2(cos(angle), sin(angle)) * dist
		_generate_path(fallback_pos)
		return
		
	var selected = nearby_walkables.pick_random()
	var size = selected.size if "size" in selected else Vector2(64, 64)
	var half_size = size / 2.0
	var offset = Vector2(
		randf_range(-half_size.x + 8.0, half_size.x - 8.0),
		randf_range(-half_size.y + 8.0, half_size.y - 8.0)
	)
	var next_target = selected.global_position + offset
	_generate_path(next_target)

func _generate_path(destination: Vector2) -> void:
	if nav_motor:
		nav_motor.move_to_target(destination, true)

func _teleport(target_pos: Vector2) -> void:
	if nav_motor and nav_motor.has_method("teleport_to"):
		nav_motor.teleport_to(target_pos)
	else:
		global_position = target_pos
		velocity = Vector2.ZERO

# Spawn floating Unicode emoji emotes above character's head
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
		if active_commercial_route != null:
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
					# Check if active recipe is set to show what is producing
					var has_recipe = false
					if is_instance_valid(hired_by_building):
						for emp in hired_by_building.hired_employees:
							if emp.get("npc_ref") == self and emp.get("active_recipe_path") != "":
								has_recipe = true
								break
					if has_recipe:
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


func _start_transit_to_waypoint(index: int) -> void:
	if active_commercial_route and index < active_commercial_route.market_waypoints.size():
		var wp = active_commercial_route.market_waypoints[index]
		if is_instance_valid(wp):
			var target_pos = wp.global_position
			if wp.has_method("get_interaction_position"):
				target_pos = wp.get_interaction_position()
			_generate_path(target_pos)
		else:
			call_deferred("_skip_to_next_waypoint")

func _skip_to_next_waypoint() -> void:
	commercial_route_current_waypoint_index += 1
	if commercial_route_current_waypoint_index >= active_commercial_route.market_waypoints.size():
		worker_state = "commercial_route_returning"
		if is_instance_valid(hired_by_building):
			_generate_path(hired_by_building.get_interaction_position())
	else:
		_start_transit_to_waypoint(commercial_route_current_waypoint_index)

func _process_commercial_route(delta: float) -> void:
	if commercial_route_sale_cooldown > 0.0:
		commercial_route_sale_cooldown -= delta
		
	match worker_state:
		"commercial_route_loading":
			if is_instance_valid(hired_by_building):
				var target_pos = hired_by_building.get_interaction_position()
				if global_position.distance_to(target_pos) <= 32.0:
					velocity = Vector2.ZERO
					if has_method("update_animation"):
						update_animation(Vector2.ZERO)
						
					if wait_timer > 0.0:
						wait_timer -= delta
						return
						
					var storage = hired_by_building.get("building_storage")
					if storage:
						var econ_mgr = get_node_or_null("/root/EconomyManager")
						var item_res = econ_mgr.item_database.get(active_commercial_route.target_item_id) if econ_mgr else null
						if item_res:
							var avail = storage.get_item_amount(item_res.id)
							if hired_by_building.has_method("get_available_item_amount"):
								avail = hired_by_building.get_available_item_amount(item_res.id)
							var to_load = min(active_commercial_route.target_amount, avail)
							var max_limit = item_res.max_stack if "max_stack" in item_res else 20
							to_load = min(to_load, max_limit)
							
							if to_load > 0:
								storage.remove_item(item_res.id, to_load)
								commercial_route_cargo_item_id = item_res.id
								commercial_route_cargo_amount = to_load
								commercial_route_gold_carried = 0
								commercial_route_current_waypoint_index = 0
								worker_state = "commercial_route_transit"
								_start_transit_to_waypoint(0)
							else:
								wait_timer = 5.0
		
		"commercial_route_transit":
			if active_commercial_route and commercial_route_current_waypoint_index < active_commercial_route.market_waypoints.size():
				var wp = active_commercial_route.market_waypoints[commercial_route_current_waypoint_index]
				if is_instance_valid(wp):
					var target_pos = wp.global_position
					if wp.has_method("get_interaction_position"):
						target_pos = wp.get_interaction_position()
						
					if global_position.distance_to(target_pos) <= 32.0:
						velocity = Vector2.ZERO
						if has_method("update_animation"):
							update_animation(Vector2.ZERO)
							
						if commercial_route_sale_cooldown > 0.0:
							return
							
						var econ_mgr = get_node_or_null("/root/EconomyManager")
						var item_res = econ_mgr.item_database.get(commercial_route_cargo_item_id) if econ_mgr else null
						var sold_an_item = false
						if item_res and commercial_route_cargo_amount > 0:
							var price = wp.get_sell_price(item_res)
							if price >= active_commercial_route.minimum_sell_price:
								if wp.inventory and wp.inventory.get_free_space_for_item(item_res) >= 1:
									var can_afford = true
									if wp.ownership_type == "NPC" and wp.owner_id == "Rival":
										var rivals = get_tree().get_nodes_in_group("Rivals")
										if rivals.size() > 0 and rivals[0].gold < price:
											can_afford = false
									
									if can_afford:
										wp.inventory.add_item(item_res, 1)
										if wp.ownership_type == "NPC" and wp.owner_id == "Rival":
											var rivals = get_tree().get_nodes_in_group("Rivals")
											if rivals.size() > 0:
												rivals[0].gold -= price
												
										commercial_route_cargo_amount -= 1
										commercial_route_gold_carried += price
										spawn_debug_emote("Sold 1 ($%d)" % price, Color.GREEN)
										commercial_route_sale_cooldown = 0.5
										sold_an_item = true
										return
										
						if not sold_an_item:
							if commercial_route_cargo_amount <= 0:
								worker_state = "commercial_route_returning"
								if is_instance_valid(hired_by_building):
									_generate_path(hired_by_building.get_interaction_position())
							else:
								commercial_route_current_waypoint_index += 1
								if commercial_route_current_waypoint_index >= active_commercial_route.market_waypoints.size():
									worker_state = "commercial_route_returning"
									if is_instance_valid(hired_by_building):
										_generate_path(hired_by_building.get_interaction_position())
								else:
									_start_transit_to_waypoint(commercial_route_current_waypoint_index)
				else:
					_skip_to_next_waypoint()
					
		"commercial_route_returning":
			if is_instance_valid(hired_by_building):
				var target_pos = hired_by_building.get_interaction_position()
				if global_position.distance_to(target_pos) <= 32.0:
					var storage = hired_by_building.get("building_storage")
					var econ_mgr = get_node_or_null("/root/EconomyManager")
					var item_res = econ_mgr.item_database.get(commercial_route_cargo_item_id) if econ_mgr else null
					
					if commercial_route_cargo_amount > 0 and storage and item_res:
						storage.add_item(item_res, commercial_route_cargo_amount)
						
					var strongbox = hired_by_building.get_node_or_null("StrongboxComponent")
					if strongbox and commercial_route_gold_carried > 0 and item_res:
						var timestamp = GameState.get_time_string() if GameState.has_method("get_time_string") else "Day %d" % GameState.time_days
						strongbox.add_transaction("Trade Route (" + item_res.name + ")", active_commercial_route.target_amount - commercial_route_cargo_amount, commercial_route_gold_carried, timestamp, npc_name)
						
					commercial_route_cargo_item_id = ""
					commercial_route_cargo_amount = 0
					commercial_route_gold_carried = 0
					
					worker_state = "commercial_route_loading"
					wait_timer = 2.0
					
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
				"tailor": tailor_level
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


func _process_internal_trade_route(delta: float) -> void:
	if not active_commercial_route or current_stop_index >= active_commercial_route.route_stops.size():
		return
		
	var stop = active_commercial_route.route_stops[current_stop_index]
	if not is_instance_valid(stop) or not is_instance_valid(stop.target_building):
		_advance_to_next_stop()
		return
		
	var target_pos = stop.target_building.get_interaction_position() if stop.target_building.has_method("get_interaction_position") else stop.target_building.global_position
	
	if global_position.distance_to(target_pos) <= 32.0:
		velocity = Vector2.ZERO
		if has_method("update_animation"):
			update_animation(Vector2.ZERO)
			
		var is_market = stop.target_building.is_in_group("MarketStall")
		var storage = stop.target_building.get("building_storage") if stop.target_building.get("building_storage") != null else stop.target_building.get("inventory")
		var econ_mgr = get_node_or_null("/root/EconomyManager")
		var item_res = econ_mgr.item_database.get(stop.item_id) if econ_mgr else null
		
		# Deposit gold at workshops
		if not is_market:
			var strongbox = stop.target_building.get_node_or_null("StrongboxComponent")
			if strongbox and commercial_route_gold_carried > 0:
				var timestamp = GameState.get_time_string() if GameState.has_method("get_time_string") else "Day %d" % GameState.time_days
				strongbox.add_transaction("Market Sales", commercial_route_gold_carried, timestamp, npc_name)
				commercial_route_gold_carried = 0
		
		if storage and item_res:
			if is_market:
				# Timed transaction logic
				if wait_timer > 0.0:
					wait_timer -= delta
					return
					
				if last_processed_stop_index != current_stop_index:
					last_processed_stop_index = current_stop_index
					current_stop_transacted_count = 0
					
				if current_stop_transacted_count >= stop.target_quantity:
					_advance_to_next_stop()
					return
					
				if stop.action_type == "LOAD":
					# Buying from market
					var free_space = cargo_inventory.get_free_space_for_item(item_res)
					var avail = storage.get_item_amount(stop.item_id)
					if is_instance_valid(stop.target_building) and stop.target_building.has_method("get_available_item_amount"):
						avail = stop.target_building.get_available_item_amount(stop.item_id)
					if free_space <= 0 or avail <= 0:
						_advance_to_next_stop()
						return
						
					var price = stop.target_building.get_buy_price(item_res)
					var strongbox = hired_by_building.get_node_or_null("StrongboxComponent") if is_instance_valid(hired_by_building) else null
					var can_afford = false
					if strongbox and strongbox.gold >= price:
						can_afford = true
					elif not strongbox and GameState.gold >= price:
						can_afford = true
						
					if can_afford:
						if strongbox:
							strongbox.gold -= price
						else:
							GameState.gold -= price
							
						storage.remove_item(stop.item_id, 1)
						cargo_inventory.add_item(item_res, 1)
						
						if stop.target_building.ownership_type == "NPC" and stop.target_building.owner_id == "Rival":
							var rivals = get_tree().get_nodes_in_group("Rivals")
							if rivals.size() > 0:
								rivals[0].gold += price
								
						spawn_debug_emote("Bought 1 (-$%d)" % price, Color.RED)
						current_stop_transacted_count += 1
						wait_timer = 0.5
						return
					else:
						_advance_to_next_stop()
						return
						
				elif stop.action_type == "UNLOAD":
					# Selling to market
					var held = cargo_inventory.get_item_amount(stop.item_id)
					var free_space = storage.get_free_space_for_item(item_res)
					if held <= 0 or free_space <= 0:
						_advance_to_next_stop()
						return
						
					var price = stop.target_building.get_sell_price(item_res)
					var can_afford = true
					if stop.target_building.ownership_type == "NPC" and stop.target_building.owner_id == "Rival":
						var rivals = get_tree().get_nodes_in_group("Rivals")
						if rivals.size() > 0 and rivals[0].gold < price:
							can_afford = false
							
					if can_afford:
						cargo_inventory.remove_item(stop.item_id, 1)
						storage.add_item(item_res, 1)
						
						if stop.target_building.ownership_type == "NPC" and stop.target_building.owner_id == "Rival":
							var rivals = get_tree().get_nodes_in_group("Rivals")
							if rivals.size() > 0:
								rivals[0].gold -= price
								
						commercial_route_gold_carried += price
						spawn_debug_emote("Sold 1 ($%d)" % price, Color.GREEN)
						current_stop_transacted_count += 1
						wait_timer = 0.5
						return
					else:
						_advance_to_next_stop()
						return
			else:
				# Non-market: traditional sequential fast trade
				if stop.action_type == "LOAD":
					var avail = storage.get_item_amount(stop.item_id)
					if is_instance_valid(stop.target_building) and stop.target_building.has_method("get_available_item_amount"):
						avail = stop.target_building.get_available_item_amount(stop.item_id)
					var to_load = min(stop.target_quantity, avail)
					if to_load > 0:
						var free_space = cargo_inventory.get_free_space_for_item(item_res)
						var fit = min(to_load, free_space)
						if fit > 0:
							storage.remove_item(stop.item_id, fit)
							var remaining = cargo_inventory.add_item(item_res, fit)
							spawn_debug_emote("Loaded %d %s" % [fit, item_res.name], Color.CYAN)
							
							if remaining > 0:
								storage.add_item(item_res, remaining)
								GameState.spawn_ui_floating_text("Route Alert: Carrier %s inventory full!" % npc_name)
						else:
							GameState.spawn_ui_floating_text("Route Alert: Carrier %s inventory full!" % npc_name)
							
				elif stop.action_type == "UNLOAD":
					var held = cargo_inventory.get_item_amount(stop.item_id)
					var to_unload = min(stop.target_quantity, held)
					if to_unload > 0:
						var free_space = storage.get_free_space_for_item(item_res)
						var fit = min(to_unload, free_space)
						if fit > 0:
							cargo_inventory.remove_item(stop.item_id, fit)
							storage.add_item(item_res, fit)
							spawn_debug_emote("Unloaded %d %s" % [fit, item_res.name], Color.ORANGE)
							
		_advance_to_next_stop()
	else:
		if nav_motor and nav_motor.nav_agent.is_navigation_finished():
			_start_transit_to_stop(current_stop_index)


func _start_transit_to_stop(index: int) -> void:
	if active_commercial_route and index < active_commercial_route.route_stops.size():
		var stop = active_commercial_route.route_stops[index]
		if stop and is_instance_valid(stop.target_building):
			worker_state = "internal_route_transit"
			var target_pos = stop.target_building.get_interaction_position() if stop.target_building.has_method("get_interaction_position") else stop.target_building.global_position
			_generate_path(target_pos)


func _advance_to_next_stop() -> void:
	current_stop_index += 1
	if current_stop_index >= active_commercial_route.route_stops.size():
		current_stop_index = 0
	_start_transit_to_stop(current_stop_index)


func _process_interior_roam(delta: float) -> void:
	if wait_timer > 0.0:
		wait_timer -= delta
		velocity = Vector2.ZERO
		if has_method("update_animation"):
			update_animation(Vector2.ZERO)
	else:
		var nav_finished = true
		if nav_motor and nav_motor.nav_agent:
			nav_finished = nav_motor.nav_agent.is_navigation_finished()
			
		if nav_finished:
			var rx = randf_range(-120.0, 120.0)
			var ry = randf_range(-70.0, 70.0)
			var target_pos = anchor_position + Vector2(rx, ry)
			_generate_path(target_pos)
			wait_timer = randf_range(3.0, 8.0)

func get_interaction_text() -> String:
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

# --- Relationships, static scan and leisure helpers ---

var leisure_spot_building: Node2D = null
var is_leisure_consuming: bool = false
var scan_timer: float = 3.0

func is_shift_active() -> bool:
	if GameState:
		return GameState.time_hours >= 8 and GameState.time_hours < 18
	return true

func payout_salary(amount: int) -> void:
	npc_gold += amount
	spawn_debug_emote("+%d Salary" % amount, Color.GREEN)

func _process_employee_leisure(delta: float) -> void:
	if limbo_timer > 0.0:
		limbo_timer -= delta
		velocity = Vector2.ZERO
		if has_method("update_animation"):
			update_animation(Vector2.ZERO)
		return
		
	if wait_timer > 0.0:
		wait_timer -= delta
		velocity = Vector2.ZERO
		if has_method("update_animation"):
			update_animation(Vector2.ZERO)
		if wait_timer <= 0.0:
			var targets = []
			for grp in ["Taverns", "Inns", "Bakeries"]:
				targets.append_array(get_tree().get_nodes_in_group(grp))
			if targets.is_empty():
				_choose_new_wander_target()
		return

	if is_leisure_consuming:
		is_leisure_consuming = false
		_execute_leisure_transaction()
		wait_timer = randf_range(8.0, 15.0)
		return

	if not is_instance_valid(leisure_spot_building):
		var targets = []
		for grp in ["Taverns", "Inns", "Bakeries"]:
			targets.append_array(get_tree().get_nodes_in_group(grp))
			
		if targets.is_empty():
			var nav_finished = true
			if nav_motor and nav_motor.nav_agent:
				nav_finished = nav_motor.nav_agent.is_navigation_finished()
			if nav_finished:
				wait_timer = randf_range(4.0, 8.0)
			return
			
		leisure_spot_building = targets.pick_random()
		var target_pos = leisure_spot_building.get_interaction_position() if leisure_spot_building.has_method("get_interaction_position") else leisure_spot_building.global_position
		_generate_path(target_pos)
	else:
		var target_pos = leisure_spot_building.get_interaction_position() if leisure_spot_building.has_method("get_interaction_position") else leisure_spot_building.global_position
		var dist = global_position.distance_to(target_pos)
		
		var nav_finished = false
		if nav_motor and nav_motor.nav_agent:
			nav_finished = nav_motor.nav_agent.is_navigation_finished()
			
		if dist <= 32.0 or nav_finished:
			is_leisure_consuming = true
			velocity = Vector2.ZERO
			if has_method("update_animation"):
				update_animation(Vector2.ZERO)

func _execute_leisure_transaction() -> void:
	if not is_instance_valid(leisure_spot_building):
		return
		
	if npc_gold < 10:
		spawn_debug_emote("No Gold!", Color.RED)
		leisure_spot_building = null
		return
		
	var storage = leisure_spot_building.get("building_storage")
	if not storage:
		storage = leisure_spot_building.get("inventory")
		
	var item_to_consume = null
	if storage:
		for slot in storage.slots:
			if slot.get("item") and slot["item"].category == "Food":
				item_to_consume = slot["item"]
				break
				
	var cost = 12
	var item_name = "Drink/Food"
	if item_to_consume:
		item_name = item_to_consume.name
		cost = item_to_consume.base_value
		storage.remove_item(item_to_consume.id, 1)
		
	if npc_gold >= cost:
		npc_gold -= cost
		spawn_debug_emote("Consumed %s (-%d G)" % [item_name, cost], Color.GREEN)
		
		if leisure_spot_building.ownership_type == "Player" or (leisure_spot_building.ownership_type == "Rented" and leisure_spot_building.owner_id == "Player"):
			var strongbox = leisure_spot_building.get_node_or_null("StrongboxComponent")
			if strongbox:
				strongbox.strongbox_gold += cost
				strongbox.add_transaction("Leisure Customer", 1, cost, "Off-Duty", npc_name)
			else:
				GameState.gold += cost
		elif leisure_spot_building.ownership_type == "NPC" and leisure_spot_building.owner_id == "Rival":
			var rivals = get_tree().get_nodes_in_group("Rivals")
			if rivals.size() > 0:
				rivals[0].gold += cost
	else:
		spawn_debug_emote("No Gold!", Color.RED)
		
	leisure_spot_building = null

func _process_relation_target_behavior(delta: float) -> void:
	if roams_interior_only:
		_process_interior_roam(delta)
		return
		
	if wait_timer > 0.0:
		wait_timer -= delta
		velocity = Vector2.ZERO
		if has_method("update_animation"):
			update_animation(Vector2.ZERO)
		if wait_timer <= 0.0:
			_choose_new_wander_target()
		return
		
	var nav_finished = true
	if nav_motor and nav_motor.nav_agent:
		nav_finished = nav_motor.nav_agent.is_navigation_finished()
		
	if nav_finished:
		wait_timer = randf_range(5.0, 10.0)

func _process_static_scan(delta: float) -> void:
	velocity = Vector2.ZERO
	if has_method("update_animation"):
		update_animation(Vector2.ZERO)
		
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = randf_range(4.0, 8.0)
		var player = get_tree().get_first_node_in_group("Player")
		if player and global_position.distance_to(player.global_position) <= 80.0:
			spawn_debug_emote("Guarding...", Color.SKY_BLUE)
			var diff = player.global_position - global_position
			last_direction = _get_cardinal_direction(diff)
			if has_method("update_animation"):
				update_animation(Vector2.ZERO)
