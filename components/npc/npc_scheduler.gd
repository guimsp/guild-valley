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
		
	# Night time routine: 22:00 to 06:00
	var is_night = (TimeManager.time_hours >= 22 or TimeManager.time_hours < 6)
	if is_night:
		process_night_routine(delta)
		return
	elif not is_night and npc.has_meta("is_asleep") and npc.get_meta("is_asleep"):
		# Morning wake up! Return to doorstep
		npc.set_meta("is_asleep", false)
		npc.visible = true
		if is_instance_valid(npc.home_house):
			var doorstep = npc.get_home_position()
			npc.global_position = doorstep
			if npc.nav_motor and npc.nav_motor.nav_agent:
				npc.nav_motor.nav_agent.target_position = doorstep
		npc.current_state = npc.State.IDLE_HOME
		npc.wait_timer = randf_range(2.0, 5.0)
		
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
			# Unemployed candidates should idle to avoid heavy pathfinding/leisure CPU checks
			npc.velocity = Vector2.ZERO
			if npc.navigation and npc.navigation.has_method("update_movement_animation"):
				npc.navigation.update_movement_animation(Vector2.ZERO)
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

func check_shopping_excursion_gates() -> void:
	if not npc or not npc.profile or npc.profile.shopping_list.is_empty():
		return
		
	var should_shop = false
	
	# 1. CAPACITY GATE
	if npc.profile.shopping_list.size() >= 3:
		should_shop = true
		
	# 2. CRITICAL GATE
	if not should_shop:
		for item_id in npc.profile.shopping_list:
			var item = EconomyManager.item_database.get(item_id)
			if item and item.get_item_category() == 0 and item.item_level >= 0 and item.item_level <= 2:
				should_shop = true
				break
				
	# 3. SCHEDULE GATE
	if not should_shop:
		var hr = TimeManager.time_hours
		if hr == 12 or hr == 17:
			should_shop = true
			
	if should_shop:
		npc.profile.shopping_queue = npc.profile.shopping_list.duplicate()
		npc.current_state = npc.State.SEARCH_CHOOSE
		npc.wait_timer = 0.0

func process_idle_home(delta: float) -> void:
	if not npc:
		return
		
	# Check shopping gates
	check_shopping_excursion_gates()
	if npc.current_state == npc.State.SEARCH_CHOOSE:
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
		npc.wait_timer = randf_range(12.0, 30.0)

func process_search_choose(_delta: float) -> void:
	if not npc:
		return
		
	if npc.is_searching:
		return
		
	if not npc.profile or npc.profile.shopping_queue.is_empty():
		if npc.profile:
			npc.profile.shopping_list.clear()
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
					if npc.profile.demand_timers.has(npc.target_item_id):
						npc.profile.increment_accumulation(npc.target_item_id)
						npc.profile.set_retry_timer(npc.target_item_id)
				npc.spawn_debug_emote("X Blocked", Color.RED)
				npc.current_state = npc.State.SEARCH_CHOOSE

func process_transact(_delta: float) -> void:
	if npc:
		npc.econ_brain.process_transact()

func process_night_routine(delta: float) -> void:
	if not npc:
		return
		
	if not is_instance_valid(npc.home_house):
		specialist_scheduler.process_interior_roam(delta)
		return
		
	if npc.has_meta("is_asleep") and npc.get_meta("is_asleep"):
		npc.velocity = Vector2.ZERO
		npc.visible = false
		return
		
	var doorstep = npc.get_home_position()
		
	var dist = npc.global_position.distance_to(doorstep)
	if dist <= 24.0:
		npc.set_meta("is_asleep", true)
		npc.visible = false
		npc.velocity = Vector2.ZERO
		npc.global_position = npc.home_house.interior_position + Vector2(128, 200) # Teleport inside
		npc.spawn_debug_emote("Sleeping", Color.BLUE)
	else:
		if npc.nav_motor and npc.nav_motor.nav_agent:
			if npc.nav_motor.nav_agent.target_position != doorstep:
				npc.navigation.generate_path(doorstep)
