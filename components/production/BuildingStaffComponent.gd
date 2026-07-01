extends Node

# Standalone child component for managing building workforce and candidate lists
var building: Node = null

var hired_employees: Array = []
var hireable_candidates: Array = []
var workforce_ticker: Node = null
var candidate_replenish_timer: float = randf_range(0.0, 5.0)

signal employee_hired(employee_data: Dictionary)
signal employee_fired(employee_data: Dictionary)
signal candidates_replenished(candidates: Array)

func setup(p_building: Node) -> void:
	building = p_building
	if "hired_employees" in building:
		hired_employees = building.hired_employees
	if "hireable_candidates" in building:
		hireable_candidates = building.hireable_candidates
		
	var ticker_script = load("res://components/production/BuildingWorkforceTickComponent.gd")
	if ticker_script:
		workforce_ticker = ticker_script.new()
		workforce_ticker.name = "BuildingWorkforceTickComponent"
		add_child(workforce_ticker)
		workforce_ticker.setup(building, self)

func populate_candidates() -> void:
	if not building: return
	hireable_candidates.clear()
	var province_name = GameState.get_province_of_node(building)
	var local_unemployed = []
	for npc in get_tree().get_nodes_in_group("NPCs"):
		if is_instance_valid(npc) and not npc.get("is_hired") and npc.get("province") == province_name:
			if npc.get("is_quest_npc") or npc.get("roams_interior_only") or npc.get("quest_npc_id") != "" or npc.is_in_group("Guards") or npc.get("is_romanceable") or npc.get("npc_type") == 1:
				continue
			local_unemployed.append(npc)
	while local_unemployed.size() < 3:
		var new_npc = spawn_dynamic_npc_in_province(province_name)
		if is_instance_valid(new_npc): local_unemployed.append(new_npc)
	hireable_candidates = local_unemployed
	ensure_spouse_candidate()
	candidates_replenished.emit(hireable_candidates)

func ensure_spouse_candidate() -> void:
	if not building: return
	var spouse_id = ""
	var owner_id = building.get("owner_id")
	var ownership_type = building.get("ownership_type")
	if owner_id == "Player" or ownership_type == "Player":
		if GameState and GameState.is_married: spouse_id = GameState.spouse_npc_id
	elif owner_id == "Rival":
		for r in get_tree().get_nodes_in_group("Rivals"):
			if is_instance_valid(r) and r.get("spouse_npc_id"):
				spouse_id = r.spouse_npc_id
				break
	if spouse_id != "":
		var spouse_node = null
		for npc in get_tree().get_nodes_in_group("NPCs"):
			if is_instance_valid(npc) and npc.get("quest_npc_id") == spouse_id:
				spouse_node = npc
				break
		if spouse_node and not spouse_node.get("is_hired") and not hireable_candidates.has(spouse_node):
			hireable_candidates.append(spouse_node)

func spawn_dynamic_npc_in_province(prov_name: String) -> CharacterBody2D:
	var npc_scene = load("res://entities/npc/npc.tscn")
	if not npc_scene: return null
	var target = null
	for city in get_tree().get_nodes_in_group("Cities"):
		if (city.city_name + " Province") == prov_name:
			target = city
			break
	if not target:
		for town in get_tree().get_nodes_in_group("Towns"):
			if town.ownership_province == prov_name:
				target = town
				break
	var spawn_pos = target.global_position if target else (building.global_position if building else Vector2.ZERO)
	var npc = npc_scene.instantiate() as CharacterBody2D
	npc.global_position = spawn_pos + Vector2(randf_range(-100, 100), randf_range(-100, 100))
	npc.add_to_group("NPCs")
	building.get_parent().add_child(npc)
	npc.province = prov_name
	
	# Scale starting skills based on province prosperity level
	var pm = building.get_node_or_null("/root/ProsperityManager")
	var level = 1
	if pm:
		var val = pm.province_prosperity.get(prov_name, 100.0)
		level = pm.get_level_for_prosperity(val)
	
	var min_skill = 1
	var max_skill = 2
	if level == 2:
		min_skill = 3
		max_skill = 5
	elif level >= 3:
		min_skill = 6
		max_skill = 9
		
	var final_lvl = randi_range(min_skill, max_skill)
	if "skills_data" in npc:
		for career_key in npc.skills_data:
			npc.skills_data[career_key]["level"] = final_lvl
			
	var npc_mgr = building.get_node_or_null("/root/NPCManager")
	if npc_mgr:
		npc.character_resource = npc_mgr.generate_character_resource(prov_name, final_lvl)
		if "salary" in npc:
			npc.salary = npc.character_resource.daily_wage
			
	if is_instance_valid(npc.get("npc_runtime_state")):
		npc.npc_runtime_state.initialize_state({
			"id": npc.character_resource.character_id if npc.character_resource else "dynamic_" + str(npc.get_instance_id()),
			"name": npc.npc_name,
			"is_unique": false,
			"rank": "Employee",
			"is_dynamic": true
		})
		
	return npc

