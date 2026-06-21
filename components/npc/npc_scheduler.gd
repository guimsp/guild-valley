class_name NPCScheduler
extends Node

var npc: CharacterBody2D = null

var employee_scheduler: Node = null
var specialist_scheduler: Node = null

func _ready() -> void:
	npc = get_parent() as CharacterBody2D
	
	employee_scheduler = Node.new()
	employee_scheduler.set_script(load("res://components/npc/npc_employee_scheduler.gd"))
	employee_scheduler.name = "NPCEmployeeScheduler"
	employee_scheduler.npc = npc
	add_child(employee_scheduler)
	
	specialist_scheduler = Node.new()
	specialist_scheduler.set_script(load("res://components/npc/npc_specialist_scheduler.gd"))
	specialist_scheduler.name = "NPCSpecialistScheduler"
	specialist_scheduler.npc = npc
	add_child(specialist_scheduler)

func tick_scheduler(delta: float) -> void:
	if not npc:
		return
		
	if npc.has_meta("is_inspector"):
		specialist_scheduler.process_inspector_logic(delta)
		return
		
	if npc.is_talking:
		npc.velocity = Vector2.ZERO
		npc.navigation.update_movement_animation(Vector2.ZERO)
		return
		
	if npc.npc_type == npc.NPCType.TYPE_STATIC:
		specialist_scheduler.process_static_scan(delta)
		return
		
	if npc.npc_type == npc.NPCType.TYPE_RELATION_TARGET:
		specialist_scheduler.process_relation_target_behavior(delta)
		return
		
	if npc.npc_type == npc.NPCType.TYPE_EMPLOYEE:
		if npc.is_hired:
			if npc.is_shift_active():
				employee_scheduler.process_hired_worker(delta)
			else:
				employee_scheduler.process_employee_leisure(delta)
		else:
			employee_scheduler.process_employee_leisure(delta)
		return
		
	# Default consumer behavior (TYPE_CONSUMER)
	if npc.roams_interior_only:
		specialist_scheduler.process_interior_roam(delta)
		return
		
	if npc.limbo_timer > 0.0:
		npc.limbo_timer -= delta
		npc.velocity = Vector2.ZERO
		npc.navigation.update_movement_animation(Vector2.ZERO)
		return
		
	# Tick demands in consumer profile
	if npc.profile:
		npc.profile.tick_demands(delta)
		
	match npc.current_state:
		npc.State.IDLE_HOME:
			process_idle_home(delta)
		npc.State.SEARCH_CHOOSE:
			process_search_choose(delta)
		npc.State.TRAVEL:
			process_travel(delta)
		npc.State.TRANSACT:
			process_transact(delta)

func process_idle_home(delta: float) -> void:
	if not npc:
		return
		
	# Check if shopping queue has items
	if npc.profile and not npc.profile.shopping_queue.is_empty():
		npc.current_state = npc.State.SEARCH_CHOOSE
		npc.wait_timer = 0.0
		return
		
	if npc.wait_timer > 0.0:
		npc.wait_timer -= delta
		npc.velocity = Vector2.ZERO
		npc.navigation.update_movement_animation(Vector2.ZERO)
		if npc.wait_timer <= 0.0:
			npc.navigation.choose_new_wander_target()
		return
		
	var nav_finished = true
	if npc.nav_motor and npc.nav_motor.nav_agent:
		nav_finished = npc.nav_motor.nav_agent.is_navigation_finished()
		
	if nav_finished:
		npc.wait_timer = randf_range(3.0, 7.0)

func process_search_choose(_delta: float) -> void:
	if not npc:
		return
		
	if npc.is_searching:
		return
		
	if not npc.profile or npc.profile.shopping_queue.is_empty():
		# Shopping complete, return home
		npc.return_home_requested = true
		npc.navigation.generate_path(npc.get_home_position())
		npc.current_state = npc.State.TRAVEL
		return
		
	npc.target_item_id = npc.profile.shopping_queue[0]
	npc.econ_brain.request_search(npc.target_item_id)

func process_travel(_delta: float) -> void:
	if not npc:
		return
		
	# If travelling to shop, check distance to target stall doorstep
	if not npc.return_home_requested and is_instance_valid(npc.target_stall):
		var target_pos = npc.target_stall.global_position
		if npc.target_stall.has_method("get_interaction_position"):
			target_pos = npc.target_stall.get_interaction_position()
		var dist = npc.global_position.distance_to(target_pos)
		if dist <= 24.0: # Close enough to doorstep to transact
			if npc.nav_motor and is_instance_valid(npc.nav_motor.nav_agent):
				npc.nav_motor.nav_agent.target_position = npc.global_position # stop moving
			npc.current_state = npc.State.TRANSACT
			return
			
	# If the navigation is finished, we reached path end
	if npc.nav_motor and npc.nav_motor.nav_agent:
		if npc.nav_motor.path_pending:
			return
		if npc.nav_motor.nav_agent.is_navigation_finished():
			if npc.return_home_requested:
				npc.current_state = npc.State.IDLE_HOME
				npc.wait_timer = randf_range(2.0, 5.0)
			else:
				# Finished path but did not reach the stall. Erase/postpone item retry
				if npc.profile and npc.target_item_id != "":
					npc.profile.shopping_queue.erase(npc.target_item_id)
					if npc.profile.demand_profiles.has(npc.target_item_id):
						npc.profile.demand_profiles[npc.target_item_id]["accumulation"] = min(2, npc.profile.demand_profiles[npc.target_item_id].get("accumulation", 1) + 1)
						npc.profile.demand_profiles[npc.target_item_id]["timer"] = randf_range(15.0, 30.0)
				npc.spawn_debug_emote("X Blocked", Color.RED)
				npc.current_state = npc.State.SEARCH_CHOOSE

func process_transact(_delta: float) -> void:
	if npc:
		npc.econ_brain.process_transact()
