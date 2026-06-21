extends Node

signal time_changed(hours: int, minutes: int, days: int)

# Time cycle variables
var time_minutes: float = 0.0 # 0.0 to 60.0
var time_hours: int = 6 # Starts at 6 AM
var time_days: int = 1
var TIME_SPEED: float = 1.0 # 1 in-game minute = 1 real second
var _last_emitted_minute: int = -1
var last_salary_payout_day: int = -1
var _last_checked_politics_key: int = -1

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_last_emitted_minute = 0

func get_time_string() -> String:
	var ampm = "AM" if time_hours < 12 else "PM"
	var display_hours = time_hours % 12
	if display_hours == 0:
		display_hours = 12
	return "Day %d - %02d:%02d %s" % [time_days, display_hours, int(time_minutes), ampm]

func _process(delta: float) -> void:
	time_minutes += delta * TIME_SPEED
	if time_minutes >= 60.0:
		time_minutes -= 60.0
		time_hours += 1
		if time_hours >= 24:
			time_hours = 0
			time_days += 1
			_clear_daily_production_stats()
			_deduct_salaries()
			if time_days % 4 == 0:
				if has_node("/root/PoliticsManager"):
					get_node("/root/PoliticsManager").process_seasonal_taxes()
			
	var current_min = int(time_minutes)
	if current_min != _last_emitted_minute:
		_last_emitted_minute = current_min
		time_changed.emit(time_hours, current_min, time_days)
		_check_politics_cycle_ticks()

func _clear_daily_production_stats() -> void:
	for node in get_tree().get_nodes_in_group("production_buildings"):
		if node.has_method("clear_daily_stats"):
			node.clear_daily_stats()

func _check_politics_cycle_ticks() -> void:
	if not has_node("/root/PoliticsManager"):
		return
	
	var pm = get_node("/root/PoliticsManager")
	var key = time_days * 100 + time_hours
	if _last_checked_politics_key == key:
		return
	_last_checked_politics_key = key
	
	if time_days % 4 == 0:
		for province in ["Valley Province", "Oakhaven Province"]:
			if time_hours == 6:
				pm.set_phase(province, pm.Phase.PHASE_SPONSORSHIP)
				GameState.spawn_ui_floating_text("%s: Lawhouse is open for Sponsorship!" % province)
			elif time_hours == 12:
				pm.assemble_ballot(province)
				pm.set_phase(province, pm.Phase.PHASE_BALLOT_ASSEMBLY)
				GameState.spawn_ui_floating_text("%s: Ballot Assembly Phase begun!" % province)
			elif time_hours == 18:
				pm.set_phase(province, pm.Phase.PHASE_VOTING)
				GameState.spawn_ui_floating_text("%s: Council Voting Phase begun!" % province)
			elif time_hours == 0:
				var state = pm.province_states[province]
				if state["current_phase"] == pm.Phase.PHASE_VOTING:
					var results = pm.resolve_voting_session(province, {}, {})
					var passed = []
					for lid in results:
						if results[lid]["passed"]:
							passed.append(results[lid]["law_name"])
					if passed.size() > 0:
						GameState.spawn_ui_floating_text("%s passed: %s" % [province, ", ".join(passed)])
					else:
						GameState.spawn_ui_floating_text("%s: No laws passed." % province)