func get_employee_craft_time(emp: Dictionary, recipe: Resource) -> float:
	if workforce_ticker:
		return workforce_ticker.get_employee_craft_time(emp, recipe)
	return recipe.get_base_craft_time()

func tick_employees(delta: float) -> void:
	if not building: return
	
	candidate_replenish_timer -= delta
	if candidate_replenish_timer <= 0.0:
		candidate_replenish_timer = randf_range(6.0, 12.0)
		var valid_candidates = []
		for cand in hireable_candidates:
			if is_instance_valid(cand) and not cand.get("is_hired"):
				valid_candidates.append(cand)
		hireable_candidates = valid_candidates
		
		if hireable_candidates.size() < 3:
			populate_candidates()
		
	if workforce_ticker:
		workforce_ticker.tick_employees(delta)

func spawn_shift_worker(emp: Dictionary, node: Area2D) -> void:
	if workforce_ticker:
		workforce_ticker.spawn_shift_worker(emp, node)

func cancel_employee_gathering(emp: Dictionary, law_reason: String) -> void:
	emp["active_gathering_node_path"] = ""
	emp["shift_status"] = "idle"
	emp["is_paused"] = true
	var worker = emp.get("shift_worker_ref")
	if is_instance_valid(worker):
		if worker.get("is_gathering"):
			worker.set("is_gathering", false)
			if is_instance_valid(worker.get("target_mega_node")):
				worker.target_mega_node._on_body_exited(worker)
		worker.set("worker_state", "idle_at_workshop")
		if worker.has_method("_generate_path"):
			worker.call("_generate_path", building.get_interaction_position())
		emp["shift_worker_ref"] = null
		
	var npc = emp.get("npc_ref")
	if is_instance_valid(npc):
		npc.set("worker_state", "idle_at_workshop")
		if npc.has_method("_generate_path"):
			npc.call("_generate_path", building.get_interaction_position())
			
	var hud = get_tree().get_first_node_in_group("PlayerHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("game_hud")
	if hud and hud.has_method("_spawn_floating_text"):
		hud._spawn_floating_text("%s: On Strike! (%s)" % [emp.get("name", "Worker"), law_reason], building.global_position)

func cancel_all_smelting_recipes(law_reason: String) -> void:
	for emp in hired_employees:
		if emp.get("active_recipe_path", "") != "":
			emp["active_recipe_path"] = ""
			emp["craft_timer"] = 0.0
			emp["craft_total_time"] = 0.0
			emp["is_paused"] = true
			var worker = emp.get("npc_ref")
			if is_instance_valid(worker):
				worker.set("worker_state", "idle_at_workshop")
				if worker.has_method("_generate_path"):
					worker.call("_generate_path", building.get_interaction_position())
			
			var hud = get_tree().get_first_node_in_group("PlayerHUD")
			if not hud:
				hud = get_tree().get_first_node_in_group("game_hud")
			if hud and hud.has_method("_spawn_floating_text"):
				hud._spawn_floating_text("%s: Smelting Banned! (%s)" % [emp.get("name", "Worker"), law_reason], building.global_position)