func advance_day() -> void:
	if time_days % 4 == 0:
		if has_node("/root/PoliticsManager"):
			var pm = get_node("/root/PoliticsManager")
			for province in ["Valley Province", "Oakhaven Province"]:
				if pm.province_states[province]["current_phase"] == pm.Phase.PHASE_VOTING:
					pm.resolve_voting_session(province, {}, {})
					
	time_days += 1
	time_hours = 6
	time_minutes = 0.0
	_last_emitted_minute = 0
	_clear_daily_production_stats()
	
	# Emit immediate update
	time_changed.emit(time_hours, 0, time_days)
	
	# overnight economy simulation
	var stalls = get_tree().get_nodes_in_group("MarketStall")
	for stall in stalls:
		if stall.has_method("simulate_overnight_tick"):
			stall.simulate_overnight_tick()
			
	# overnight crop/resource regrowth
	var fields = get_tree().get_nodes_in_group("WheatFields")
	for field in fields:
		if field.has_method("simulate_overnight_tick"):
			field.simulate_overnight_tick()
			
	var cotton = get_tree().get_nodes_in_group("CottonPlants")
	for plant in cotton:
		if plant.has_method("simulate_overnight_tick"):
			plant.simulate_overnight_tick()
			
	var mines = get_tree().get_nodes_in_group("OreMines")
	for mine in mines:
		if mine.has_method("simulate_overnight_tick"):
			mine.simulate_overnight_tick()
			
	# overnight Bank interest (5% if player owns at least one Bank)
	var banks = get_tree().get_nodes_in_group("Banks")
	if banks.size() > 0 and GameState.bank_balance > 0:
		var usury_blocked = false
		if has_node("/root/PoliticsManager"):
			var pm = get_node("/root/PoliticsManager")
			var bank_prov = GameState.get_province_of_node(banks[0])
			if pm.is_law_active("usury_prohibition", bank_prov):
				usury_blocked = true
				
		if usury_blocked:
			GameState.spawn_ui_floating_text("Bank Interest Blocked by Usury Prohibition!")
		else:
			var interest = int(GameState.bank_balance * 0.05)
			if interest > 0:
				GameState.bank_balance += interest
				GameState.spawn_ui_floating_text("Bank Interest Earned: +%d Gold!" % interest)
			
	# overnight Inn traveler revenue
	var inns = get_tree().get_nodes_in_group("Inns")
	for inn in inns:
		if is_instance_valid(inn) and inn.ownership_type == "Player":
			var prosperity = 20
			if inn.get("nearest_settlement"):
				prosperity = inn.nearest_settlement.prosperity if "prosperity" in inn.nearest_settlement else 20
			var base_rev = inn.base_revenue if "base_revenue" in inn else 50
			if inn.get("building_level") != null and inn.building_level >= 2:
				base_rev = 120 # Premium luxury hotel lodging
			var rev = base_rev + int(prosperity * 0.5)
			
			var sbox = inn.get_node_or_null("StrongboxComponent")
			if sbox:
				sbox.strongbox_gold += rev
				sbox.add_transaction("Lodging Rent", 1, rev, "Overnight", "Guests")
			else:
				GameState.gold += rev
			GameState.spawn_ui_floating_text("Inn Revenue: +%d Gold!" % rev)
		elif is_instance_valid(inn) and inn.ownership_type == "NPC" and inn.owner_id == "Rival":
			var prosperity = 20
			if inn.get("nearest_settlement"):
				prosperity = inn.nearest_settlement.prosperity if "prosperity" in inn.nearest_settlement else 20
			var base_rev = inn.base_revenue if "base_revenue" in inn else 50
			if inn.get("building_level") != null and inn.building_level >= 2:
				base_rev = 120
			var rev = base_rev + int(prosperity * 0.5)
			var rivals = get_tree().get_nodes_in_group("Rivals")
			if rivals.size() > 0:
				rivals[0].gold += rev
				
	# overnight Employee salary deduction
	_deduct_salaries()
				
	# overnight Rental House tenant simulation
	var houses = get_tree().get_nodes_in_group("Houses")
	for house in houses:
		if is_instance_valid(house) and house.get("is_rental"):
			if house.is_occupied:
				# Add rent income to owner
				var rent_earned = house.rent_cost
				if house.ownership_type == "Player":
					GameState.gold += rent_earned
					GameState.spawn_ui_floating_text("Received %d Gold in Rent!" % rent_earned)
				elif house.ownership_type == "NPC" and house.owner_id == "Rival":
					var rivals = get_tree().get_nodes_in_group("Rivals")
					if rivals.size() > 0:
						rivals[0].gold += rent_earned
				
				# Decrement tenant rent days
				house.rent_days_remaining -= 1
				if house.rent_days_remaining <= 0:
					house.is_occupied = false
					house.rent_days_remaining = 0
					house._update_door_state()
					if house.ownership_type == "Player":
						GameState.spawn_ui_floating_text("Tenant moved out!")
			else:
				# Roll for new tenant
				var prosperity = 20
				var dist_to_market = 800.0
				
				if house.get("nearest_settlement"):
					prosperity = house.nearest_settlement.prosperity if "prosperity" in house.nearest_settlement else 20
					var market_node = null
					if "market_node_path" in house.nearest_settlement and house.nearest_settlement.market_node_path:
						market_node = house.nearest_settlement.get_node_or_null(house.nearest_settlement.market_node_path)
					if market_node:
						dist_to_market = house.global_position.distance_to(market_node.global_position)
					else:
						dist_to_market = house.global_position.distance_to(house.nearest_settlement.global_position)
				
				var base_chance = 0.20
				var prosperity_bonus = prosperity * 0.005
				var market_bonus = max(0.0, 1.0 - dist_to_market / 800.0) * 0.20
				var total_chance = base_chance + prosperity_bonus + market_bonus
				
				var is_patreon_l10 = GameState.career_levels.get("patreon", 1) >= 10
				if is_patreon_l10 and house.ownership_type == "Player":
					total_chance *= 1.5 # +50% tenant fill rate
				
				if randf() < total_chance:
					house.is_occupied = true
					house.rent_days_remaining = randi_range(3, 8)
					var base_rent = 25
					var rent_cost = base_rent + int(prosperity_bonus * 50) + int(market_bonus * 50)
					if is_patreon_l10 and house.ownership_type == "Player":
						rent_cost = int(rent_cost * 1.15) # +15% higher rent limit
					house.rent_cost = rent_cost
					house._update_door_state()
					if house.ownership_type == "Player":
						GameState.spawn_ui_floating_text("New Tenant moved in! (Rent: %d G)" % house.rent_cost)
						
	# Decay rent days overnight
	var groups_to_decay = ["MarketStall", "CraftingBenches", "WheatFieldGrids", "CottonPatchGrids", "OreMines", "TeleportTriggers", "WheatFields", "CottonPlants"]
	for grp in groups_to_decay:
		for node in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(node) and "ownership_type" in node:
				if (grp == "WheatFields" or grp == "CottonPlants") and _get_grid_for_crop(node) != null:
					continue
					
				if node.ownership_type == "Rented":
					node.rent_days_remaining -= 1
					if node.rent_days_remaining <= 0:
						node.ownership_type = "Public"
						node.owner_id = ""
						node.rent_days_remaining = 0
						
					# Propagate to child plots if grid
					if "crop_nodes" in node:
						for plot in node.crop_nodes:
							if is_instance_valid(plot):
								plot.ownership_type = node.ownership_type
								plot.owner_id = node.owner_id
								plot.rent_days_remaining = node.rent_days_remaining

	# overnight Employee salary deduction
	_deduct_salaries()

func _deduct_salaries() -> void:
	if last_salary_payout_day == time_days:
		return
	last_salary_payout_day = time_days
	
	var employee_salary_cost = 0
	var rival_salary_cost = 0
	var production_groups = ["Mills", "Smelters", "Looms", "Bakeries", "PaperMakers", "PrintingPresses", "Banks", "Inns", "Taverns", "Farmsteads", "Distilleries", "EventHalls"]
	for grp in production_groups:
		for node in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(node) and "hired_employees" in node:
				if node.ownership_type == "Player":
					for emp in node.hired_employees:
						employee_salary_cost += int(emp.get("salary", 15))
				elif node.ownership_type == "NPC" and node.owner_id == "Rival":
					for emp in node.hired_employees:
						rival_salary_cost += int(emp.get("salary", 15))
	if employee_salary_cost > 0:
		GameState.gold -= employee_salary_cost
		GameState.spawn_ui_floating_text("Paid Employee Salaries: -%d Gold!" % employee_salary_cost)
	if rival_salary_cost > 0:
		var rivals = get_tree().get_nodes_in_group("Rivals")
		if rivals.size() > 0:
			rivals[0].gold -= rival_salary_cost

func _get_grid_for_crop(crop_plot: Node2D) -> Node2D:
	return null
